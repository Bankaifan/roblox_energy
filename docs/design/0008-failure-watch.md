# 0008 Failure watch

Issue: #190 (design study, no implementation in this PR).

## 1. Goal

Every status run (script, no model) finds failed workflow runs, opens exactly one guard issue per failure signature, closes it when the workflow is green again, and reopens it when the same failure comes back.
On the third recurrence the issue gets `needs-human`. The weekly summary lists open, closed and reopened failure issues. The orchestrator picks the issues up by priority because they are signed guard issues. No log text ever enters an issue (design 0004).

## 2. Current state (file references)

- `tools/liveness.py`: `SCHEDULED` (four workflows), `is_overdue`, `ensure_overdue_issue` (dedup by title, `prio:1`, body signed with `guard_mark.sign`), `flag_overdue`. It only opens issues; nothing closes `Overdue scheduled run: <label>` (#98-#100 stayed open).
- `tools/run_report.py`: `ensure_denial_issue` is the second signed guard issue (`prio:2`, dedup by title, fixed strings only).
- `tools/guard_mark.py`: HMAC over title and body, marker at the end of the body; `GUARD_KEY` only in script steps.
- `tools/trusted_issues.py:51-57` `is_guard_issue`: author app, not `idea`, valid signature. Any signed guard issue is already trusted, so a new issue family needs no new trust rule, but a title-prefix allowlist is missing: a leaked key would make any title trusted (see 4.6).
- `tools/status.py` `run_status` (`:399-475`): collects runs with `gh run list`, handles orphans, conflicts and limits, then `liveness.flag_overdue`. It runs on schedule, dispatch and after `agent-dev`, `agent-fix`, `agent-review` (`status.yml:7-13`). Event-triggered workflows that fail (unblocker, agent-review, template-sync, automerge, risk, setup) are seen only as orphans, if at all.
- `tools/weekly_summary.py`: builds the weekly body from merged PRs, needs-human, rule keeper, ideas, and `status_stale`. No failure section.
- Token: `status.yml` gives the app token `actions: write`, `issues: write`; GitHub allows reading runs and jobs with that. Open: whether `actions: read` on the status token is enough for `actions/runs/{id}/jobs` (it is, per GitHub docs; PR 1 confirms on the real repo).

## 3. Options with trade-offs

Collection:
- A. `workflow_run` trigger on every workflow, one watch run per failure. Instant, but a trigger on all workflows is a new `workflow_run` surface (zizmor `dangerous-triggers`) and an outage floods runs. Rejected.
- B. Poll `actions/runs` in the existing status run, window since the last tick. Chosen: no new trigger, no new token, bounded per tick.

Signature:
- C. Hash of the log. Needs logs, which are untrusted. Rejected.
- D. Workflow file + failed job + failed step name from the jobs API (names come from workflow files in the repo, not from logs). Chosen. Names are still repo-controlled text, so they are sanitised (see 4.2).

Dedup and state:
- E. A state file or cache. Another place to lose state. Rejected.
- F. The issue is the state: title is the key, the body carries the counter and the last run id, re-signed on every change. Chosen, like the overdue and denial issues.

## 4. Chosen approach

B + D + F, in a new module `tools/failure_watch.py` called from `run_status` after `flag_overdue`.

### 4.1 Collect
`collect(since, run)` calls `gh api repos/{repo}/actions/runs?created=>=<since>&status=completed&per_page=100`, one page (a second page only if the first is full, max 3 pages). `since` is the anchor of 4.3 (`Failure watch since:` in the status issue), minus 5 minutes overlap, at most 24 hours back (first run, or after an outage). Dedup across ticks is by run id kept in the issue body (`Last run: <id>`), so an overlap never counts a run twice.
Keep conclusions `failure`, `timed_out`, `startup_failure`. Skip: `cancelled`, `skipped`, `success`, `neutral`, `action_required` (the status run approves those); `validate` and `agent-review` whose `head_branch` starts with `agent/` (agent-fix rounds own them); the `status` workflow itself (no self-reference); runs of `pull_request` events from forks.

### 4.2 Signature
For each kept run: `gh api repos/{repo}/actions/runs/{id}/jobs`, first job with conclusion `failure`/`timed_out`, its first failed step. No failed step (startup failure, runner lost): step `-`. Signature = `<workflow file> / <job name> / <step name>`; each part is cut to 60 characters and limited to `[A-Za-z0-9 ._:/()-]`, other characters become `_`. Title: `Failing workflow: <signature>`.
Body is fixed script text: `The workflow <file> failed in job <job>, step <step>.`, then `Failures: <n>`, `Last run: <url>`, `Closed by: <PR url or none>`, then the guard signature. No log text, no commit message, no PR title. Signed with `guard_mark.sign` and `GUARD_KEY`; no key means no signature, so the issue stays untrusted (fail closed).

### 4.3 One issue per signature, priority, flood cap
- Dedup by exact title over open and closed issues (`gh issue list --state all --search`), as `ensure_overdue_issue` does for open ones.
- Label `prio:2`. `prio:1` from the third failure in a row (counter `Failures` reaches 3 without a success between) or when the workflow is a merge gate: `validate.yml` on `main`, `risk.yml`, `agent-security-review.yml` (list `MERGE_GATES` in the module).
- At most 5 new issues per tick (`MAX_NEW = 5`); further signatures are `deferred`. So they are not lost, the window anchor is not the status run time but the `created_at` of the oldest deferred run (or the newest handled run if nothing was deferred), kept in the status issue line `Failure watch since: <ts>`. A tick that defers adds `failure watch: N signatures deferred` to its actions.
- Recurrence updates (4.5) are not new issues and do not count against the cap.

### 4.4 Auto-close
For every open failure issue the module asks for the newest completed run of the same workflow file that is newer than the issue's `Last run`: `gh run list --workflow <file> --limit 5 --json conclusion,createdAt,url,headBranch`. A `success` on the default branch (or, for workflows that only run on PRs, any success on a non-`agent/` ref) closes the issue with one comment `Closed by the failure watch: <run url> succeeded.` and records the run in the body. The job must also have succeeded: when the success run's job list has the job of the signature with conclusion `success`, close; if the job is absent in that run (skipped by a path filter) leave the issue open.
The same function closes `Overdue scheduled run: <label>` issues: if the workflow of `<label>` (map from `liveness.SCHEDULED`) is not overdue in this tick (`liveness.overdue_runs` returns no label for it), the open issue gets the comment `Closed by the failure watch: the scheduled run is current again.` and is closed. This also closes #99 and #100 on the first run after the merge. Only issues whose title is exactly `liveness.overdue_title(label)` and whose signature verifies are touched; a stranger's issue with that title is left alone.
Comments use `liveness.post_comment` (read back, `ReadbackError` handled like in `run_status`).

### 4.5 Recurrence
A kept failing run whose signature matches a **closed** failure issue reopens it: `gh issue reopen`, body rewritten with `Failures` increased by one, `Reopened: <k+1>` and `Closed by: <PR url>` (the PR whose `closed_by` timeline event or `Closes #N` linked it, from `gh api repos/{repo}/issues/{n}/timeline`, event `closed` with `commit_id`, then `commits/{sha}/pulls`; none if unknown), and a comment `Same failure again after the fix in <PR>: <run url>.` The body is re-signed, so the signature stays valid.
At `Reopened: 3` the issue also gets `needs-human` and the comment follows the "Waiting for Daniel" note format of AGENTS.md (German, one yes/no question). The unblocker sees `needs-human` first and decides before the orchestrator would take the slip. Escalation uses the existing `status.escalate` helper. The label is added once (no second add when the label exists).
A failure in an issue that is still open only increments `Failures` and updates `Last run` (the "third in a row" priority bump). The counter in the body is the only state; tests compare against the signed result.

### 4.6 Trust: `tools/trusted_issues.py`
Today any validly signed issue is trusted. Add `GUARD_TITLES = ("Overdue scheduled run: ", "Denied command in ", "Failing workflow: ")` and require `title.startswith` one of them in `is_guard_issue`. This narrows trust (a leaked `GUARD_KEY` can no longer trust an arbitrary title) and registers the new family. The classification output stays the same (`guard: true`). `orchestrator.md` gets one line that the issue family exists and that a failure issue is fixed like a normal slip (the developer reads the run, not an untrusted log in the issue). The change touches trust logic: `risk:security`, Daniel approves.

### 4.7 Weekly summary
`tools/weekly_summary.py` gets a section `Failure watch`: open failure issues, closed this week, reopened this week (issues updated in the last 7 days with `Reopened: >= 1`), by `gh issue list --search "Failing workflow:" in:title`. Only title, number and counters are printed. A read failure yields `unknown`, not an empty list.

### 4.8 Fit with the status run
`run_status` calls `failure_watch.run(env, now, run)` after the overdue block, inside `safe(...)`, so an error never stops the status issue. Actions are appended to `actions` (`opened failure issue #N`, `closed failure issue #N`, `reopened #N`). No new workflow, no new secret; `status.yml` already has `GUARD_KEY` and `issues: write`, and gets `permission-actions: read` implied by `actions: write`. `liveness.py` stays the source of the overdue titles; `run_report.py` is unchanged (it keeps writing denial issues).

## 5. Migration and compatibility

Additive. Without `GUARD_KEY` nothing is signed and the issues are not trusted: they are created but the orchestrator ignores them (as for overdue issues today). Existing `Overdue scheduled run` and `Denied command in` issues keep their trust (prefix allowlist, 4.6). The repo variable `FAILURE_WATCH=off` skips the module (default on after merge of PR 3). Open failures that already ran before the merge are not back-filled: the first window is the last 24 hours.

## 6. Test and verification plan

All of these fail on today's code (no `tools/failure_watch.py`, no allowlist):
- `tests/test_failure_watch.py`: collect filter (keeps failure, timed_out, startup_failure; drops cancelled, skipped, `agent/*` validate and agent-review, `status` itself); signature (sanitising, 60 character cut, missing step -> `-`, no log text possible: fixture with a hostile step name is neutralised); dedup (second failure of the same signature updates, does not create); flood cap (7 signatures -> 5 issues, 2 deferred, cap not counted for updates); priorities (`prio:2`, `prio:1` on third in a row and for each merge gate); auto-close (success of the same job closes, success without that job does not); overdue auto-close (not overdue closes, overdue stays, foreign title untouched, #99/#100 fixture); reopen with counter and PR link; escalation `needs-human` on the third recurrence and only once; signature stays valid after every body change.
- `tests/test_trusted_issues.py` (extended): signed `Failing workflow:` issue is trusted; a signed issue with another title is not; a failure issue without a valid signature or by another author is not.
- `tests/test_weekly_summary.py` (extended): the section lists open, closed, reopened; read failure prints `unknown`.
- `tests/test_status.py` (extended): the watch runs after overdue, an exception in it does not stop the status issue.
- `tests/test_status_workflow.py`/`test_guard_mark.py` pattern: `GUARD_KEY` still only in script steps.
- Measurement: after PR 3, `workflow_dispatch` of status on the real repo; expected: #99 and #100 closed, no new issue while all workflows are green. Then break a test workflow on a throw-away branch and check one issue is opened, one comment on the next green run closes it. Recorded in the PR body of PR 3.
- `make check` on every PR.

## 7. Rollback

`FAILURE_WATCH=off` stops the module without a revert. Each PR is one rebase-merged commit; reverting PR 3 removes the call from `run_status`, reverting PR 1 removes the allowlist. Open failure issues are ordinary issues: close them by hand.

## 8. Split into PR-sized implementation issues

Each under about 400 changed lines, disjoint files:
1. **Trusted title allowlist** (`risk:security`): `tools/trusted_issues.py` (`GUARD_TITLES`), `tests/test_trusted_issues.py`, one line in `.agents/roles/orchestrator.md`. First: later issues need it, and it is useful alone.
2. **Failure watch module** (no wiring): `tools/failure_watch.py` (collect, signature, dedup, cap, priority, auto-close incl. overdue, reopen, escalation), `tests/test_failure_watch.py`. Nothing calls it yet. If it grows past 400 lines, split collect and signature (2a) from close and reopen (2b) at the function boundary of 4.1-4.3 and 4.4-4.5.
3. **Wire into the status run** (`risk:security`: workflow and status logic): `tools/status.py` (call, `FAILURE_WATCH` switch, status issue line), `.github/workflows/status.yml` (env `FAILURE_WATCH`), `tests/test_status.py`, the measurement run. Needs 2.
4. **Weekly summary**: `tools/weekly_summary.py`, `tests/test_weekly_summary.py`. Independent of 3, needs the title format from 2.

Order: 1, then 2, then 3 and 4 in either order. Under the 2-job cap run 1 and 2 first (disjoint files).

## 9. Owner decisions

none
