# 0003 Merge train

Issue: #124 (design study, no implementation in this PR).

## 1. Goal

Parallel agent PRs land one after another without Daniel untangling them. Two PRs that are green alone can still break `main`
together, and a textual conflict only shows up when auto-merge fails. GitHub's merge queue is not available for a personal-account
repo, so the train is built from what exists: strict status checks, a model-free rebase step, the existing conflict fix round and
a cheap re-approval after a rebase that did not change the PR's own diff.

## 2. Current state

- Ruleset `.github/rulesets/main.json`: `strict_required_status_checks_policy: false` (line 29), so a PR merges while behind `main`;
  `dismiss_stale_reviews_on_push: true`, `require_last_push_approval: true`, `require_code_owner_review: true`, rebase merge only,
  checks `validate`, `agent-smoke`, `risk`, `security-review`.
- Disjoint files: `orchestrator.yml:146` tells the orchestrator that slips must touch disjoint files. Nothing checks it against the files
  of open agent PRs.
- Rebase today: `tools/status.py` `rebase_candidates()` (only an own one-commit PR whose last validate failed while `main` was red), run
  through `PUT pulls/N/update-branch` with `update_method=rebase` in `run_status()`. It never merges.
- Conflict today: `status.py` `conflict_prs()` and `handle_conflict()` take the first agent PR with `mergeStateStatus == DIRTY` (any
  such PR, auto-merge or not), set `review:N` and dispatch `agent-fix.yml`; after round 2 it escalates. It runs on the status tick
  (30 min public, 60 min private), not at once.
- Review: `agent-review.yml` runs on `workflow_run` of `validate` (the workflow file comes from the default branch, checkout is `main`,
  token of the approver app). It skips when `agent_guard.py reviewed PR SHA BODYHASH` finds an approver review for that SHA
  (`agent_guard.has_review`, line 92). Auto-merge: `automerge.yml` enables `gh pr merge --auto --rebase` after an approval.
- CODEOWNERS (`/.github/rulesets/`, `agent_guard.py`, `exec_log.py`, `risk.py`, `risk.yml`, `AGENTS.md`) and `risk:security` PRs need
  Daniel regardless of reviews.
- No `CHANGELOG.md` in this repo, so no file is known as a hot spot. Conflict rate between agent PRs is not measured (open).

## 3. Options with trade-offs

