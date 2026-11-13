# 0006 Review requests, design study, dependabot metadata

Status: accepted (Daniel approved workflow, tool and rule changes in issue #18).

- Every workflow that adds `needs-human` to a PR (round limit in `agent-fix`/`agent-review`, dependabot major) also runs `gh pr edit --add-reviewer Bankaifan`, skipped when he is the author. A label alone never shows up under "Needs your review".
- Design study before big work: the orchestrator assigns a design task, the developer writes `docs/design/NNNN-<slug>.md` (template in `docs/design/README.md`), a design reviewer (`.agents/roles/design-reviewer.md`, chosen by `agent-review` when only `docs/design/` changed) approves. Only the section *Owner decisions* goes to Daniel (`needs-human` + review request + German summary); empty means the design merges without him.
- After the merge the orchestrator creates the implementation issues. `tools/trusted_issues.py` trusts them when the author is `AUTHOR_BOT`, the body has a line `Design: docs/design/NNNN-<slug>.md` and that file exists on `main`; `idea` issues never qualify.
- Dependabot: `dependabot/fetch-metadata` (pinned SHA) supplies `updated-dependencies-json`; the highest update type wins, so grouped PRs work. Range titles ("Update x requirement from A to B") are parsed as a fallback. Unknown is major.
- Open: whether `fetch-metadata` reads the PR from a `workflow_run` event is not verified; on failure the step is skipped and the title decides. `agent-review.yml` is touched too, because it adds `needs-human` at the round limit.
