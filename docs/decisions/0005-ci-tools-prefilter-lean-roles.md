# 0005 CI tools for agents, pre-filters, lean roles

Status: accepted (Daniel approved in issue #12).

- `make check` = ruff, pytest, actionlint, zizmor and the repo checks; `tools/ci/install_tools.sh` pins the tools for validate, agent-dev and agent-fix. gitleaks runs in validate.
- `tools/prefilter.py` decides without a model whether orchestrator or scout has work; the Claude step is skipped otherwise.
- The weekly summary is `tools/weekly_summary.py` (Mondays), no model. The scout runs monthly and reads Dependabot/CodeQL alerts.
- The tester role is removed; the reviewer requests missing tests as changes.
- `tools/**/*.py` have no shebang (called with `python3`).
- Open: pinned versions (zizmor, actionlint) and gitleaks-action not yet run in CI; gitleaks-action may need a licence for organisation repos.
