# 0015 Role cost and benefit, and the Role proposal

Status: accepted (issue #343, owner comment). Amends 0014 item 4: the lever "a separate seat or token" is dropped. Describes the state on this branch.

Context: 0014 measures model runs per workflow. Daniel asked whether splitting work into more roles pays off, not whether a separate seat helps. All roles share `CLAUDE_CODE_OAUTH_TOKEN`; the quota is one quota.

Decision:
1. The weekly summary (script step, no model) gets a table "Roles, last 7 days", one row per role in `run_stats.ROLES`: model runs, failed runs, review rounds (CHANGES_REQUESTED on agent PRs updated in the last 7 days; the review row), rework (restarts with `restart:1` on open issues updated in the last 7 days, the dev row; fix runs, the fix row).
2. Failure classes: a failed model run (not a limit or rate error, `run_stats.LIMIT_RE`) gets a class from the first error line of its failed-step log, with digits replaced by `#` (`run_stats.failure_class`, a heuristic: same text, same class). Runs are read for 4 weeks.
3. A "Role proposal" issue is opened, or its body updated, only when one class repeats in 3 or more failed model runs within 4 weeks (`ROLE_REPEATS`). It lists the classes and the role table, and says that a script in `tools/` is checked first (AGENTS.md: script first, then haiku, then sonnet). The script does not check `tools/` itself, so this step stays manual.
4. The Capacity proposal (0014) lists the same levers without the seat or token; it adds the role table as evidence.
5. Neither proposal writes a variable, a secret, a role or a workflow. The calls stay limited to `run`, `api`, `issue` and `pr` (`tests/test_quota_advisor.py`).
6. `AGENTS.md` caps text was checked against `tools/prefilter.py` (defaults 2 and 3) and `weekly-summary.yml` / `orchestrator.yml` (agent-template 4 and 5). It matches, so it is unchanged.

Open (not measured; follow-ups, not claims):
- Denied calls, turns and silent runs: the execution file stays on the runner; the summary does not read it.
- Benefit beyond review rounds (failures a reviewer caught that no script could): no source yet.
- Handoffs: handover PRs have no branch or label marker in the repo; only the needs-human count (Queue section) is shown.
- Restarts count open issues only; a closed issue with `restart:1` is not counted.
- Failure classes are text heuristics: different wording of one cause counts as two classes (no false proposal), and unrelated errors with the same first line count as one (possible false proposal).
- Thresholds (`ROLE_REPEATS` = 3 in 4 weeks) are a first guess; change them after the first runs.

Consequences:
- No permission change. The app token already reads actions (0014).
- The Role proposal is one more issue the summary can open; Daniel decides on it. It is not a `needs-human` item and carries no decision marker yet.
