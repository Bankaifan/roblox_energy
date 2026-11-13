# 0004 Secure agent inputs, reliable triggers

Status: proposed (issue #11, Daniel approved the workflow/rule/doc changes; source: an external review). Not verified end to end.

## Decision
- Orchestrator: `claude-code-action` does not support `push`, so it runs on `workflow_run` of `validate` (completed, event push,
  branch main, success). A script step exits early when the merged commit only touches HANDOVER.md (no self-loop).
- Trusted input only: `tools/trusted_issues.py` picks the orchestrator's candidates: issues authored by `Bankaifan`, or with
  `approved` / `auto-ok` whose latest label event was made by `Bankaifan`. The list is passed into the prompt. A valid `auto-ok`
  also makes an issue a candidate (otherwise it would have no effect). The scout adds only `idea`.
- `allowed_bots: '*'` is gone. Repo variables `AUTHOR_BOT` / `APPROVER_BOT` are required (`setup.yml` checks them);
  `agent-fix` also requires `review.user.login == vars.APPROVER_BOT`.
- Reviewer never runs PR code: checkout of the default branch, change read through `gh pr diff` / `gh pr view`, `--max-turns 12`.
  Every `claude-code-action` call gets `--setting-sources user`. `.claude/` and `.mcp.json` are code-owned.
- Guaranteed CI: after the Claude step, agent-dev and agent-fix run an inline script step (inline so the agent cannot edit it):
  wait up to 60 s for a `validate` run on the PR head SHA, else `gh workflow run validate.yml --ref <branch>` and label
  `agent:review`. `validate.yml` has `workflow_dispatch`; `check_pr_form.py` then reads title/body with `gh pr view`.
- Review on green CI only (`workflow_run` of `validate`, success, same-repo `agent/*`, PR found by head SHA, one review per SHA).
  A red `validate` on an `agent/*` branch starts agent-fix with the run id (`gh run view --log-failed`) and counts as a round.
- Rounds: the counter label is bumped by the reviewer (before reviewing) or by a red CI. `review:1`/`review:2` -> fix,
  `review:3` -> `needs-human`. That gives 2 fix rounds and up to 3 reviews.
- All writing workflows set `bot_id: "476059"`, `bot_name: "Bankaifan"`.

## Consequences
- The author app needs Actions (read run logs, dispatch) and Workflows (push workflow files) write permission. Open: not tested.
- "validate check run" is approximated by "a validate workflow run exists for the SHA" (`gh run list --commit`, Actions: read).
- Open: whether `workflow_run` events of runs created by the author app behave as expected; whether `bot_id` makes the
  action's own commits carry the Bankaifan noreply email (the developer commits with `git config` anyway).
