# 0001 Template sync

Issue: #19 (design study, no implementation in this PR).

## 1. Goal

Projects created from this template (or ported, like ha-luxtronik-shi) get later template changes without a blind
file copy that would break their adapted files. A weekly script detects template changes, one issue describes them,
the normal developer flow ports them, and Daniel approves the PR because it touches code-owner paths.

## 2. Current state

- No link from a project back to the template exists. Agent files are copied once ("Use this template", `README.md` `## Setup`).
- Project-specific differences are edited inline today:
  - `.github/workflows/agent-fix.yml:11` and `agent-review.yml` use `workflow_run.workflows: [validate]`; ported projects
    name their CI `Validate`. `workflow_run.workflows` cannot use variables or expressions.
  - `python-version: "3.x"` is hard-coded in `validate.yml:23`, `agent-dev.yml:41`, `agent-fix.yml:134`.
  - Extra install steps go into `tools/ci/install_tools.sh` (it already reads `requirements.txt` and `requirements_test.txt`).
    The extra command comes from the repo variable `vars.EXTRA_INSTALL`, never from a file on the PR branch (section 4.5).
  - `AGENTS.md` line 2 (project sentence) and `HANDOVER.md` are project content.
- Variables already used: `RUNNER`, `AUTHOR_BOT`, `APPROVER_BOT`, `ORCHESTRATOR_ENABLED`, `IDEAS_PER_WEEK`.
- Trust: `tools/trusted_issues.py` trusts Daniel's issues, `approved`/`auto-ok` set by Daniel, and `AUTHOR_BOT` issues with a
  `Design:` line naming an existing file. A sync issue from the author app is not trusted today.
- Scripted issue writer to copy the pattern from: `.github/workflows/weekly-summary.yml` + `tools/weekly_summary.py`
  (author app token, no model).
- `.github/`, `.agents/`, `tools/check/`, `AGENTS.md` are code-owner paths (`.github/CODEOWNERS`), so a sync PR needs Daniel.

## 3. Options with trade-offs

Detecting changes:
- A. Git compare `GET /repos/{template}/compare/{synced_sha}...main`, filtered by managed paths. Exact, cheap, no clone.
  Needs the recorded SHA to be an ancestor of `main` (true unless the template history is rewritten).
- B. Compare file hashes per path. Independent of history, but cannot tell a template change from a project change,
  so adapted files are reported every week.
- C. A bot copies the template files. Rejected: overwrites adaptations.

Adaptations:
- D. Whole-file overrides listed in `template.json`. Simple, coarse.
- E. Section markers inside template files. Too invasive for YAML.
- F. Reduce the need for overrides by moving values to variables or `project.env`.

Values:
- G. Repo variables (`vars.X`): usable in `runs-on`, `with:`, `env:`, `if:`; not in `on:` or `workflow_run.workflows`.
- H. `.agents/project.env`: versioned with the repo, usable only after checkout, a code-owner path. Rejected for commands:
  a PR can change it, and its values would run in a job with the app token before review (section 4.5). Plain data values
  could still use it, but no value needs it yet.

Who ports:
- I. A script merges automatically. Fragile on adapted files.
- J. The developer (sonnet) ports from the diff summary and the override list. Reuses the existing flow, review and CODEOWNERS gate.

## 4. Chosen approach

A + D + F (via G only) + J.

### 4.1 `.agents/template.json`

```json
{
  "template": "Bankaifan/agent-template",
  "synced_sha": "<40 hex>",
  "managed": [".github/workflows/", ".github/dependabot.yml", ".github/CODEOWNERS", ".github/rulesets/",
              ".agents/roles/", "tools/", "tests/", "AGENTS.md", "CLAUDE.md", "Makefile", "docs/design/README.md"],
  "overrides": [
    {"path": ".github/workflows/agent-fix.yml", "why": "workflow_run.workflows needs the CI name 'Validate'"},
    {"path": "AGENTS.md", "why": "project sentence and project rules"}
  ]
}
```

- `managed`: path prefixes the template owns (trailing `/` = directory). Everything else (`HANDOVER.md`, `README*`,
  `docs/decisions/`, project code) is never reported.
