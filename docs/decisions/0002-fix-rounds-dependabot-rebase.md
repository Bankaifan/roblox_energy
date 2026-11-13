# 0002 Fix rounds, dependabot without AI, rebase merge, code owners

Status: proposed (issue #7, Daniel approved the workflow/rule/ruleset changes). Not yet verified end to end.

## Decision
- `agent-fix.yml`: an approver `CHANGES_REQUESTED` review on an `agent/*` PR starts the developer on that branch
  (no new PR). Cap stays 2: label `review:1` -> fix; `review:2` -> `needs-human`, no dev run.
- Dependabot PRs get no AI review. `dependabot-automerge.yml` (no model) runs on `workflow_run` of `validate`
  (not `pull_request_target`; it checks out only the default branch, never PR code). Patch/minor: approver
  approves, author enables auto-merge `--rebase`. Major, 0.x minor or unparseable titles: `needs-human`.
- Daniel is the sole author on `main`: rebase merge instead of squash. The developer squashes its branch into one
  commit authored by Daniel before review; the ruleset allows only `rebase` and keeps linear history.
- `.github/CODEOWNERS`: `@Bankaifan` owns `AGENTS.md`, `CLAUDE.md`, `.agents/`, `.github/`, `tools/check/`;
  ruleset has `require_code_owner_review: true`. Other paths merge without Daniel.
- `setup.yml` (manual): creates the labels and lists missing secrets (names only).

## Consequences
- The 5 secrets must be set per repo, and the ruleset must be re-imported after this change.
- Dependabot `github-actions` PRs touch `.github/`, so they also need Daniel as code owner; the auto-approval
  alone does not merge them.
- Open: whether `workflow_run` of a dependabot-triggered run sees the Actions secrets. If not, add the four app
  secrets as Dependabot secrets as well.
