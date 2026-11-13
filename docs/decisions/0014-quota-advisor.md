# 0014 Quota advisor in the weekly summary

Status: accepted (issue #343, design 0007 section 4.7 baseline). Describes the state on this branch.

Context: nobody measured how much model capacity the agents use or what throttles them. `run_stats.py` counted only orchestrator runs. `weekly-summary` had no model usage. Daniel cannot tell whether more caps, more seats or a separate seat for some roles would help.

Decision:
1. The weekly summary (script step, no model) gets a section "Model runs, last 7 days": per workflow with a `claude-code-action` step, the model runs, runs per day, median duration, failed runs and failed runs whose failed-step log matches a limit or rate pattern (`run_stats.LIMIT_RE`, a heuristic). The role per workflow comes from `run_stats.ROLES`.
2. A "Queue" section: approved issues waiting for a slot, free `agent:dev` and agent PR slots (an approximation of `tools/prefilter.py`), and the median days since the last update of `needs-human` items.
3. The caps for the queue section come from `MAX_DEV` and `MAX_PRS` in `weekly-summary.yml`, with the same defaults as `orchestrator.yml` (4 and 5). `AGENTS.md` already documents these values and is unchanged.
4. One issue "Capacity proposal" is opened, or its body updated, only when a threshold is hit: at least one failed model run with a limit or rate error in the last 7 days, or at least 3 approved issues waiting while no `agent:dev` slot is free. The proposal lists the levers (`IDEAS_PER_WEEK`, `ORCHESTRATOR_EVENTS`, `MAX_DEV`/`MAX_PRS`, model per role, a separate seat or token) and leaves the choice to Daniel.
5. The script never writes a repo variable or a secret. `tests/test_quota_advisor.py` checks that the calls it makes are limited to `run`, `api`, `issue` and `pr`.

Open (not measured; each is a follow-up, not a claim):
- Turns and denied calls per run: the execution file stays on the runner (`EXEC_FILE` in the workflows); the summary does not read it.
- Limit errors: the pattern runs over the failed-step log; a test name or log line that contains "rate limit" counts too.
- Queue ages use the last update time, not the time the label was set.
- The first weekly run has not been observed yet; the numbers in the first summary are the first measurement.
- The proposal issue has no decision marker (`tools/decision.py`) yet.

Consequences:
- The summary step reads the repo's workflow runs and failed logs with the app token; it still writes only the summary, the metrics row and the proposal issue.
- Permission change: the app token in `weekly-summary.yml` gets `permission-actions: read` (new for this workflow; it was contents, pull-requests and issues only). Without it the run and log calls fail and the model section shows "unknown".
- Thresholds (1 limit error, 3 waiting) are a first guess; change them in `tools/weekly_summary.py` after the first runs.
- Changes to `weekly-summary.yml` are `risk:security` and need the security reviewer.