- `overrides`: `path` (exact match) and `why` (free text for the developer).
- The sync is a no-op when `.agents/template.json` is missing or `synced_sha` is empty.
- Template detection: the repo is the template itself when `template` equals `GH_REPO` (case-insensitive string compare). Then the
  script prints `template-sync: this repo is the template, skipped` and exits 0.
- `.agents/template.json` is not committed to the template repo. The example lives in `README.md` and `README.de.md` (section 8,
  item 4), so projects created with "Use this template" do not inherit a file that would point at the template.

### 4.2 Diff and override logic (`tools/template_sync.py`: pure functions plus a thin `gh` wrapper)

- `changed_files(compare_json, managed)`: list of `{path, status}` inside `managed`; a rename counts both paths.
  The compare API caps `files` at 300 entries. If the list has 300 or more entries, the response may be truncated, so
  `changed_files` raises `TruncatedCompare`. The script exits 1 with a message and creates or edits no issue. A partial
  list would hide changes with no sign of it, so the run fails loudly instead.
- `split_overrides(changed, overrides)`: `(clean, overridden)`. `clean` can be ported as is, `overridden` needs judgment.
- `render_issue(main_sha, clean, overridden, stat)`: title `Template sync <short SHA of template main>`, body with a summary
  line, both file lists (overridden ones with their `why`), the compare URL and the line `Template-Sync: <full main SHA>`.
- `pick_issue(open_issues)`: the open issue whose title starts with `Template sync `. At most one is open: if it exists it is
  edited (title and body), otherwise one is created. No managed changes: exit 0, nothing created.
- `bump(template_json_text, sha)`: returns the text with only `synced_sha` replaced (used by tests and the developer step).

### 4.3 `template-sync.yml`

`schedule` weekly + `workflow_dispatch`, `permissions: contents: read`, concurrency group `template-sync`, no model.
Steps: author app token, checkout without persisted credentials, `python3 tools/template_sync.py` with `GH_TOKEN` and `GH_REPO`.
Skipped when repo variable `TEMPLATE_SYNC` is `off`. The issue gets labels `agent:dev` and `model:sonnet` and is authored by the
author app. Reading a private template needs the author app installed on the template repo: open, and an owner decision (section 9).

### 4.4 Trust and handling

- `trusted_issues.py` also trusts an issue when its author is `AUTHOR_BOT`, its title starts with `Template sync ` and its
  body has a line `Template-Sync: <40 hex>`. Authorship by the app cannot be forged; the body is generated from the template's own repo.
- The developer role gets a short block: port `clean` files from the template at the SHA in the issue, port `overridden`
  files by hand keeping the recorded intent, never touch paths outside `managed`, set `synced_sha` to the issue's SHA, one PR.
  The PR touches `.github/`, so CODEOWNERS requires Daniel.
- The PR says `Closes #<sync issue>`. The next weekly run opens a new issue only when `synced_sha` is behind again.

### 4.5 Project values

| Value | Mechanism |
|---|---|
| Python version | repo variable `PYTHON_VERSION`: `python-version: ${{ vars.PYTHON_VERSION \|\| '3.x' }}` |
| Extra install command | repo variable `vars.EXTRA_INSTALL`, passed as env to `install_tools.sh`, which runs it after the common tools |
| CI workflow name | documented override: `workflow_run.workflows` in `agent-fix.yml` and `agent-review.yml` |
| Runner, bots | unchanged (`vars.RUNNER`, `vars.AUTHOR_BOT`, `vars.APPROVER_BOT`) |

`EXTRA_INSTALL` is shell code, so its source matters. It comes only from the repo variable `vars.EXTRA_INSTALL`, which a PR cannot
change. An earlier draft read it from `.agents/project.env` on the PR branch. That is rejected: `agent-fix.yml` (lines 124-137)
checks out the PR branch with the author-app token persisted and runs `install_tools.sh` before the model step, so a command on the
branch would run unreviewed, next to `CLAUDE_CODE_OAUTH_TOKEN`. CODEOWNERS only gates merge, so it does not help here.
`install_tools.sh` runs `EXTRA_INSTALL` with `bash -c` only when it is set and non-empty. It never reads `.agents/project.env`.
Setting the variable is a repo-settings change by an owner, so it is listed under section 9 as well.