Order:
- A. Keep `strict: false`, rebase only on conflict. Cheap, but semantic breaks reach `main` unchecked. Rejected (the issue's point 2).
- B. `strict: true` and a train that rebases the ready PR. Chosen.
- C. A bot that merges PRs itself in a queue branch. Needs a second integration branch and write access to `main`: rejected (limits 3, 5).

Train trigger:
- D. Extend the status tick. At most 30 to 60 min between two merges. Too slow as the main path, fine as a fallback.
- E. A workflow on `push` to `main` plus a `schedule` fallback. Starts seconds after a merge. Chosen.

Re-approval after a rebase:
- F. Full model review again. Safe, expensive: every queued PR is reviewed once per merge ahead of it.
- G. A script approval when the PR's own patch is identical. Chosen. The compared object is the patch of the single commit
  (`git patch-id --verbatim` on the commit patch from the API), not the merge result: the merge result is what `validate` tests.
- H. `git range-diff`. Needs the old commits fetched into a checkout; patch-id over API text needs no checkout of PR objects.

## 4. Chosen approach

B + E + G.

### 4.1 Prevention (point 1)

`tools/overlap.py` (no model): given the slip's "Files touched" line and the file lists of open agent PRs (`gh pr view --json files`),
print the overlapping paths. The orchestrator prompt calls it before adding `agent:dev` and defers a slip that overlaps (it stays
`approved`, retried next run). Lines in `orchestrator.yml` and `.agents/roles/orchestrator.md` only. Paths from a slip are untrusted text:
the script compares strings and never opens them.

### 4.2 Strict order (point 2)

`strict_required_status_checks_policy: true`. Effect: a PR whose base is not the tip of `main` cannot merge until updated. Auto-merge then
waits (`mergeStateStatus == BEHIND`). Nothing updates the branch by itself, hence 4.3. The flip is the only Owner decision and goes last.

### 4.3 Train step (point 3): `tools/train.py`, workflow `train.yml`

Trigger: `push` to `main`, `schedule` every 30 min (fallback), `workflow_dispatch`. `contents: read`, concurrency group `train`
(no cancel). Author app token (not `GITHUB_TOKEN`: its pushes do not start `validate`). Checkout is `main` only, `persist-credentials: false`;
the script runs from `main` and reads PR data through `gh` as data. Repo variable `TRAIN=off` disables it.

Steps of `train.py` (pure functions plus a thin `gh` layer, fake `run` in tests, like `status.py`):
1. List open same-repo agent PRs (`status.is_agent_pr`), excluding `needs-human`, design PRs and PRs without an approving review of
   the approver app on their current head (`agent_guard.has_review`). Order by PR number (oldest first).
2. One in flight: if any listed PR already has `mergeStateStatus` `CLEAN`, `UNSTABLE`, `HAS_HOOKS` or is `BLOCKED` with checks pending on
   a head that is based on the tip of `main`, do nothing. That PR merges, the `push` event runs the train again.
3. Take the oldest `BEHIND` PR with auto-merge enabled and call `PUT pulls/N/update-branch` with `update_method=rebase`. Then `validate`,
   `agent-smoke`, `risk`, `security-review` run on the new head (open: confirm the checks other than `validate` start for an app-token push).
4. Take the oldest `DIRTY` PR, whether or not auto-merge is enabled (`status.conflict_prs` has the same scope), and call
   `status.handle_conflict` at once instead of waiting for the tick. A PR without an approval yet is not probed: it is rebased by its own
   author or by the next `agent-fix`.
5. Print numbers and actions, never tokens. A failed `gh` call is reported and ends the run without a label change (the schedule retries).

`status.py` keeps its red-main rebase and its conflict handling as a safety net; the two share `handle_conflict`, so a PR gets at most one
fix round per conflict (label `review:N` is the counter).

### 4.4 Cheap re-approval (point 4): `tools/reapprove.py` inside `agent-review.yml`

The step goes into the existing `agent-review.yml`, before the model step and after the round step, so it runs in the same job and the
same concurrency group: no race with the review, no second workflow. The file comes from the default branch (`workflow_run`), the
checkout is `main`, the token is the approver token the job already has. A PR can change neither the script nor the workflow that
judges it. `reapprove.yml` on `pull_request` is not used: that event would run the PR's own copy.

`reapprove.py PR SHA`: approve the new head without the model only if all hold, else exit 1 and the model review runs as today:
1. The PR is an agent PR, open, one commit, no `needs-human`, not `risk:security`, not a design PR, and touches no CODEOWNERS path
   (those wait for Daniel anyway; the `risk` check also fails again on a new head until he approves it).
2. An earlier approver review exists for a head `OLD` whose state at submission was `APPROVED`, and whose body `body-hash` equals the
   current one (`agent_guard.body_hash`). A body edit forces a full review. `dismiss_stale_reviews_on_push` turns that review into
   `DISMISSED` on the rebase, so the prior state is read back from the PR timeline (`review_dismissed` event, `previous_review_state`;
   open: confirm the field in the scratch repo, section 6). The `body-hash` alone does not decide: a `CHANGES_REQUESTED` review carries
   the same line. A dismissed `CHANGES_REQUESTED` review does not count, and a review whose prior state cannot be read does not count
   either (fail closed: the model reviews).
3. `patch-id(OLD) == patch-id(SHA)`, both from `gh api repos/R/commits/<sha> -H 'Accept: application/vnd.github.patch'`, fed to
   `git patch-id --verbatim`. The API text is data; nothing is checked out. Commit message and metadata are not part of the patch: the
   body-hash check in 2 covers the PR text, the subject line is covered by `check_pr_form`.
4. `validate` for `SHA` is green (the job only starts on `workflow_run` success).

Then `gh pr review --approve` with the body `Re-approved without model: patch unchanged since OLD (patch-id P).` plus the `body-hash:` line.
That review is the marker: `agent_guard.reviewed` finds it for `SHA`, so the model step is skipped (no new marker). The script review never
chains past a changed patch: the next comparison uses the newest approver review's head, whose patch equals the first model-reviewed one.
Not covered, on purpose: a patch-id compares hunks and ignores context lines; whether the new context breaks the code is what `validate`
on the rebased head measures (strict mode makes that the rule).

## 5. Migration and compatibility

- Order matters: train and re-approval go live first, `strict` last. With strict on and no train, approved PRs would sit `BEHIND`.
- Open PRs at the flip are rebased one by one by the train; their old approvals are dismissed and re-created by 4.4 or the model.
- `setup.yml` is not touched. Projects from the template get the files by template sync (design 0001); `main.json` is a managed
  path, so a project adopts `strict: true` by syncing it (Daniel's decision per repo).
- Fork PRs and dependabot are out of scope: `is_agent_pr` is same-repo `agent/*` only; dependabot keeps `dependabot-automerge.yml`.

## 6. Test and verification plan

All fail on today's code (no module, step or flag):
- `tests/test_overlap.py`: an overlapping path is reported, disjoint is not, a directory prefix overlaps its files, an empty slip is empty.
- `tests/test_train.py`: oldest approved `BEHIND` PR is rebased; a second one waits while one is in flight; a PR without approval, with
  `needs-human`, cross-repo or non-agent is skipped; `DIRTY` calls `handle_conflict` once and a `review:3` PR escalates; a failed
  `gh` call is reported, no label change.
- `tests/test_reapprove.py`: same patch and same body-hash approves; changed patch, edited body, two commits, `risk:security`,
  `needs-human`, CODEOWNERS path, no earlier approval each refuse; a dismissed earlier review counts only with prior state `APPROVED`;
  "earlier review was changes-requested, then dismissed -> refuse"; an unreadable prior state refuses; a script review chains from the
  newest head. The patch text for the fake `run` is a fixture.
- `tests/test_agent_review_workflow.py`: the reapprove step sits before the model step, the checkout `ref` is the default branch, the trigger
  is `workflow_run`, and no step uses `pull_request`/`pull_request_target` for approval.
- `tests/test_train_workflow.py`: triggers are `push` to `main`, `schedule`, `workflow_dispatch` only; `permissions: contents: read`;
  `persist-credentials: false`; no PR ref is checked out.
- `tests/test_ruleset.py`: `strict` is true only after PR 5 (this test is the proof that the flip happened).
- `make check` (actionlint, zizmor) on both workflows.
- Before the flip, in a scratch repo with the same ruleset: two PRs on disjoint files with auto-merge (expect the second to go `BEHIND`, be
  rebased by the train, re-approved by script, merged); a changed-patch case (expect a model review). Also measure whether `update-branch`
  dismisses the approval and whether all four checks start. Not run yet (open).

## 7. Rollback

Set `TRAIN=off` or disable `train.yml`; the reapprove step falls back to the model review by exiting 1. Flip `strict` back to `false` in
`main.json` (Daniel, ruleset change). Each implementation PR is one rebase-merged commit, so `git revert` undoes it. Script approvals already
given stay valid: they were approvals of a patch a model had reviewed.

## 8. Split into PR-sized implementation issues

Each issue carries `Design: docs/design/0003-merge-train.md` and stays under about 400 changed lines. Files are disjoint.
1. **Overlap guard** (any time, `risk:security`: prompt of a workflow): `tools/overlap.py`, `tests/test_overlap.py`,
   `.agents/roles/orchestrator.md`, `.github/workflows/orchestrator.yml`.
2. **Train core** (no workflow, normal risk): `tools/train.py`, `tests/test_train.py`.
3. **Train workflow** (needs 2, `risk:security`: token and triggers): `.github/workflows/train.yml`, `tests/test_train_workflow.py`.
4. **Re-approval** (independent of 2 and 3, `risk:security`: approval logic and approver token): `tools/reapprove.py`,
   `tests/test_reapprove.py`, `tests/test_agent_review_workflow.py`, `.github/workflows/agent-review.yml`.
5. **Strict flip** (last, needs 2, 3, 4 live, `risk:security`, Daniel): `.github/rulesets/main.json`, `tests/test_ruleset.py`,
   `docs/decisions/0010-merge-train.md`.

1, 2 and 4 touch disjoint files and can run in parallel (max 2 jobs at once: 2 and 4 first). Open: how the ruleset file reaches the live
ruleset (by hand or by `rule-keeper.yml`); PR 5 states it.

## 9. Owner decisions

One: switch the `main` ruleset to `strict_required_status_checks_policy: true` (PR 5). Effect: a PR can merge only when it is tested on
the current `main`; without the train, approved PRs would wait. Worst case: a bug in the train or in the re-approval stops all merges until
the flag is set back (a one-line revert; Daniel can also merge by his admin bypass). Reviewers' recommendation: yes, after PRs 2 to 4 ran
without the flag for a while.

## 10. Open (settled in the implementation issues)

- Conflict rate between agent PRs is not measured; PR 1 may show whether the guard alone avoids most of them.
- Whether `update-branch` by the app token starts all required checks and dismisses the approval (measured in the scratch repo, section 6).
- Whether the timeline returns `previous_review_state` for a dismissed review (scratch repo, section 6). Until confirmed, 4.4 refuses.
- Whether `git patch-id --verbatim` treats file-mode-only changes as a change (measured in `test_reapprove.py` before PR 4 merges).
- Cost saving is not measured: the number of model reviews per queued PR before and after is counted after PR 4 from `agent-review` runs.
