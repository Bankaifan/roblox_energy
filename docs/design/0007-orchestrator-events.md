# 0007 Orchestrator event triggers

Issue: #125 (design study, no implementation in this PR). The answer part of #125 is design 0006 (#191); this design does not repeat it.

## 1. Goal

The orchestrator reacts to every relevant event instead of waiting for a merge, an `approved`/`auto-ok` label, the 06:43 UTC schedule or a manual start:
issues `opened`, `edited`, `closed`, `labeled`; `issue_comment` `created`; `pull_request` `opened`, `closed`; `pull_request_review` `submitted`.
Only events by Daniel (OWNER) or the two agent apps count. A script decides without a model whether there is work. Bursts give one run. The orchestrator never
starts itself. The model quota does not grow beyond what is measured before and after.

## 2. Current state (file references)

- `orchestrator.yml:10-18`: triggers are `workflow_run` (validate on main), `issues: labeled`, `schedule`, `workflow_dispatch`. The job `if` (`:23-31`) lets only `approved`/`auto-ok` label events through.
- `tools/orchestrator_gate.py`: for label events checks that OWNER set the label (`same_login`) and drops the run if an earlier orchestrator run was created at most 180 s before
  (`debounced`, `decide`). A debounced run is **dropped**, not queued: the later event of a burst is lost. This contradicts "queued, not dropped" in #125. The
  workflow-level `concurrency: orchestrator`, `cancel-in-progress: false` (`:33-35`) keeps one running and the newest pending run, so queueing exists only there.
- `tools/prefilter.py orchestrator` (`:116-131`): counts `dev_open`, free slots, startable candidates, `needs-human` PRs and a stale HANDOVER.md; `work` is true if candidates exist,
  `needs_human > 0` or the handover is stale. The model step runs only on `work=true` (`orchestrator.yml:105-133`). It does not look at issue comments, new PRs without `needs-human`,
  reviews or the event that started the run. Because `needs_human > 0` is true as long as any PR waits for Daniel, `work` is often true and the filter saves less than it seems (open, not measured here).
- Trust: `tools/trusted_issues.py` builds the candidate list (author OWNER or `approved`/`auto-ok` set by OWNER, guard-signed overdue issues). The prompt may only pick from that list.
- Self-loops today: the HANDOVER-only merge check (`orchestrator.yml:79-83`). Comments and labels written by the orchestrator through the author app token do trigger workflows
  (only `GITHUB_TOKEN` events do not), so as soon as it listens to comments and labels it would restart itself.
- Other listeners: `agent-dev.yml` on `issue_comment` (OWNER/MEMBER/COLLABORATOR, `/dev`); design 0006 adds `answer-receiver.yml` for an OWNER comment on a `needs-human` item.

## 3. Options with trade-offs

Where the filtering happens:
- A. One `on:` list with many event types, filter in the job `if` only. Simple, but every foreign comment on a public repo creates a (skipped) run entry and the `if` cannot read
  `author_association` and app logins reliably for all event types.
- B. Many events, a cheap first job (`gate`, script only, no model, read token) decides on live data, then the existing job. Chosen. A skipped run costs seconds and no quota.
- C. A separate "dispatcher" workflow that calls `workflow run orchestrator.yml`. One more workflow and token, the same filtering problem moved. Rejected.

Debounce:
- D. Today's drop of the later run. Loses the final state of a burst (the last comment may be the one that matters). Rejected for events.
- E. Let the group keep the newest pending run and have each run wait first (sleep 60 s, as design 0006 does for 45 s), then the gate asks "is there a newer event of mine pending?".
  A burst gives one run on the last event; one run is always allowed after the burst. Chosen. The 180 s window of `orchestrator_gate.py` stays for label events until
  PR 2 replaces it with the same rule.

Self-loop guard:
- F. Compare the sender to the app login only. A run started by a human still lets its own comments start the next run through the app.
- G. Sender check plus a run window: the gate ignores events written by the author app *during a run of the orchestrator* (event time inside `[run start, run end + 60 s]` of an
  orchestrator run). Needs no marker in model text. Chosen: F alone is not enough
  because other agent apps (developer, reviewer) legitimately produce events the orchestrator should see; G only filters the orchestrator's own echo.

Which events decide "work":
- H. Every accepted event starts the model. Quota risk.
- I. The gate maps the event to a script-checkable reason, `prefilter.py` gets an `event` input and `work` needs a reason that fits (table in 4.3). Chosen.

## 4. Chosen approach

B + E + G + I.

