# Repository variables

Every repo variable (`vars.X`, set under *Settings > Secrets and variables > Actions > Variables*) that the workflows
read, with its default, the files that read it, and its effect. Source: `grep vars. .github/workflows/`, the env names
read in `tools/`, and the workflow defaults. Secrets (tokens, keys) are not variables and are not listed here.
Unknown facts are marked "open".

| Name | Default | Read by | Effect | Allowed values |
| --- | --- | --- | --- | --- |
| `AUTHOR_CLIENT_ID` | none (required) | most workflows (`create-github-app-token`) | client ID of the author GitHub App (pushes, opens PRs and issues) | the app's client ID (not secret) |
| `APPROVER_CLIENT_ID` | none (required) | `agent-review.yml`, `agent-fix.yml`, `agent-security-review.yml`, `validate.yml`, `dependabot-automerge.yml` | client ID of the approver GitHub App (reviews, verdicts) | the app's client ID (not secret) |
| `AUTHOR_BOT` | none (required) | most workflows; `tools/agent_guard.py`, `tools/ci/risk.py`, `tools/trusted_issues.py`, `tools/unblock.py` and others (env `AUTHOR_BOT`) | bot login of the author app; marks agent PRs and issues as agent work | the bot login, e.g. `my-author[bot]` (`x`, `app/x` and `x[bot]` are treated alike) |
| `APPROVER_BOT` | none (required) | `agent-review.yml`, `agent-fix.yml`, `agent-security-review.yml`, `status.yml`, `orchestrator.yml`, `automerge.yml`; `tools/approval.py`, `tools/ci/risk.py`, `tools/prefilter.py` and others (env `APPROVER_BOT`) | bot login of the approver app; its review or verdict counts as the approval | the bot login, same forms as `AUTHOR_BOT` |
| `OWNER` | `Bankaifan` | `answer-receiver.yml` (env `OWNER` for `tools/answer.py`); other workflows hard-code `OWNER: Bankaifan`, and tools fall back to `Bankaifan` | login of the owner (Daniel): whose issues, comments and replies count as trusted | a GitHub login. Open: changing it does not affect `train`, `status` and `orchestrator`, which hard-code the owner |
| `RUNNER` | `ubuntu-latest` | `runs-on` of every workflow; shown by `setup.yml` | runner label for all jobs | any runner label, e.g. `self-hosted` |
| `PYTHON_VERSION` | `3.x` | `validate.yml`, `agent-dev.yml`, `agent-fix.yml`, `orchestrator.yml`; `setup.yml` (shown) | Python version for `setup-python` in those jobs | a version string accepted by `setup-python`. Open: exact accepted set |
| `EXTRA_INSTALL` | not set | `validate.yml`, `agent-dev.yml`, `agent-fix.yml`, `orchestrator.yml`; `tools/ci/install_tools.sh` | shell command run once after the common tools; read only from the repo variable, never from a file on a PR branch | any bash command |
| `TRAIN` | `on` | `train.yml` (job `if`) | `off` disables the merge train (rebases the oldest approved agent PR that is behind `main`) | `on` / `off`; only `off` disables |
| `ANSWER_RECEIVER` | `on` | `answer-receiver.yml` (job `if`); `setup.yml` (shown) | `off` disables the answer receiver for replies to `needs-human` items (`docs/decisions/0011-answer-receiver.md`) | `on` / `off`; only `off` disables |
| `UNBLOCKER` | `on` | `unblocker.yml` (job `if`); `setup.yml` (shown) | `off` disables the unblocker for `needs-human` items (`docs/decisions/0010-unblocker.md`) | `on` / `off`; only `off` disables |
| `TEMPLATE_SYNC` | `on` | `template-sync.yml` (job `if`) | `off` turns the daily template-sync poll off | `on` / `off`; only `off` disables |
| `TEMPLATE_SYNC_MODE` | `all` | `template-sync.yml` (env `SYNC_ALL`) | `all` skips the version gate, so every template version produces a sync PR; `version` reports only when the template's `x` moved (`docs/design/0011-automatic-template-sync.md`) | `version` / `all`; only `all` skips the gate |
| `TEMPLATE_SYNC_APPLY` | `on` | `template-sync.yml` (job `if` of `build` and `report`) | `on` ports the managed changes by script in one PR, a model runs only for conflicts (`docs/design/0014-template-sync-by-script.md`); `off` returns to the issue-only report | `on` / `off`; only `off` disables |
| `FAILURE_WATCH` | `on` | `status.yml` (env, read by `tools/status.py`) | `off` skips the failure watch (`docs/design/0008-failure-watch.md`) | `off` skips; any other value runs it |
| `STATUS_INTERVAL` | `30` (public repo), `60` (private repo) | `status.yml` (env, read by `tools/status.py`); `setup.yml` (shown) | minutes between scheduled status runs, rounded up to a multiple of 30 (the cron tick) | integer minutes; empty, non-numeric or `<= 0` means the default |
| `IDEAS_PER_WEEK` | `3` | `scout.yml` (job `if` and env `IDEAS`, read by `tools/prefilter.py`); `setup.yml` (shown) | maximum number of `idea` issues per scout run; `0` turns the scout off | non-negative integer. A non-integer makes `tools/prefilter.py` fail (`int()`) |
| `NIGHTLY_HEAVY_TESTS` | `false` | `validate.yml` (env; the Makefile deselects `slow` tests when it is exactly `true`); `nightly.yml` (job `if`); `tools/liveness.py`; `setup.yml` (shown) | `true` moves `@pytest.mark.slow` tests from PRs and `main` to the nightly run (`docs/design/0009-test-scoping.md`) | `true` / `false`; only exactly `true` enables it |
| `DESIGN_AUTOMERGE` | `on` in `Bankaifan/agent-template`, `off` elsewhere | `automerge.yml` (refuses design PRs unless `on`); `agent-review.yml` (design owner mode text) | `on` lets design PRs (`docs/design/`) auto-merge after the design reviewer approves, and the design reviewer decides Owner decisions; otherwise Daniel merges them | `on` / `off` |
| `ORCHESTRATOR_ENABLED` | not set (off) | `orchestrator.yml` (job `if`); `setup.yml` (shown) | `true` enables the orchestrator (after merges to `main`, daily, and by hand) | `true`; anything else keeps it off |
| `DISPATCH` | `off` | `dispatch.yml` (`if`); `orchestrator.yml` (prompt, env for `tools/prefilter.py`) | `on` starts issues that hold a slip by script (`tools/dispatch.py`, design 0015); the orchestrator model only writes slips and the daily handover | `on` / `off`; anything other than `on` is off |
| `ORCHESTRATOR_EVENTS` | `off` | `orchestrator.yml` (`if`, and env for `tools/orchestrator_gate.py`); `setup.yml` (shown) | `on` also wakes the orchestrator on issues, issue comments, PRs and reviews (`docs/decisions/0012-orchestrator-events.md`) | `on` / `off`; anything other than `on` is off |
| `MAX_DEV` | `4` | `orchestrator.yml` and `weekly-summary.yml` (env); `tools/prefilter.py`; `tools/weekly_summary.py` | maximum number of open `agent:dev` issues that hold a slot, i.e. agent jobs at once (parked `needs-human` issues and issues with a merged PR do not count) | integer. Empty or non-numeric falls back to the default with a warning |
| `MAX_PRS` | `5` | `orchestrator.yml` and `weekly-summary.yml` (env); `tools/prefilter.py`; `tools/weekly_summary.py` | maximum number of open agent PRs | integer. Empty or non-numeric falls back to the default with a warning |
| `DEV_SHELL` | not set (command list) | `agent-dev.yml`, `agent-fix.yml` (`--allowedTools` expression) | `free` gives developer and fix model runs bare `Bash` instead of the command list; the `--settings` deny rules stay (`docs/design/0017-safety-boundary.md`, step 6) | `free`; any other value or unset keeps the command list |

## Environment inputs that are not repo variables

Some tools also read environment names that no workflow or Makefile sets and that are not repo variables. They are
inputs for manual or local runs only:

- `STALE_DAYS` (default `7`, `tools/prefilter.py`): the staleness threshold in days for the handover check.
- `VERSION_FILE` and `VERSION_REGEX` (`tools/check/check_version.py`): the file and the regex for the version check.
