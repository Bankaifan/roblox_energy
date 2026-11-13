# 0001 Agent setup

Status: accepted (Daniel, 2026-11-09). Not yet verified end to end.

## Decision
- Payment: Claude subscription only (`CLAUDE_CODE_OAUTH_TOKEN`), no API key, no budget console.
- Agents run in GitHub Actions with `anthropics/claude-code-action@v1`; runner via variable `RUNNER`.
- Quota is scarce: max 2 agent jobs at once. Enforced by the orchestrator (at most 2 open `agent:dev` issues),
  not by `concurrency`: a shared group would silently drop queued runs.
- Models per role via `--model`: developer routine haiku, core sonnet, reviewer sonnet, orchestrator sonnet.
- Two GitHub Apps (author pushes and opens PRs, approver reviews); auto-merge with the author token.
- Ruleset on `main`: PR, 1 approval, check `validate`, linear history, rebase merge only, no force push or deletion.
- Commits authored as Daniel, no `Co-authored-by` trailer.
- Rules a script can check go into `tools/check/`, not into prompts. The weekly rule keeper proposes rule changes and new checks in one PR; `branch-cleanup` deletes stale `agent/*` branches daily.

Amended by [0002](0002-fix-rounds-dependabot-rebase.md): rebase merge instead of squash, code owners, automatic fix rounds.

## Consequences
- Review rounds are capped at 2 by labels; a third trigger ends in `needs-human`.
- `concurrency` is per issue/PR only, so nothing queued gets dropped; the 2-job cap depends on the orchestrator.
- Open: app permissions and the approver counting as a required reviewer need a first real run.
