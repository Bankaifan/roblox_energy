# 0003 Autonomous orchestrator, scout and weekly summary

Status: proposed (issue #8, Daniel approved the workflow/rule changes). Not yet verified end to end.

## Decision
- `orchestrator.yml` (sonnet): push to `main` (except HANDOVER.md-only pushes, no loop), daily schedule, manual
  dispatch. Skipped unless repo variable `ORCHESTRATOR_ENABLED` is `true`. It writes task slips, adds `agent:dev`
  (max 2 open; `model:sonnet` only for core/security), handles `needs-human` PRs (rewrite the slip once, then ask
  Daniel), and opens a small PR that overwrites HANDOVER.md.
- `scout.yml` (haiku, sonnet via dispatch input): monthly (amended by 0005), at most `IDEAS_PER_WEEK` (default 3, 0 = off) issues
  labelled `idea`. Small low-risk ideas also get `auto-ok` and may be started by the orchestrator; all others wait
  for Daniel's `approved` label.
- Weekly summary: the orchestrator opens or updates one issue "Weekly summary" on schedule/dispatch runs.
- `setup.yml` creates the labels `idea`, `auto-ok`, `approved`.

## Consequences
- Quota: `ORCHESTRATOR_ENABLED` and `IDEAS_PER_WEEK` control the load. The orchestrator is off by default.
- Open: not verified end to end; the 2-job cap still relies on the orchestrator's own count.
