# 0008 Tiers S/M/L

Status: accepted (issue #29, part 1: metrics and documentation). Source: HPO comparison, section "Ausbaustufen".

Projects grow; the template must scale without starting heavy. A project is in tier S (default), M or L. The tier is a proposal for Daniel, never switched by a script. Implementation of M/L parts happens later via their own issues when a project reaches the tier.

## Metrics

`tools/weekly_summary.py` appends one row per week to `docs/metrics.csv`, and the `weekly-summary` workflow opens a PR for it (branch `agent/metrics-<date>`). Columns: code lines and modules (source files) in total and per language, generated files excluded (lock files, `*.min.*`, `dist/`, `build/`, `vendor/`, `node_modules/`, `generated/`); `max_parallel_agent_prs` (max agent PRs open at once during the week); `avg_review_rounds` (1 + `CHANGES_REQUESTED` reviews, merged agent PRs); `median_ci_minutes` (runs of `validate.yml`); `actions_minutes` (user billing API, empty if the token cannot read it). Unknown values stay empty. Open: `conflicts_rebuilt` (merge conflicts / branches rebuilt) has no cheap data source yet and stays empty.

## Thresholds (estimates, to be calibrated)

Two of the thresholds exceeded four weeks in a row would justify proposing the next tier (`tools/tier.py`: "lines or modules" counts as one threshold, empty values never count; `.agents/tier` holds the current tier; the `rule-keeper` workflow runs `tools/tier.py --propose`, which opens ONE issue "Propose tier M/L" with the numbers and never switches the tier).

| | S to M | M to L |
|---|---|---|
| Code | ~5,000 lines or 30 modules | ~30,000 lines or 150 modules |
| Parallel agent PRs | 3+ | 6+ |
| Conflicts per week | 3+ | 10+ |
| Review rounds (avg) | > 1.5 | > 2 |
| CI duration (median) | > 10 min | > 20 min |

## Tier S (today)

Roles, CI checks, rule keeper, weekly summary, template sync as in 0001 to 0007. No structure budgets.

## Tier M adds

- A small structure ratchet: 4 to 6 numbers per file (e.g. lines, functions, imports) in a checked-in file; they may only go down, a PR that raises one fails.
- Reviewer verdict classes (what blocks, what is advice).
- Cancel superseded runs (`cancel-in-progress` for runs of a PR whose head moved).

## Tier L adds

- An architecture score as a required check.
- A scripted merge train that lands reviewed PRs one by one and stops at the first failure. GitHub's merge queue was decided against (HPO): its rebase creates a new SHA and breaks "review is for exactly this SHA".
- Designer roles and a heartbeat.
