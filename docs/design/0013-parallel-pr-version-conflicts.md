# 0013 Parallel agent PRs without conflicts on VERSION and CHANGELOG

Issue: #406 (design study, no implementation in this PR).

## 1. Goal

Parallel agent PRs must not need a hand rebase or the unblocker only because two of them wrote the same `VERSION` line or the same
`CHANGELOG.md` section. Decide whether that is worth a change, and which one.

## 2. Current state

- `tools/check/check_version_bump.py`: a PR that changes a path in `.agents/managed.json` must change `VERSION`; `VERSION` must be
  `x.y` and not lower than on the base (`errors()`, lines 26-39). It does not require `base + 1`, so two PRs may both write `1.5`.
- `tools/check/check_version.py`: `VERSION` must have a `## [x.y]` heading in `CHANGELOG.md`, plus a `## [Unreleased]` heading.
- Every PR adds a line under `## [Unreleased]` (developer role) and the bump moves that block under a new `## [x.y]` heading. Two open
  PRs therefore edit the same lines of `CHANGELOG.md` and the same line of `VERSION`.
- Conflicts today: `tools/train.py` sends the oldest DIRTY PR to `status.handle_conflict()` (agent-fix round, then escalation).
  `mergeStateStatus == BEHIND` is rebased by `update-branch`; that rebase fails when the same lines changed.
- Template sync reads only the **x** of `VERSION`: `tools/template_sync.py` `read_version()` accepts `x.y`, `needs_sync()` compares
  the template `x` with the recorded `synced_version` `x` (ADR 0007). `y` is never read for the gate. `sync_lines()` reads `Sync:`
  lines from the template `CHANGELOG.md` as data. `check_version_bump.py` and `template_sync.py` share `is_managed()`.
- GitHub does not run custom git merge drivers, so a driver (for example `merge=union` on `CHANGELOG.md`) does not help on GitHub.

### Measurement

Window: 2026-10-12 to 2026-11-11 (30 days), repo `Bankaifan/agent-template`.