## 5. Migration and compatibility

- Existing projects add `.agents/template.json` once by hand: `synced_sha` = the template commit they last matched
  (if unknown, the template commit at creation; a too-old SHA only makes the first issue larger), plus the known overrides.
- Without `template.json` the workflow prints `template-sync: no .agents/template.json, skipped` and succeeds.
- `PYTHON_VERSION` unset keeps `3.x`; `EXTRA_INSTALL` unset keeps today's behavior. Nothing breaks for existing projects.
- `setup.yml` lists `TEMPLATE_SYNC`, `PYTHON_VERSION` and `EXTRA_INSTALL` as optional variables (names only).
- `EXTRA_INSTALL` unset keeps today's behaviour.

## 6. Test and verification plan

All of these fail on today's code (module, workflow and files do not exist):
- `tests/test_template_sync.py`: `changed_files` ignores non-managed paths and counts renames; `split_overrides` matches exact paths;
  `render_issue` contains title, both lists and the `Template-Sync:` line; `pick_issue` returns the open one and never a second;
  `bump` changes only `synced_sha`; empty compare creates nothing; missing or invalid JSON gives a clear error.
- `tests/test_trusted_issues.py`: sync issue by `AUTHOR_BOT` is trusted; the same title by a stranger, or without the
  `Template-Sync:` line, is not.
- `tests/test_install_tools_env.py`: with `EXTRA_INSTALL` unset or empty, `install_tools.sh` runs no extra command; with
  `EXTRA_INSTALL=touch <marker>` set in the environment, the command runs; a `.agents/project.env` containing
  `EXTRA_INSTALL=touch <marker>` is ignored (the marker file is not created).
- `tests/test_template_sync.py` also covers `TruncatedCompare`: 300 entries raise, 299 do not, and no issue is created or edited.
- `make check` runs actionlint and zizmor on `template-sync.yml`.
- Before rollout: `workflow_dispatch` on a test project with an old `synced_sha`. Expect one issue; a second dispatch edits it
  (no duplicate); the orchestrator picks it up; the PR requires Daniel. Not run yet (open).

## 7. Rollback

Set repo variable `TEMPLATE_SYNC=off` (the workflow exits at once) or disable the workflow. Each implementation PR is one
rebase-merged commit, so `git revert` undoes it. `template.json` is inert without the workflow. Open sync issues can be closed.

## 8. Split into PR-sized implementation issues

Each issue carries `Design: docs/design/0001-template-sync.md`. Order:
1. **Project values**: `PYTHON_VERSION` in `.github/workflows/validate.yml`, `agent-dev.yml`, `agent-fix.yml`; `EXTRA_INSTALL` from
   `vars.EXTRA_INSTALL` in `tools/ci/install_tools.sh` and the workflows that call it; `tests/test_install_tools_env.py`;
   `setup.yml` optional variable list.
2. **Sync core**: `tools/template_sync.py`, `tests/test_template_sync.py`. No workflow yet, no `template.json` file in this repo.
3. **Workflow and trust** (needs 2): `.github/workflows/template-sync.yml`, `tools/trusted_issues.py`, `tests/test_trusted_issues.py`,
   `.agents/roles/developer.md` sync block, `.agents/roles/orchestrator.md` line.
4. **Docs** (last): `README.md` and `README.de.md` "Keeping projects in sync" (incl. the `workflow_run.workflows` override and an
   example `.agents/template.json` for projects), `docs/decisions/0007-template-sync.md`.

1 and 2 touch disjoint files and may run in parallel under the 2-job cap.

## 9. Owner decisions

1. **Install the author app on the template repo** (`Bankaifan/agent-template`) so the sync job can read the compare API of a
   private template (section 4.3). This is a permission change (AGENTS.md limit 2). Open until verified.
2. **Widen what the orchestrator trusts**: `tools/trusted_issues.py` also trusts `AUTHOR_BOT` issues titled `Template sync `
   with a `Template-Sync:` line (section 4.4). This changes which issues start agent work. Needed before implementation PR 3.

The repo variable `vars.EXTRA_INSTALL` (section 4.5) is set by an owner, not by a PR. It is a repo setting, not a decision
for this design.