### 4.1 Trigger list
`orchestrator.yml` adds `issues: [opened, edited, closed, labeled]`, `issue_comment: [created]`, `pull_request_target: [opened, closed]` and `pull_request_review: [submitted]`. For PR events
`pull_request_target` runs the workflow from `main` and never checks out PR code (the checkout is the default branch; add a zizmor ignore for `dangerous-triggers` with that reason,
as for `workflow_run` today). Existing triggers stay. `pull_request_review` has no `_target` variant and does not get secrets for fork PRs, so it is **open** whether it works for
same-repo agent PRs: PR 4 measures it on a test PR. If it has no secrets, review submissions are seen by the next label, comment or schedule event (the reviewer's own comments/labels are app events that pass the gate).
The job `if` is only a coarse pre-check (`vars.ORCHESTRATOR_ENABLED`); the decision is in the gate.

### 4.2 Trust filter (point 2)
`tools/orchestrator_gate.py` `decide()` gets the full event, not only the label. Accepted senders: login equal to OWNER (`same_login`), the author app login (`AUTHOR_BOT`) or the approver
app login (`APPROVER_BOT`). The gate re-reads the object with the read-only token and checks live data: item exists, the comment id exists and its author login equals the sender,
the label event on the timeline was made by that sender. `author_association` and `sender.type` of the payload are not trusted alone. Everything else exits `skip=true` and the
reason goes to stderr. A comment or issue body by another account is never passed to the model by the gate; the existing rule stays that the model picks only from
`trusted_issues.py` output and reads comments only through the role file's rules.

The same rule applies to what an accepted event causes: an `opened` issue by an app is a candidate only if `trusted_issues.py` already lists it (guard-signed or `approved`/`auto-ok`
by OWNER). An issue edit by Daniel on a trusted issue counts, an edit by anyone else does not.

### 4.3 Prefilter per event (point 3)
`prefilter.py orchestrator` reads `EVENT` and `EVENT_ACTION` (set by the gate step) and computes `reason`, a short word logged and written to `$GITHUB_OUTPUT`:

| Event | `work` requires |
| --- | --- |
| `issues` opened/edited/labeled | the issue is in the trusted list and startable, or has `needs-human` and a new OWNER comment or edit |
| `issues` closed | a linked open PR or `agent:dev` label exists that must be cleaned up |
| `issue_comment` created | OWNER comment on an item with `needs-human` without a receiver marker (design 0006 is faster; this is the fallback), or on a trusted issue |
| `pull_request` opened | agent PR beyond the slot caps, a design PR (step 1c) or an unlinked PR needing a slot decision |
| `pull_request` closed | merged: remove `agent:dev` from its issue, create implementation issues of a design PR (1b); closed unmerged: restart accounting |
| `pull_request_review` submitted | `CHANGES_REQUESTED`/`APPROVED` by the approver or OWNER on a PR that the orchestrator tracks |
| schedule, dispatch, validate on main | today's rule, unchanged |

If no row fits, `work=false` and the model does not run. The existing counts stay and stay the fallback for schedule/dispatch. The step prints `reason` and the counts. Tests give each row
one case with `work=true` and one with `work=false`.

### 4.4 Debounce (point 4)
Every event run first waits (`sleep 60`, script step) so a burst has landed. Job `concurrency: group: orchestrator`, `cancel-in-progress: false` (unchanged: a running orchestrator is never cancelled;
GitHub keeps the newest pending run, older pending ones are cancelled). After the wait the gate asks `gh run list` whether a **newer pending** orchestrator run exists; if yes it exits
without work (the newer run sees everything). If no newer one exists it proceeds, whatever ran before. This replaces the "earlier run within 180 s drops me" rule of `orchestrator_gate.debounced`,
which loses the last event of a burst. The 60 s sleep counts as runner time, not model quota.

### 4.5 No self-loops (point 5)
1. No marker in comments and no change to how the model writes: the gate alone enforces the rule on the receiving side, using run windows (rule 2).
2. The gate drops an event when the sender is the author app and the event time lies inside an orchestrator run window (`gh run list --workflow orchestrator.yml --json createdAt,updatedAt,conclusion` plus 60 s).
   Labels set by the orchestrator (`agent:dev`, `model:*`, `prio:*`) fall under this rule. `labeled approved/auto-ok` by OWNER still passes.
3. The existing HANDOVER-only merge check stays.
4. Hard stop: if the last 3 orchestrator runs were all started by an event of the author app and each created at most 5 minutes after the previous, the gate refuses and comments once in the status issue
   (`STATUS_ISSUE`). It is a brake against a loop nobody saw, not the normal protection.

### 4.6 Daniel's answers (point 6)
Overlap with design 0006: **0006 owns the immediate path** for one event type: an OWNER comment on a `needs-human` item, via `answer-receiver.yml`, with marker, allowlist and
confirmation. This design does not parse yes/no and starts no action from a comment. It adds only the fallback: the orchestrator also wakes on that comment (row `issue_comment` above) so that an
old note without a marker, or an answer when `ANSWER_RECEIVER=off`, is not lost until the next day. The orchestrator skips the item if a receiver marker newer than the `needs-human`
event exists (rule from 0006 section 4.6) and otherwise follows the existing `orchestrator.md` rule: read the German note's question and Daniel's reply, act only within AGENTS.md Limits, no parsing script.
So 0006 may land before or after this design; nothing here depends on it.

### 4.7 Quota (point 7)
Measure first, in PR 1: a script `tools/run_stats.py` prints model runs per day for the last 14 days (`gh run list --workflow orchestrator.yml`, conclusion not `skipped`, and whether the
`claude` step ran, from the job steps API) and the number of gate-skipped runs. The value is written into the PR body as the "before" baseline. After rollout (PR 4) the same
command over 7 days is the "after". Keep: the agent caps (`MAX_DEV`, `MAX_PRS` in `prefilter.py`, repo variables, defaults 2 and 3; this design does not change them), model `sonnet`, `--max-turns 40` unchanged. Switch: repo variable `ORCHESTRATOR_EVENTS=off`
(gate: events other than today's four are skipped). Acceptance for the rollout: model runs per day after <= 2x before; otherwise tighten the table in 4.3 or turn the switch off. The 2x is a proposal; Daniel
decides it (section 9).

## 5. Migration and compatibility

Additive. With `ORCHESTRATOR_EVENTS=off` or unset the new events are accepted by the workflow but the gate skips them: no model runs, only seconds of runner time. Schedule, dispatch, validate-on-main and
the label path behave as today. `setup.yml` documents the variable. Template sync (design 0001): `orchestrator.yml`, `tools/orchestrator_gate.py`, `tools/prefilter.py`, `tools/run_stats.py` are managed paths.
`orchestrator.yml` and the gate are CODEOWNERS/trust logic: every PR that touches them is `risk:security` and needs Daniel's approval.

## 6. Test and verification plan

All fail on today's code (the gate knows only label events; `prefilter.py` has no event input):
- `tests/test_orchestrator_gate.py` (extended): sender OWNER / author app / approver app accepted; any other login refused for each event type; the comment author is re-checked against live data;
  a burst of 3 events gives one run on the last (the earlier two skip because a newer pending run exists); an app event inside an orchestrator run window is ignored; the 3-in-5-minutes brake refuses.
- `tests/test_prefilter.py` (extended): one `work=true` and one `work=false` case per row of 4.3; unchanged results for schedule/dispatch.
- `tests/test_orchestrator_workflow.py` (new, pattern of `tests/test_unblocker_workflow.py`): the new triggers exist, no PR checkout on `pull_request_target`, `ORCHESTRATOR_EVENTS` switch, model step after gate and prefilter, `sleep` before the gate.
- `tests/test_run_stats.py`: counts model runs from fixture data.
- Measurement before rollout: baseline from `run_stats.py` (PR 1), then one test repo (or the real repo with `ORCHESTRATOR_EVENTS` on a branch) run with a comment by a non-owner account (expected: gate skip, no model),
  by Daniel on a trusted issue (expected: one model run), and a 3-comment burst (expected: one run). Recorded in the PR of issue 4. The `pull_request_review` secrets question of 4.1 is answered here.
- `make check` on every PR.

## 7. Rollback

`ORCHESTRATOR_EVENTS=off` stops the new paths without a revert. Each PR is one rebase-merged commit; `git revert` of PR 3 (the triggers) restores today's triggers exactly. `ORCHESTRATOR_ENABLED=false` stops everything.

## 8. Split into PR-sized implementation issues

Each under about 400 changed lines, disjoint files:
1. **Quota baseline** (no trigger change): `tools/run_stats.py`, `tests/test_run_stats.py`; the PR body carries the 14-day number. Independent, first.
2. **Gate for all events** (trust logic, `risk:security`): `tools/orchestrator_gate.py` (sender filter, live check, debounce rule E, self-loop rule G and brake), `tests/test_orchestrator_gate.py`. No workflow change yet, so nothing runs differently.
3. **Prefilter per event** (needs nothing from 2): `tools/prefilter.py` (`EVENT`/`EVENT_ACTION`, `reason`), `tests/test_prefilter.py`.
4. **Triggers and switch** (`risk:security`, needs 1 to 3): `.github/workflows/orchestrator.yml` (new events, `sleep`, gate/prefilter env, `ORCHESTRATOR_EVENTS`), `tests/test_orchestrator_workflow.py`, `setup.yml` variable, the measurement run.
5. **Role and docs** (after 4): `.agents/roles/orchestrator.md` (act on Daniel's answer with no receiver marker, skip rule from 0006), `docs/decisions/NNNN-orchestrator-events.md`, README paragraph.

2 and 3 are disjoint with 1; under the 2-job cap run 1 and 2 first.

## 9. Owner decisions

Daniel decides:
1. May the orchestrator wake on non-label events at all (more runner minutes, possibly more model runs)? The design assumes yes, behind `ORCHESTRATOR_EVENTS` (default off at merge, turned on after the measurement).
2. The quota limit for rollout: "model runs per day after <= 2x before" is a proposal; tell us a different number if the subscription allows less.

Open, not owner decisions: whether `pull_request_review` has secrets for same-repo agent PRs (PR 4 measures it); how many orchestrator model runs per day there are today (PR 1 measures it);
how often `needs_human_prs > 0` makes `work` true on a quiet day (PR 3 reads it from the log).