| Number | Value | Source |
|---|---|---|
| Commits on `main` | about 270 | `git log --since=2026-10-12 --no-merges` |
| Commits that changed `VERSION` | 5 (1.0 to 1.4, all on 2026-11-11, strictly sequential) | `git log -- VERSION` |
| Commits that changed `CHANGELOG.md` | 6 | `git log -- CHANGELOG.md` |
| Agent PRs that were DIRTY or rebased only because of `VERSION` or `CHANGELOG.md` | **open** | needs `gh pr list`, denied to the developer run (commented on #406 and on this PR) |
| Git-only proxy (rebase or update-branch commits of merged PRs) | **not available** | merged PR branches are deleted; `main` keeps only the rebased commits, so PR-side rebases cannot be counted from git |
| Remote agent branches still present (the PR branches of merged PRs are deleted) | 2 (`agent/406-...`, `agent/407-...`) | `git branch -r --list origin/agent/*` |
| Live sample: PR #411 touches `VERSION`, `CHANGELOG.md` and 16 other files; it is now closed with `mergeStateStatus` DIRTY | 1 PR | `gh pr view 411 --json mergeStateStatus,files,state` |

What the numbers say: `VERSION` exists only since 2026-11-11, so the exposure is 5 bumps in one day, and no bump was skipped or
duplicated on `main`. The `main` history cannot show the cost, because the PRs that were rebased before merging leave no trace on
`main`. The DIRTY count is therefore not measured and is not claimed to be zero. The one live sample (#411) shows the shape of the
problem, not its rate: a managed PR edits the same two files that every other managed PR edits.

Mechanism (from the owner's analysis on #406; not yet measured): with strict status checks and the merge train, every merge of a
managed PR changes `VERSION` and the `[Unreleased]` block of `CHANGELOG.md` on `main`. Every other open managed PR then has a stale
`VERSION` line and a stale hunk in the same place, so it turns DIRTY or BEHIND until its agent-fix round or `update-branch` runs.
The cost therefore scales with merges times open managed PRs, not with the number of bumps on `main`. The 5 sequential bumps
understate the exposure for this reason.

## 3. Options with trade-offs

- **A. Changelog fragments plus a release step.** Each PR adds `changelog.d/<issue>.md`; one release step folds fragments into
  `CHANGELOG.md` and assigns `VERSION`. Removes the conflict completely.
  Cost: a new workflow that writes to `main` (limits 3 and 5: needs the security reviewer and a CODEOWNERS decision), changes to
  `check_version_bump.py` (a managed change no longer edits `VERSION`; it needs a fragment instead), `check_version.py` (heading
  per version), the developer role and the template-sync gate. About 4 PRs.
  Risk: the template `VERSION` then moves after the merge, so there is a window where `main` has managed changes under the old
  version and the gate (`needs_sync`, x only) does not see them; a `sync:must` change must still be an `x` bump decided at
  merge time, not by the author. High.
- **B. Hand bumps stay; the merge train re-bumps.** When the only conflicting files of a DIRTY PR are `VERSION` and `CHANGELOG.md`,
  `tools/train.py` rebases onto `main`, re-applies the PR's bump step on top of the version that `main` has now, moves the PR's
  changelog line under the new heading, force-pushes the PR branch and lets CI run again.
  Rule (`M` = `main`'s `VERSION` as `m.n`, `P` = the PR's step, applied to `M`):
  - `P` = `y` gives `m.(n+1)`. Example: `main` 1.5, PR step `y` gives 1.6. If `main` took an `x` bump first (for example `sync:must`,
    `main` 2.0), the PR's `y` is added on top of it: 2.0 gives 2.1.
  - `P` = `x` gives `(m+1).0`. Example: `main` 1.5, PR step `x` gives 2.0. If `main` took a `y` bump first, the `x` step still wins
    and resets `y`.
  The re-bump never drops the PR's step: an `x` step always raises `x`, so the template-sync gate (section 2) sees the change it was
  written for. Cases (a), (b) and (c) in section 6 cover this rule.
  Cost: one script (about 150 lines with tests) and one change in `train.py`. Risk: medium. It rewrites an agent branch, so the
  approval is dismissed (`dismiss_stale_reviews_on_push`) and the review reruns; a wrong re-bump is caught by `check_version_bump.py`
  and `check_version.py` in CI. No change to `check_version_bump.py` or the sync gate.
- **C. Leave as is.** Cost none. Risk: each conflict costs one agent-fix round (one model run) plus a CI and review rerun, and the
  unblocker and `handle_conflict()` already handle it. It scales with merges times open managed PRs (section 2), so it grows with
  MAX_PRS (5 now; #411 raises the number of agents working in parallel).

## 4. Chosen approach

**B.** Chosen on the mechanism in section 2, not on a measured count.

- Why not C: each merge of a managed PR makes every other open managed PR DIRTY or BEHIND. Each such PR costs one agent-fix run
  (`tools/train.py` -> `status.handle_conflict()`) plus a CI and review rerun. The cost grows with merges times open managed PRs, and
  parallel work (MAX_PRS, #411) raises the number of open managed PRs. C leaves that cost in place.
- Why not A: it changes `check_version_bump.py`, `check_version.py` and the template-sync gate (`needs_sync()` reads only `x`), and
  it moves the `x` decision to merge time. High risk for the same conflict B removes.
- Why B: it removes the model run for conflicts that touch only `VERSION` and `CHANGELOG.md`, and it leaves the version check and the
  sync gate unchanged (section 3).

Open, and not a gate for this choice: the DIRTY count and the agent-fix round cost. Both are open because `gh pr list` and
`gh run list` were denied to the developer run (commented on #406 and on this PR). They feed only the check after B ships
(section 6). Cost of B: one script (about 150 lines with tests) and one `train.py` change, paid once.

## 5. Migration and compatibility

Downstream projects that sync the template see no change under B: `VERSION` stays `x.y`, the gate reads only `x`, and `Sync:` lines
stay in `CHANGELOG.md`. The re-bump only changes which `y` a PR lands with. A would change what downstream projects receive: new
`changelog.d/` path and a release workflow in `managed.json`, a one-time sync, and a rule that the template `x` is set by the release
step. Under C nothing changes.

## 6. Test and verification plan

- Before B ships (must be able to fail on today's code): a unit test of the re-bump on a conflict fixture (two branches bump `1.5`
  and change the same `[Unreleased]` line) that fails on today's `train.py`, which sends it to agent-fix. Cases:
  (a) `main` 1.5, PR step `y`: result 1.6;
  (b) `main` 2.0 (took `x`, `sync:must`), PR step `y`: result 2.1;
  (c) `main` 1.5, PR step `x`: result 2.0.
  Each case must fail on today's `train.py`.
- After B ships (a check, not a gate): over the next 30 days, count agent PRs that got an agent-fix round or a manual rebase where the
  only conflicting files were `VERSION` and `CHANGELOG.md`. Rule: a count above 0 means B does not cover a case; it opens one
  follow-up issue against `tools/rebump.py` (section 8). Count method: `gh pr list --state all --json number,mergeStateStatus,files`
  and `gh run list` for the agent-fix runs. Both are denied to the developer run today, so the count is **open** until they are
  allowed.
- Measurement the developer run can do now: `gh pr view <n> --json mergeStateStatus,files` per open PR (allowed).

## 7. Rollback

B: remove the `train.py` call; PRs fall back to `handle_conflict()`. C: nothing to roll back.

## 8. Split into PR-sized implementation issues

Under B. Step 2 needs the function of step 1, so they cannot run in parallel. The check in section 6 follows after both.

| Step | Title | Files | Depends on |
|---|---|---|---|
| 1 | Add `tools/rebump.py`: re-bump `VERSION` and move the changelog line, cases (a) to (c) | `tools/rebump.py`, `tests/test_rebump.py` | - |
| 2 | Call `rebump` from `tools/train.py` for DIRTY PRs whose conflict set is only `VERSION` and `CHANGELOG.md` | `tools/train.py`, `tests/test_train.py` | 1 |

## 9. Owner decisions

none
