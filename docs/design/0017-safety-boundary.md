# 0017 Safety boundary by token and checkout instead of command allow lists

Issue: #421 (design study, no implementation in this PR). Builds on 0004 (untrusted-text boundary), 0015 (model-free dispatcher).

## 1. Goal

Today the boundary of a model run is a list of allowed shell command forms per workflow (`--allowedTools "Bash(git:*),..."`) plus prose in the
prompt ("one simple command per Bash call: no pipes, `&&`, `;`, `$(...)`"). The model works around it, which costs turns and failed runs (issues
#156, #203, #210, #312, #313, #327, #328, #330, #338, #349), and every incident adds a sentence to a prompt. Goal: decide per job what the
token and the checkout can do, so that a developer or fix run needs no command list. Judging runs stay confined. Acceptance: a per-job
table of token, secrets and egress, a chosen design, and implementation steps that can run in parallel.

## 2. Current state (file references)

- Measurement. `tools/run_stats.py` counts model runs, failures and limit failures per workflow (`workflow_stats`, line 101) and failure
  classes (`failure_classes`, line 139). It does NOT count denied tool calls. `python3 tools/run_stats.py 7` (default workflow only) returned 17 model runs
  (5 on 2026-11-11, 12 on 2026-11-12) and 661 gate-skipped runs, after about 3 minutes; it has no denied-call figure, so none is claimed: **open**.
  Step 1 adds the count: the Claude Code result message records `permission_denials` (open: the action's `execution_file` is assumed to
  keep it, step 1 verifies on a real file) and `run_stats.py` sums it per workflow.
- Allowed Bash per workflow (`--allowedTools`): `agent-dev.yml:212` and `agent-fix.yml:267` list `git`, `cp`, `mkdir`, `diff`, `cmp`, `wc`, `ls`,
  `make`, `python3`, `pytest`, `ruff`, `actionlint`, `zizmor` and a few `gh`; `orchestrator.yml:272` lists 20 `gh`/`git` forms; reviewers,
  scout, unblocker and answer-receiver are read-mostly (`agent-review.yml:162`, `agent-security-review.yml:122`, `scout.yml:117`,
  `unblocker.yml:84`, `answer-receiver.yml:93`).
- Read confinement exists (design 0004 rule 1): `.github/claude-judge-settings.json` denies `Read`/`Glob`/`Grep` of `/proc`, `/etc`, `/root`, `/run`,
  `/var`, the runner temp, `_actions`, `_tool` and `~/.*`, and is passed as `--settings` (`agent-dev.yml:211`). Only the `Read`, `Glob` and `Grep` tools
  are covered: a shell command (`cat /proc/self/environ`) is not.
- Tokens (`create-github-app-token`, `permission-*`): dev `agent-dev.yml:132-136` and fix `agent-fix.yml:191-195`: `contents`, `workflows`,
  `pull-requests`, `issues`, `actions` write. Orchestrator `orchestrator.yml:79-81`: `contents`, `pull-requests`, `issues` write.
  Reviewers `agent-review.yml:46`, `agent-security-review.yml:49`: `pull-requests` write (approver app). Scout `scout.yml:43-47`: `issues` write, rest
  read. Unblocker `unblocker.yml:45-47` and answer-receiver `answer-receiver.yml:50-52`: read in the model job; the write token (`:106-109`,
  `:117-120`) is only in the later script job.
- Secrets in a model job: `CLAUDE_CODE_OAUTH_TOKEN` is an input of `claude-code-action` in every model job (`agent-dev.yml:183`). `GUARD_KEY` is only in
  script steps after the model step (`agent-dev.yml:252`, test `tests/test_guard_mark.py`). `AUTHOR_APP_KEY` / `APPROVER_APP_KEY` feed
  `create-github-app-token` only; the minted token is in the step `env` (`agent-dev.yml:181`).
- Branch protection: `.github/rulesets/main.json` targets only the default branch (`~DEFAULT_BRANCH`): required PR, code owner review, four checks, no
  force push, no deletion. It says nothing about other branches or tags.

## 3. Options with trade-offs

A. Status quo: command allow lists. Known cost (section 1); also weak: `Bash(python3:*)` and `Bash(make:*)` already run arbitrary code, so the list
   limits wording, not capability.

B. Free shell for developer and fix runs, boundary = token + checkout (the issue's proposal). Fewer denied calls and shorter prompts. Two facts make
   it not "free": (1) a shell bypasses the Read deny rules of 0004, so `cat /proc/self/environ` can reach `CLAUDE_CODE_OAUTH_TOKEN` (the CLI
   needs it; open: whether it sits in the process environment, 0004 left this open too) and the app token in `env`; (2) GitHub-hosted runners
   have unrestricted egress, so a stolen token can leave by `curl`. The goal "no secrets in the job except that token" cannot hold for the OAuth
   token while the CLI runs inside the job. Worst case is the loss of Daniel's subscription token, not repo content.

C. B plus capability narrowing, so that the remaining token can do little: see section 4.

D. Run developer steps in a container or a separate job without the OAuth token (design 0004 option C). Strongest, but the action takes the token as its
   own input, so it means replacing the action. Not chosen for v1.

E. Egress allow list (a proxy or `step-security/harden-runner` in block mode). Closes the exfiltration path of B, but adds a third-party action to
   every model job and a list to maintain (api.anthropic.com, github.com, pypi.org ...). Rejected for v1, named as the next lever if the owner
   wants a free shell and the residual risk is too high.

Already true and independent of the shell: with `contents: write` and `workflows: write` a dev run can push `agent/x` containing a workflow with an
`on: push` trigger. Workflows on same-repo branches run with the repo secrets (`AUTHOR_APP_KEY`, `GUARD_KEY`, `CLAUDE_CODE_OAUTH_TOKEN`), before any
reviewer sees the PR. This is a larger hole than the command list closes, and it is not changed by option A or B. Only C narrows it.

## 4. Chosen approach

C, staged so the owner can stop after any step. The allow lists of judging runs stay. Developer and fix runs get a free shell only after steps 1 to 3
are merged and Daniel agrees (section 9). The numbers below are the step numbers of section 8.

1. **Measure** (step 1): denied calls per workflow from the execution files, 7 days. The shell decision is made on that number, not on this study.
2. **Checkout and refs** (step 2): a second ruleset `.github/rulesets/agent-refs.json`: all branches except the default branch and `agent/**` cannot be
   created, updated or deleted by anyone but the repository admin role (bypass as in `main.json`), and tags cannot be created by the app. The
   app token can then only write `agent/**`. `main.json` stays as is.
3. **Token narrowing** (step 3): the dev and fix model token loses `workflows` and `actions` write; the one script step that needs `actions` write
   (`gh workflow run validate.yml`, `agent-dev.yml:240`) gets its own short token. Decided (the safer, reversible path): a dev or fix run whose diff
   touches `.github/workflows/` is not pushed. GitHub refuses that push (no `workflows` scope); a script step reports the refusal on the issue for
   Daniel, who applies the change himself. A script-step push for such files is a later issue, not part of this design.
4. **Judging runs unchanged** (step 4): reviewers, security reviewer, scout, unblocker and answer-receiver keep their read-only tools (0004). Step 4
   pins this with a test (section 6).
5. **Orchestrator** (step 5): after the dispatcher (#415, design 0015) starts the work, the orchestrator writes only comments and labels. Its tool list
   becomes `gh issue comment|edit|view|list`, `gh pr comment|view|list|edit`, `gh label create`; `Edit`, `Write`, `git`, `make` and `contents: write`
   are removed. Depends on the dispatcher issues being merged (cross-design, not a step number: open until the dispatcher steps are numbered).
   HANDOVER.md PRs (`orchestrator.yml:240-251`) are moved, not dropped: the model returns the new text (max 60 lines) as its output (open: how
   claude-code-action hands it to a later step; step 5 verifies), and a script step with its own `contents: write` token, outside the model env,
   commits it to `agent/handover` and opens the PR as today.
6. **Free shell** (step 6, owner decision): `agent-dev.yml` and `agent-fix.yml` drop the `Bash(...)` list for `Bash` and keep the `--settings` deny rules
   (they still protect `Read`). The prompt loses the "one simple command per call" paragraph. A repo variable `DEV_SHELL=free` switches it, default
   off. Open: the whole Bash deny for destructive paths, not needed if refs are confined by step 2.

Per-job table. Egress is open for every job: hosted runners have no egress filter, so every job can reach any host; the column lists what it
needs, not what is enforced. "Reach if compromised" means what injected text or a malicious dependency can do with the job's token and secrets.

| Job | Model-job token (today -> chosen) | Secrets in the model job | Needs egress to | Reach if compromised |
|---|---|---|---|---|
| agent-dev, agent-fix | contents, workflows, pull-requests, issues, actions write -> contents, pull-requests, issues write, refs confined to `agent/**` | OAuth token (action input), app token in env | api.anthropic.com, github.com, pypi.org (`EXTRA_INSTALL`) | OAuth token (by shell or by a pushed workflow, today also), pushes to `agent/**`, comments; today also all repo secrets through a pushed `on: push` workflow |
| orchestrator | contents, pull-requests, issues write -> issues, pull-requests write | OAuth token, app token | api.anthropic.com, github.com | all issues, PR comments, labels; today also `contents` write (HANDOVER.md PRs) |
| agent-review, agent-security-review | pull-requests write (approver app), checkout of `main` with `persist-credentials: false` | OAuth token, approver app token | api.anthropic.com, github.com | approve or request changes on any PR (the approval is still one of the required gates; CODEOWNERS and the checks stay) |
| unblocker, answer-receiver | read only in the model job, write token in the later script job | OAuth token only | api.anthropic.com, github.com | the OAuth token through `Read` outside the deny list (open, 0004); verdict file is validated before any write |
| scout | issues write, security alerts read | OAuth token, app token | api.anthropic.com, github.com | creates issues (labels `approved` are Daniel's, trust rules in `tools/trusted_issues.py`) |
| dispatcher (0015, no model) | issues write | none (no model) | github.com | label and comment writes only |

Remaining gates for everything a free-shell run produces: required `validate`, `agent-smoke`, `risk`, `security-review` checks, the security reviewer on
risk classes, CODEOWNERS review by Daniel on guarded paths, no merge without one approval (`main.json`). These gates protect `main`; they do not
protect a secret that leaves the runner during the run.

## 5. Migration and compatibility

- Steps are additive and each has a switch or a revert: the refs ruleset is imported by hand (README, setup step 4, AGENTS.md Limits 2 and 5);
  `DEV_SHELL` defaults to off, so nothing changes until Daniel sets it.
- Downstream projects take the files through the template sync. The refs ruleset is a new managed file; a project imports it like `main.json`.
- A dev or fix run that today pushes a workflow change (workflow fixes, changes under `.github/workflows/`) is affected by step 3: the push is refused
  and the change goes to Daniel, who applies it by hand. This is the one task type that becomes manual; it is not impossible, and it is the
  reversible choice of section 4 item 3.

## 6. Test and verification plan

Each fails on today's code:
- `run_stats`: a fixture execution file with two `permission_denials` gives `denied: 2` for its workflow; today the key does not exist. Format test
  for the new line of `format_stats`. A real file from a run confirms the field name once (open).
- Refs ruleset: a test loads `agent-refs.json` and asserts `~ALL` minus `refs/heads/agent/**` minus the default branch, rules `creation`, `update`,
  `deletion`, the same bypass as `main.json`, plus a tag rule. Today the file does not exist. A manual check by Daniel after import: a push of
  `foo/x` with the app token is refused, `agent/1-x` is accepted (recorded in the step PR, open until run).
- Token scope: a workflow test parses `agent-dev.yml` and `agent-fix.yml` and asserts the model-step token has no `permission-workflows` and no
  `permission-actions`; today both are present. The same test asserts that the report step for a refused workflow push exists.
- Judging runs: `tests/test_judge_boundary.py` checks the five judging workflows (agent-review, agent-security-review, scout, unblocker,
  answer-receiver): no `Edit`/`Write` (except the exact string `Edit(verdict.json)`), only the listed `gh` forms, and no write permission in the
  model job. Named gaps on today's code, found by reading the workflows: `agent-review.yml:46` and `agent-security-review.yml:49`
  (`pull-requests: write`, needed for `gh pr review`) and `scout.yml:45` (`issues: write`, needed for `idea_route.py create`) fail the strict
  rule. Step 4 records these three as the only allowed write tokens in a model job, by name; then the test passes on today's code and fails on any
  new write scope, `Edit`/`Write` or Bash form. `Edit(verdict.json)` in `unblocker.yml:84` and `answer-receiver.yml:93` is pinned by its exact string.
- Orchestrator: asserts the `--allowedTools` string contains no `Edit`, `Write`, `git` or `make` and the token has no `permission-contents`; fails today.
- Free shell: asserts `DEV_SHELL` off keeps today's list and on yields bare `Bash`, with the 0004 deny settings still passed. A measurement run
  on a test repo tries `cat /proc/self/environ` as the model and records whether the token is visible (open: decides whether step 6 is acceptable).
- `make check` (actionlint, zizmor) on every workflow change.

## 7. Rollback

Each step is one rebase-merged commit. `DEV_SHELL` unset restores the allow list at once without a code change. The refs ruleset is removed in
*Settings > Rules*. The narrowed tokens revert with the commit. Nothing here deletes data.

## 8. Split into PR-sized implementation issues

Each issue carries `Design: docs/design/0017-safety-boundary.md`, at most ~400 changed lines.

### Step 1: Count denied tool calls per workflow
Files: `tools/run_stats.py`, `tests/test_run_stats.py`
Acceptance: `run_stats.py` prints denied calls per workflow for the last N days from the execution files and a test with a fixture proves the sum.

### Step 2: Refs ruleset that confines the app token to agent branches
Files: `.github/rulesets/agent-refs.json`, `tests/test_rulesets.py`, `.agents/managed.json`
Acceptance: the ruleset file restricts creation, update and deletion of every branch except the default branch and `agent/**` and tag creation; a test pins it.

### Step 3: Drop workflows and actions write from the dev and fix model token
Files: `.github/workflows/agent-dev.yml`, `.github/workflows/agent-fix.yml`, `tests/test_model_token_scope.py`
Acceptance: the model-step token has no `permission-workflows` or `permission-actions`; the CI-trigger step uses its own short token; a dev or fix
push that changes `.github/workflows/` is refused by GitHub and the run reports it on the issue for Daniel (no script-step push in this design);
a test pins the token scope and the report step.

### Step 4: Judging runs pinned read-only by test
Files: `tests/test_judge_boundary.py`
Acceptance: a test fails when a reviewer, security reviewer, scout, unblocker or answer-receiver model step gains `Edit`, `Write`, a write-scope token
(beyond the three named in section 6) or a `Bash` form outside its list.

### Step 5: Orchestrator comment-only tool set
Files: `.github/workflows/orchestrator.yml`, `tests/test_orchestrator_tools.py`
Acceptance: the orchestrator tool list has no `Edit`, `Write`, `git` or `make` and its token no `contents` scope; HANDOVER.md is committed by a script
step with its own `contents: write` token (section 4 item 5); the dispatcher (#415) steps are merged first (open: numbers).

### Step 6: DEV_SHELL switch for a free shell in dev and fix runs
Files: `.github/workflows/agent-dev.yml`, `.github/workflows/agent-fix.yml`, `.agents/roles/developer.md`, `tests/test_dev_shell_switch.py`
Acceptance: with `DEV_SHELL` unset the allow list is unchanged; with `free` the model step gets bare `Bash` and keeps the deny settings; owner decision 1 is "ja".
Depends on: 2, 3

### Step 7: Decision record and README
Files: `docs/decisions/<next free number>-safety-boundary.md` (0016 at the time of writing; check the folder first, 0009 and 0010 are taken), `README.md`, `README.de.md`
Acceptance: the per-job table and the chosen steps are in the decision record; the README names `agent-refs.json` and `DEV_SHELL`.
Depends on: 2, 3, 6

Steps 1 to 5 are independent with disjoint files and run in parallel (step 5 waits for #415 by hand, not by `Depends on`). Steps 3 and 6 both edit
`agent-dev.yml`, hence 6 depends on 3. Steps 2, 3, 5 and 6 are `risk:security` (permissions, tokens, rulesets) and need the security reviewer;
step 2 adds a ruleset file and needs Daniel as code owner.

## 9. Owner decisions

Deutsche Notiz fuer Daniel:

1. **Duerfen Entwickler-Laeufe eine freie Shell bekommen (Schalter `DEV_SHELL=free`)?** Heute duerfen sie nur eine Liste von Befehlen, das kostet
   Laeufe und Prompt-Text. Mit freier Shell kann ein Lauf jeden Befehl ausfuehren, auch einen, der den Zugangs-Token der Claude-Subscription
   ausliest und ins Netz schickt (die Runner haben keine Netzsperre). Schlimmster Fall: der Token wird gestohlen und fremd genutzt; er laesst sich
   widerrufen, der Schaden ist Kosten und Quota, kein Zugriff auf `main`. Wahrscheinlichkeit: gering bis mittel, es braucht einen Issue-Text oder eine
   Abhaengigkeit, die den Lauf lenkt; Issues von Fremden loesen keine Laeufe aus (nur von dir oder mit `approved`). Was danach noch haelt: die vier
   Pflicht-Checks, der Security-Reviewer, deine Freigabe fuer CODEOWNERS-Pfade und, nach Schritt 2, ein Token, der nur `agent/*` schreiben darf. Was
   nicht haelt: ein Token-Diebstahl waehrend des Laufs. Empfehlung dieser Studie: erst die Schritte 1 bis 5 (Messung, schmalerer Token, Ref-Regel), dann
   mit der Messung entscheiden; "ja" = Schritt 6 wird gebaut, der Schalter bleibt zunaechst aus; "nein" = die Befehlsliste bleibt, nur ihre Pflege wird
   mit der Messung gezielter. Frage: Soll Schritt 6 (Schalter fuer die freie Shell) gebaut werden?
2. **Import der Ref-Regel (Schritt 2) in *Settings > Rules*?** Eine falsche Regel kann Pushes der Agents blockieren oder zu viel freigeben; sie kann in
   Sekunden entfernt werden. Empfehlung: ja, nach Pruefung durch den Security-Reviewer. "ja" = du importierst die Datei, wenn Schritt 2 gemerged ist; "nein" =
   Schritt 2 wird gemerged, die Datei bleibt ungenutzt und Schritt 6 entfaellt.

Neither answer is needed to accept this design; steps 1, 3, 4 and 5 need no owner decision beyond the normal review.
