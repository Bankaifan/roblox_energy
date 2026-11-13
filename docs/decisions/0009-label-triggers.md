# 0009 Label triggers for the orchestrator

Status: accepted (issue #32).

When Daniel labels an issue `approved` or `auto-ok`, the orchestrator starts at once instead of waiting for the next merge or the daily run.

- `orchestrator.yml` also runs on `issues: labeled`. The job-level `if` lets through only these two labels. `tools/orchestrator_gate.py` checks again that the labeller is OWNER; the event alone is not trusted.
- Debounce: a label run is skipped when an earlier orchestrator run (lower run id) was created at most 180 seconds before it. A burst of labels gives one run. Trade-off: a label set in that window waits for the next run (merge, daily cron or dispatch).
- `agent-dev.yml` already filters its job with `if`. Label events that are not `agent:dev` still show as skipped runs in the Actions list. This is expected and not a failure, because GitHub cannot filter label names at workflow level.

**Why:** approved work waited up to a day (ha-luxtronik-shi #76 to #78).
**How to apply:** do not drop the owner check in the script when the event filter changes; keep the job-level `if` so that other labels do not start an orchestrator run.
