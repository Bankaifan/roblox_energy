# 0020 PARALLEL-MERGE: approved PRs merge without waiting for each other

Decided by the owner on 2026-11-24. Name of the work: `PARALLEL-MERGE`. Supersedes the flag of decision 0010.

## Problem
With `strict_required_status_checks_policy: true` a PR merges only when it is on the newest `main`. Every merge
sends every other approved PR through rebase, CI and approval again, so ten ready PRs land one after another and each
waits for all the ones before it. In a project whose CI takes 14 minutes that is hours for a queue of ten.

## Decision
`.github/rulesets/main.json` sets `strict_required_status_checks_policy: false`. The required checks (`validate`,
`agent-smoke`, `risk`, `security-review`), the approval, the code owner review and the linear history stay as they are.
An approved, green PR merges as soon as GitHub can rebase it, whatever landed in between.

## What is given up, and what catches it
Two PRs that are green alone can break `main` together (the reason for decision 0010). That is no longer caught
before the merge. It is caught after it: `validate` runs on every push to `main`, the failure watch opens a signed
`Failing workflow` issue for a red run, and an agent fixes it. A textual conflict still stops the merge as before.

## How it becomes live
The file does not apply itself. The owner re-imports it (Settings > Rules > Rulesets > `main` > Import) or switches
"Require branches to be up to date before merging" off in the UI, in every repo. Projects get the file by template sync.

## Way back
One line in `main.json` back to `true`, and a re-import. The train (`tools/train.py`), the batch (decision 0018) and
the re-approval (`tools/reapprove.py`) are unchanged and work with either setting.
