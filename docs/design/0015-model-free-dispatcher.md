# 0015 Model-free dispatcher: start ready issues by script

Issue: #415 (design study, no implementation in this PR).

## 1. Goal

Everything in the orchestrator that is a table lookup runs as a script within seconds of the event, not as a sonnet run:
start an issue that already has a slip, remove `agent:dev` after a merge, start the next ready issues. The model only
writes slips for issues that have none, and HANDOVER.md at most once a day. Trust rules stay as they are.

## 2. Current state

- `.github/workflows/orchestrator.yml`: one job, `concurrency: orchestrator` (`cancel-in-progress: false`), model step
  `claude` (sonnet, `--max-turns 40`) that runs when `tools/prefilter.py` prints `work=true`. The same step starts issues
  (slip comment, `tools/overlap.py`, labels `model:sonnet` then `agent:dev`), removes `agent:dev` after a merge
  (`Refs #N`), creates design split issues and rewrites HANDOVER.md. GitHub keeps one pending run per group, so a burst
  of events costs a wait and replaces pending runs.
- `tools/prefilter.py`: `free_slots()`, `stuck_slots()`, `startable()`, `start_candidates()` compute the `start` list
  (trusted, no `agent:dev`/`needs-human`, not blocked by `deps.py`, within `min(free_dev, free_prs)`). `event_reason()`
  maps an event to `work`: `startable-issue` and `merged-pr` both start the model although the start is a lookup.
  `orchestrator_work()` is true for any candidate, any `needs-human` PR or a stale HANDOVER.md.
- `tools/trusted_issues.py`: the only source of candidates (owner issues, `approved`/`auto-ok` set by the owner, design,
  template sync and signed guard issues). `GUARD_KEY` is read by script steps only.
- `tools/overlap.py`: `parse_files()` reads `Files:` lines of a body or of trusted comments; `collect()` counts only
  slips and PRs by `DEFAULT_TRUSTED` authors; exit 1 = overlap, 2 = unreadable (defer).
- `tools/deps.py`: `Depends on: #N` holds an issue back. `.github/workflows/agent-dev.yml` starts on the `agent:dev` label;
  the model label must be set first (`orchestrator.yml` prompt).
- `tools/run_stats.py`: model runs per workflow (`stats()`, `workflow_stats()`), a gate-skipped run is not a model run.
- Cost seen by the owner on #415 (ha-luxtronik-shi, 2026-11-11): a start run took about 13 min, an `approved` label waited
  26 min for its slip (label 18:10, `agent:dev` 18:36 UTC). Not re-measured here: **open**, `gh run list` is not allowed to
  the developer run (see section 6 for the baseline command).

## 3. Options with trade-offs

- **A. New workflow `dispatch.yml` with a script `tools/dispatch.py`.** Own concurrency group, no model, runs in seconds.
  `orchestrator.yml` keeps the model work. Cost: a new workflow (security reviewer, CODEOWNERS paths) and one more
  writer of labels, so the model must stop labelling. Risk: medium, mitigated by a repo variable switch (section 5).
- **B. Script as first step of `orchestrator.yml`.** One file less, but the job still waits in `concurrency: orchestrator`
  behind a model run (up to 30 min), which is the delay we want to remove. Rejected on that ground.
- **C. Leave as is, only tune the prompt.** No code. The wait is structural (one group, one pending run), so it stays.

## 4. Chosen approach

**A.** Pieces, each reusing existing code:

