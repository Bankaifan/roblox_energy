# 0012 Orchestrator events

Status: accepted (issue #125, design 0007, built in parts: quota baseline, gate, prefilter, triggers and switch, role and docs).

Context: the orchestrator used to wake only on a label `approved`/`auto-ok`, a merge to `main`, the 06:43 UTC schedule or a manual start. A new issue, a comment from Daniel on a `needs-human` item, a finished PR or a review waited until the next run of one of those. Every extra wake-up can cost a model run, so the subscription quota is the limit.

Decision:
- Triggers (`.github/workflows/orchestrator.yml`): `issues` opened, edited, closed, labeled; `issue_comment` created; `pull_request_target` opened, closed; `pull_request_review` submitted. The existing `workflow_run` of `validate`, `schedule` and `workflow_dispatch` stay. `pull_request_target` checks out the default branch only; PR code is never run.
- Switch: repo variable `ORCHESTRATOR_EVENTS`. Only `on` lets the non-label events through; unset or any other value skips them (no model run). The label path (`approved`/`auto-ok` by Daniel) does not depend on it. `setup` reports the variable.
- Gate (`tools/orchestrator_gate.py`, runs before any model step): accepts an event only if the sender is Daniel (OWNER), the author app or the approver app; re-reads the object live (for `opened`, the author login must equal the sender); drops an author-app event that falls inside an orchestrator run window (run start to run end + 60 s, so the orchestrator does not wake itself); skips the run if a newer orchestrator run is pending (a burst gives one run, on its last event); refuses after three runs in a row started by the author app, each at most 300 s after the previous, and comments once in the status issue.
- Debounce: each event run first sleeps 60 s so a burst has landed. Label events keep the 180 s rule of the gate.
- Prefilter (`tools/prefilter.py`): with an event, the table below decides `work`; the model runs only on `work=true`. Schedule, dispatch and validate-on-main keep the count rule. The step prints the `reason`.

| Event (action) | Reason when `work=true` |
| --- | --- |
| `issues` opened/edited/labeled | `startable-issue`: trusted issue, free PR slot, no `agent:dev` or `needs-human`; `owner-reply`: `needs-human` and sender is Daniel |
| `issues` closed | `cleanup-closed-issue`: `agent:dev` label or a linked open PR |
| `issue_comment` created | `owner-answer`: Daniel on a `needs-human` item whose newest comment is not an answer-receiver marker; `owner-comment-trusted`: Daniel on a trusted issue |
| `pull_request` opened | `pr-over-cap`: agent PR and no free PR slot; `design-pr`: a design PR; `unlinked-pr`: not an agent PR and closes no issue |
| `pull_request` closed | `merged-pr`: merged design PR or one closing an `agent:dev` issue; `closed-unmerged-pr`: not merged, closes an issue |
| `pull_request_review` submitted | `review`: `CHANGES_REQUESTED` or `APPROVED` by Daniel or the approver app on an agent PR |

Any other combination: `work=false`, reason `no-match`.

Consequences:
- Off by default. With `ORCHESTRATOR_EVENTS` unset the new events cost seconds of runner time and no model run.
- Rollback without a revert: `ORCHESTRATOR_EVENTS=off`. `ORCHESTRATOR_ENABLED=false` stops the whole orchestrator.
- Quota: `tools/run_stats.py` counts model runs per day from the workflow runs. Acceptance proposed in the design: model runs per day after rollout at most 2x the baseline. The limit is Daniel's decision (design 0007 section 9).
- Prompt-injection boundary unchanged: the gate does not pass comment or issue text to the model; the model picks work only from `tools/trusted_issues.py`.

Open (not measured in this repo yet):
- Whether `pull_request_review` gets repository secrets for same-repo agent PRs (design 0007 section 4.1). Until it is measured, a review may only be seen by the next label, comment or schedule event.
- The 14-day "before" and 7-day "after" numbers of design 0007 section 6 are not recorded here.
- Daniel's decision on the 2x quota limit and on waking on non-label events at all.
