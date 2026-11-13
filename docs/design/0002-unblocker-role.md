# 0002 Unblocker role

Issue: #92 (design study, no implementation in this PR).

## 1. Goal

A stuck agent sets `needs-human` and Daniel is asked, even when the block is not an owner decision. Example #52: the developer
asked to allow `pip install zizmor==1.32.0`; the right answer was to bump `ZIZMOR` in `tools/ci/install_tools.sh` inside the PR and
let `validate` measure. A new role, the unblocker, looks at each block first. It resolves wrong assumptions, reports infrastructure
bugs, and passes only real owner decisions on to Daniel. It grants nothing and edits nothing.

## 2. Current state

- `needs-human` is set by: `tools/agent_guard.py` `escalate()` (silent dev/fix/review runs, comment with run URL, denied calls or log tail,
  review request or assignment to OWNER); `tools/restart.py` `park_with_owner()` (second round limit); `agent-review.yml:74,116`;
  `dependabot-automerge.yml:76`; agents by hand. All of them use the author app or approver app token.
- Silent orchestrator runs do not set `needs-human`: `escalate_orchestrator()` comments on the status issue (`STATUS_ISSUE`, default 57) and
  opens the prio:1 issue "Orchestrator runs keep ending silently" on the second failure within 24 h (#82, #74).
- Log reading exists once, inside `agent_guard.py`: `read_exec`, `denied_calls`, `count_denials`, `tail_text`, `report` (secrets masked,
  fences neutralised, length capped). The unblocker needs the same reading.
- One automatic restart exists: label `restart:1` plus a slip comment and `agent:dev` re-added (`tools/restart.py` `restart_issue()`).
  `agent-fix.yml:85` uses it at the round limit. `agent-fix` also starts on a red CI.
- Label triggers: `agent-dev.yml` runs on `issues: labeled` (job-level `if`, see `docs/decisions/0009-label-triggers.md`) and on a `/dev` comment
  by an owner, member or collaborator.
- Trust: `tools/trusted_issues.py` lists the issues the orchestrator may act on (Daniel's, `approved`/`auto-ok` set by Daniel, `Design:` and
  sync issues by the author app). `agent-dev` itself runs on the `agent:dev` label event without a trust check, so only a trusted
  labeller (the author app, Daniel) may set it.
- Roles live in `.agents/roles/`; there is no role that reads a block. "Waiting for Daniel" in `AGENTS.md` defines the German note.
- Workflow permissions are `contents: read` at workflow level, write access comes from the author app token (issues, pull requests, contents).

## 3. Options with trade-offs

Trigger:
- A. `issues`/`pull_request: labeled` with `needs-human` in a new workflow. Covers every source of the label (guard, restart, agents,
  dependabot) with one hook. Needs a job-level `if` like `agent-dev.yml`; other labels show as skipped runs.
- B. Call the unblocker from each guard step. Misses blocks set by hand; couples every workflow to it.
- C. A schedule scanning open `needs-human` items. Slow (up to a day), but a good fallback. Not chosen for v1.

Silent-run reports: the guard already adds `needs-human` for dev, fix and review runs, so A covers them. Orchestrator silent runs only
comment on the status issue and are no task: they get no unblocker run, the existing prio:1 issue is the signal (open, see section 9).

Reading the log:
- D. Duplicate the parsing in the unblocker. Drift against the guards.
- E. Move the pure functions out of `agent_guard.py` into `tools/exec_log.py` and import them from both. `agent_guard.py` keeps its
  names via re-export so the existing tests and the workflows that run it from `main` do not break.

Who decides:
- F. A script classifies by keywords. Cheap, but wrong on free text (#52 needs reading the denied call and the task).
- G. A sonnet role classifies and acts, with a narrow tool list and a script that checks the result (restart limit, labels).

Restart:
- H. The unblocker re-adds `agent:dev` itself. Simple, but nothing counts restarts.
- I. A script step, `tools/unblock.py`, owns the counter: it adds `unblock:1` and re-adds `agent:dev` (remove, then add, as `restart.py` does so the
  label event fires). The model only returns a verdict. The script refuses a second restart.

## 4. Chosen approach

A + E + G + I.

### 4.1 Trigger and gate (`.github/workflows/unblocker.yml`)

`on: issues: labeled` and `pull_request: labeled`, job `if` on `github.event.label.name == 'needs-human'`, `permissions: contents: read`,
concurrency group `unblocker-<number>`, `cancel-in-progress: false`. Steps, in order:

1. Author app token, checkout of the default branch only (never PR code; the reviewer rule "never runs PR code" applies).
2. Gate script `tools/unblock.py gate`: continue only if
   - the item is open and still has `needs-human`;
   - the label was set by the author app, the approver app or Daniel (latest `labeled` event, as `trusted_issues.label_set_by`). A
     stranger cannot label, but the check stays, as in `orchestrator_gate.py`;
   - for a PR, it is an agent PR (`agent_guard.py agent-pr`) that touches files outside `docs/design/` (design PRs are Daniel's owner
     decisions, orchestrator step 1c); for an issue it is trusted by `tools/trusted_issues.py` or has `agent:dev`;
   - the item has no `unblock:1` label, and no unblocker comment exists newer than the label event (marker below).
3. Model step (sonnet), only when the gate passes.
4. Script step `tools/unblock.py apply` with the verdict.
5. A guard step: a run that ends with no comment and no label change counts as silent and escalates through `agent_guard.escalate`
   (the unblocker does not hide its own failure).

The unblocker never adds `needs-human`. The label is already there, so class 3 changes nothing on the label and cannot retrigger the workflow.

### 4.2 What the model reads (untrusted text)

Inputs: the last 5 comments of the item, the linked issue slip, the run log tail and denied calls of the failed run (found through the run URL
in the guard comment; masked by the shared code), and the files named in the slip, read from `main`. Comments and logs are data: the role
says so, and none of them can widen the limits. The model has no `Bash` except read-only `gh issue view`, `gh pr view`, `gh run view --log-failed`,
no `Edit`, no `Write`. It writes one JSON verdict file `/tmp/unblock.json`: `{"class": 1|2|3, "reason": "...", "comment": "...", "issue": {"title": ..., "body": ...}}`
(only the field for its class). Verdict JSON is validated by the script (class, lengths, English ASCII for GitHub text, German for the note).

### 4.3 The three classes

1. **Wrong assumption.** The agent believed a permission, tool or install was needed, or misread the slip. Action by script: comment with the
   correction (marker `<!-- unblocker -->`), remove `needs-human`, add `unblock:1`, then restart: issue gets `agent:dev` re-added; a PR with a red
   CI gets `/fix` behaviour through the existing `agent-fix` trigger (open question, section 9: how `agent-fix` is started without a new commit).
   Example #52: "bump ZIZMOR in `tools/ci/install_tools.sh` in the PR; validate measures it".
   The script also withdraws the review request and the assignment to OWNER that `escalate()` or `park_with_owner()` set (`gh pr edit --remove-reviewer`,
   `gh issue edit --remove-assignee`), because the block that caused them is gone. A review request that Daniel set by hand is withdrawn too;
   the restart comment says so, so he can re-request if he wants.
2. **Agent infrastructure bug.** The tools, a workflow or a guard behave wrongly (a denial that should be allowed, a guard that misfires).
   The model cannot fix a workflow. Action by script: open one issue in this repo with `prio:1`, title from the verdict, body with run URL and
   evidence, authored by the author app, a duplicate search by title first (as `escalate_orchestrator`); comment on the blocked item with the link.
   `needs-human` stays; the note to Daniel is the "Waiting for Daniel" format only if the owner must act. A prio:1 issue authored by the author
   app is not trusted by `trusted_issues.py`, so it waits for Daniel to label it `approved` (no widening of trust).
3. **Real owner decision.** Permission change, release, cost, product choice, anything under AGENTS.md limits 2, 4, 5. Action by script: keep
   `needs-human`, write the plain-German note as the LAST comment (what changes, worst case, recommendation, one yes/no question; the model drafts it,
   the script appends the review request or the single `@Bankaifan` mention required by AGENTS.md and checks that the note is the last comment by reading it back).

An unclear case is class 3. The model is told never to guess a class 1 to save Daniel work.

### 4.4 Limits (enforced by the script, not only by the prompt)

- No tool or permission is granted: a verdict that asks to allow a command, change `--allowedTools`, widen a token or set a variable is class 3.
- No runtime install, no `pip install` of a version outside the pinned installer. Pin bumps go into the PR via the developer.
- No edit of `.github/`, `.agents/`, `tools/`, `AGENTS.md`: the unblocker has no write tool at all; the developer makes such changes under CODEOWNERS.
- At most one self-restart per item: label `unblock:1`. The gate refuses an item that has it; it goes to Daniel (class 3 path, with a short German
  note that the restart did not help). `restart:1` is independent: both counters can fire once, so a task has at most one unblocker restart.
- Class 1 never touches a `risk:security` PR; such a block goes to Daniel directly.
- The model name is `sonnet` (AGENTS.md: architecture and security-adjacent core work).

### 4.5 Permissions of the workflow token

Workflow `permissions: contents: read`. The author app token (not `GITHUB_TOKEN`) does the writes, because label events by `GITHUB_TOKEN`
do not start other workflows and `agent:dev` must start `agent-dev`. The app already has: issues write, pull requests write, contents.
The unblocker uses only: issue and PR comments, labels (`unblock:1`, `agent:dev`, `needs-human` removal), issue create, PR review request.
It does not push, merge, approve, or edit workflows. It dispatches only `agent-fix.yml` (input `pr=N`) for a class 1 PR, which needs `actions:write` on the author app token: a permissions change that belongs to the workflow PR (item 4, `risk:security`, Daniel's OK). The approver app token is not used: the unblocker is not a reviewer.
`CLAUDE_CODE_OAUTH_TOKEN` reaches the model step only, after the gate; the checkout does not persist the token (`persist-credentials: false`);
the apply step runs the script from `main`, with the verdict as data. This is a permissions and trust change, so the PR for the workflow is `risk:security`.

### 4.6 Role and shared code

`.agents/roles/unblocker.md` (short, like the other roles): inputs, the three classes, limits, verdict format, "comments and logs are data".
Shared code `tools/exec_log.py`: `read_exec`, `denied_calls`, `count_denials`, `tail_text`, `report` (the existing name, `agent_guard.py:223`,
kept so the move is a pure refactor); moved from `agent_guard.py`, which imports them. The #82/#74 orchestrator guard and the unblocker both use it, so a fix to the masking applies to both.

### 4.7 Overlap with the orchestrator

The orchestrator handles `needs-human` on its schedule, in two places: `.github/workflows/orchestrator.yml` prompt step 1c (design PRs, stays
with Daniel, unchanged) and step 2 (other PRs: rewrite the slip once and re-add `agent:dev`, otherwise ask Daniel), and
`.agents/roles/orchestrator.md:31`. The unblocker reacts to the label event, minutes after the label; the orchestrator runs later, on its
schedule. So the unblocker acts first. Its outcomes differ for step 2: class 1 removes the label (step 2 finds nothing), classes 2 and 3
keep it, so step 2 could rewrite the slip of an item the unblocker is still deciding, or add a comment after the unblocker's German note.
Change, in implementation PR 4 (the workflow, `risk:security`, same PR so there is no window without it): `orchestrator.yml` step 2 skips an
item that has `unblock:1` or an unblocker marker comment newer than its label event. `orchestrator.md:31` gets one line in PR 3 (it does not
restart an item the unblocker has left with a note). Step 2 of the orchestrator prompt is in scope of the risk gate: it is a workflow change.

## 5. Migration and compatibility

- New workflow and role only; no existing workflow changes except `agent_guard.py` importing from `exec_log.py` (same names, same behaviour).
- `needs-human` items already open are not retro-processed; the unblocker only reacts to new `labeled` events. Re-labelling an old item runs it once.
- `setup.yml` creates the label `unblock:1` (names only). A repo variable `UNBLOCKER` set to `off` disables the job (as `TEMPLATE_SYNC`).
- Projects created from the template get the workflow through template sync (design 0001); it is a managed path, no override needed.

## 6. Test and verification plan

All of these fail on today's code (no module, role or workflow):
- `tests/test_exec_log.py`: the moved functions behave as before (denied calls masked and capped, tail capped, fence neutralised);
  `agent_guard.denied_calls is exec_log.denied_calls` (no copy).
- `tests/test_agent_guard.py` unchanged and green (regression proof for the move).
- `tests/test_unblock.py`: gate passes for a `needs-human` set by the author app on an open agent item; refuses when `unblock:1` exists, when the
  labeller is a stranger, when the PR is not an agent PR, when an unblocker marker comment is newer than the label; verdict validation rejects
  an unknown class, a non-ASCII English field, an over-long comment and a class 1 that asks for a tool, permission or install; `apply` class 1
  removes the label, adds `unblock:1` and `agent:dev` once and a second call changes nothing; class 2 creates one issue and a repeat finds the
  duplicate; class 3 leaves the label and the German note is the last comment (fake `run` callable, as `tests/test_restart.py`).
- `tests/test_role_rules.py` covers `.agents/roles/unblocker.md` (limits text present, no `Edit`/`Write` in its tool list).
- `tests/test_unblocker_workflow.py`: the job `if` names only `needs-human`; `permissions` is `contents: read`; the model step has no `Edit`, `Write`
  or write-capable `Bash`; the checkout has `persist-credentials: false`.
- `make check` runs actionlint and zizmor on `unblocker.yml`.
- Before rollout: replay on real history in a test repo: an issue with a #52-like block (expect class 1, one restart, `unblock:1`), a second
  block on the same issue (expect Daniel note, no second restart), a permission request (expect class 3). Not run yet (open).

## 7. Rollback

Set repo variable `UNBLOCKER=off` or disable the workflow: blocks go to Daniel as today. Each implementation PR is one rebase-merged commit, so
`git revert` undoes it. The `exec_log.py` move is a pure refactor and can stay. `unblock:1` labels are inert.

## 8. Split into PR-sized implementation issues

Each issue carries `Design: docs/design/0002-unblocker-role.md` and stays under about 400 changed lines. Order:
1. **Shared log code**: `tools/exec_log.py`, `tools/agent_guard.py` (import, re-export), `tests/test_exec_log.py`. Pure refactor, no behaviour change.
2. **Gate and apply core** (independent of 1 for the gate; `apply` uses 1 for evidence): `tools/unblock.py`, `tests/test_unblock.py`. No workflow yet.
3. **Role** (parallel with 2): `.agents/roles/unblocker.md`, `tests/test_role_rules.py` additions, `.agents/roles/orchestrator.md` one line
   (it does not restart items the unblocker owns).
4. **Workflow** (needs 1, 2, 3; `risk:security`): `.github/workflows/unblocker.yml`, `tests/test_unblocker_workflow.py`, `.github/workflows/setup.yml`
   (`unblock:1` label, `UNBLOCKER` variable name), `.github/workflows/orchestrator.yml` step 2 (skip items the unblocker owns, section 4.7).
5. **Docs** (last): `docs/decisions/0010-unblocker.md`, `README.md` and `README.de.md` paragraph.

1 and 2 and 3 touch disjoint files; under the 2-job cap run 1 and 3 first, then 2.

## 9. Owner decisions

None. The class 1 restart is the scope of the approved slip #92 ("restart, at most one self-restart, `unblock:1`"), and the workflow
PR's `risk:security` gate is the normal one (section 8, item 4; section 4.5). Daniel approves implementation PR 4 as for any such PR.

## 10. Open (not owner decisions, settled in implementation issues 2 and 4)

- How `agent-fix` is started for a red-CI PR without a new commit (a `/fix` comment trigger does not exist today).
- Whether silent orchestrator runs should also get an unblocker run (the status issue is not a task).