1. `tools/slip.py` (new): `has_slip(issue, comments, authors)` is true when a `Files:` line (`overlap.parse_files`) stands
   in the body of an issue authored by the owner or the author app (design, template sync, guard, owner issues), or in a
   comment by one of them. A body written by a stranger never counts, even when the owner labelled the issue `approved`: such
   an issue has no slip and goes to the model. `model_of(slip_text)`: `Model: sonnet` or `Model: haiku` line, else the
   existing `model:sonnet` label, else none (haiku default). `opus` is never set by script (needs Daniel's OK).
2. `tools/prefilter.py`: extract the slot and start-list computation of `main()` into `start_state()`, used by both
   prefilter and dispatch (one definition of free slots). New outputs `needs_slip` (start candidates without a slip) and
   `handover_due` (stale and no `agent/orchestrator-handover-<today>` PR, open or merged). `orchestrator_work()` becomes
   `needs_slip > 0 or needs-human decision or handover_due`; `event_reason()` rows `startable-issue` and `merged-pr`
   (non-design) no longer start the model on their own. A merged design PR still does (split issues, step 1b).
3. `tools/dispatch.py` (new), modes:
   - **start**: candidates only from `tools/trusted_issues.py` (env `TRUSTED` or the script), start list from
     `start_state()`. For each candidate with a slip, in list order: `overlap.py --files <slip files> --issue N` (exit 1 or 2:
     skip, retried next run), `gh label create <label> --force`, add the model label, then add `agent:dev` last. Overlap is
     recomputed per issue, so two ready issues on the same files start one at a time. N free slots and N ready issues
     start N issues in one run.
   - **after-merge**: for each merged same-repo `agent/` PR (not cross-repository, the `stuck_slots()` rule) remove
     `agent:dev` from the issues in `Refs #N` / `Closes #N`; then run **start**.
   - It writes labels only. It never reads issue text beyond numbers and `Files:`/`Model:`/`Depends on:` lines, never runs
     or opens a path, and posts no comment text taken from an issue.
4. `.github/workflows/dispatch.yml` (new): triggers `issues` (opened, edited by non-author-bot, closed, labeled with
   `approved`/`auto-ok`), `issue_comment` created, `pull_request_target` closed (merged), `workflow_run` of `validate` on
   main and of `orchestrator` (completed), hourly `schedule` as fallback, `workflow_dispatch`. Job `if` needs
   `vars.DISPATCH == 'on'`; `concurrency: dispatch`, `cancel-in-progress: false` (runs are idempotent and read live state,
   so a replaced pending run loses nothing). Same author app token and permissions as the orchestrator, checkout of the
   default branch only, no PR code. `GUARD_KEY` only in the script step that calls `trusted_issues.py`.
5. `orchestrator.yml` and `.agents/roles/orchestrator.md`: with `DISPATCH=on` the prompt tells the model to write the slip
   comment only (goal, `Files:`, `Model:`, acceptance) for the issues in `needs_slip`, no labels, no `agent:dev` removal,
   no start; HANDOVER.md only when `handover_due`. `dispatch.yml` starts them when their comment lands (`issue_comment`
   by the author app) and again after the orchestrator run.

Why not leave the removal after merge to the model: it is the largest group of model runs per merged PR and needs no
judgement. Not moved to script here: design split issue creation (step 1b) and `needs-human` decisions stay model work.

## 5. Migration and compatibility

Repo variable `DISPATCH` (default unset = off): off, nothing changes. `on`, `dispatch.yml` runs and the orchestrator prompt
drops labelling. Both writing labels in the same minute is harmless (adding a present label is a no-op, `overlap.py` defers
the second) but not intended, so switch the variable only after steps 1 to 4 are merged. Downstream projects get the
files through template sync (`managed.json`, `x` bump only if `sync:must`); they set `DISPATCH` themselves. No change to
`trusted_issues.py`, `deps.py`, `overlap.py`, `agent-dev.yml` or label names.

## 6. Test and verification plan

New `tests/test_slip.py`, `tests/test_dispatch.py`, additions to `tests/test_prefilter.py`, all with a fake `gh` (a stub on
`PATH` or an injected runner that records calls). Each case fails on today's code (no `tools/dispatch.py`, no `needs_slip`):
- A design split issue with `Files:` in its body gets `model:sonnet` (from `Model:`) and then `agent:dev`, no model run.
- N free slots, N ready issues with slips: one run adds `agent:dev` to N issues; N+1 issues start N.
- Slip in the body of an `approved` stranger issue: not started, counted in `needs_slip`; slip in a comment by the author
  app: started.
- `overlap.py` exit 1 and exit 2: not started, no label call; two ready issues on the same files: only the first starts.
- `Depends on:` an open issue: not started. `needs-human`, `agent:dev`, `idea` without approval: not started.
- Trust: an open issue missing from `TRUSTED` gets no gh call at all (assert on the recorded calls).
- After-merge: `Refs #N` removes `agent:dev` from #N; a cross-repository PR or a non-`agent/` branch removes nothing.
- Label order: `agent:dev` is the last call; a failing `label create` does not stop the other issues.
- `prefilter.orchestrator_work()` is false with all candidates holding a slip and no `needs-human`; true with one without a slip;
  `handover_due` false when today's handover PR exists.
- Static: `make check` (actionlint, zizmor on `dispatch.yml`; the existing `GUARD_KEY` test covers the new workflow).

Measurement after rollout (numbers go into the PR of step 5; numbers before are **open** until `gh run list` is allowed):
- Before (take on the day before `DISPATCH=on`) and after, 14 days each: `python3 tools/run_stats.py 14 orchestrator.yml`
  (model runs) and `gh pr list --state merged --search "merged:>=<date>" --json number` (merged PRs). Metric: orchestrator
  model runs per merged PR. Target: at least halved; a design merge still counts one.
- Latency: time from the `approved` label (or the closing of the last `Depends on` issue) to `agent:dev`, from the issue
  timeline. Target: under 2 minutes for an issue with a slip (baseline 26 min, #415).
- Stop rule: if, after 14 days, any issue with a slip waited for the model or any start was denied, open one follow-up issue.

### Result (step 5, measured 2026-11-12)

Command: `python3 tools/run_stats.py 14 orchestrator.yml` (the 14-day window, DISPATCH on since 2026-11-12).
- Model runs of `orchestrator.yml`: 26, gate-skipped runs: 656 (re-run later the same day). All model runs fall on
  2026-11-12, the only day listed.
- Merged PRs: `gh pr list --state merged --limit 200 --search "merged:>=2026-11-12" --json number --jq length` gives 70 for
  2026-11-12 (until about 10:21 UTC), and 30 for 2026-11-11 with `merged:2026-11-11`.
- Model runs per merged PR on 2026-11-12: 26 / 70 = 0.37. This mixes the hours before and after the switch-on, so it is
  not a before/after result. Before and after `DISPATCH=on`: **open** (the window holds no day before the switch-on, so
  there is no baseline).
- Latency from label to `agent:dev` (target under 2 minutes): **open**, not read from the issue timeline.
- Do not read the 2026-11-12 count as a result: it is one day, and it mixes runs from before and after the switch.

## 7. Rollback

Set `DISPATCH` to off or unset: `dispatch.yml` skips, the prompt again labels and starts as today. Reverting the PRs of steps
2 to 4 restores the old files; labels already set stay valid. No data migration.

## 8. Split into PR-sized implementation issues

| Step | Title | Files | Depends on |
|---|---|---|---|
| 1 | Slip detection and model line (`tools/slip.py`) | `tools/slip.py`, `tests/test_slip.py` | - |
| 2 | Prefilter: `start_state()`, `needs_slip`, `handover_due`, model gate | `tools/prefilter.py`, `tests/test_prefilter.py` | 1 |
| 3 | Dispatcher script: start and after-merge | `tools/dispatch.py`, `tests/test_dispatch.py` | 2 |
| 4 | `dispatch.yml`, orchestrator prompt and role (behind `DISPATCH`) | `.github/workflows/dispatch.yml`, `.github/workflows/orchestrator.yml`, `.agents/roles/orchestrator.md` | 2, 3 |
| 5 | Switch on, measure with `run_stats.py`, record numbers | `docs/design/0015-model-free-dispatcher.md` (result section), `CHANGELOG.md` | 4 |

Steps 1 and 2 touch disjoint files but 2 uses the slip helper, so the chain is short rather than wide; step 4 touches
`.github/` and gets the security reviewer (`risk:security`).

## 9. Owner decisions

none
