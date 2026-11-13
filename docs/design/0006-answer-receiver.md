# 0006 Answer receiver

Issue: #191 (design study, no implementation in this PR). Splits the answer part out of #125.

## 1. Goal

Every note that parks work with Daniel ends with a yes/no question (AGENTS.md "Waiting for Daniel"), but nothing reads the answer; only `/dev` on
issues reacts to comments (`agent-dev.yml:5,13`). On #184 the question "re-cut (ja) or close (nein)?" had no effect, and the bot set `needs-human`
and `review:N` again after Daniel removed them. The receiver reads Daniel's free-text reply on a `needs-human` item, maps it to one action from a fixed
allowlist, does it, confirms in German and closes the block. It also makes a label removal by Daniel stick.

## 2. Current state (file references)

- No workflow listens for comments on blocked items. `issue_comment` is used once, by `agent-dev.yml:5`, gated on OWNER/MEMBER/COLLABORATOR and a plain issue.
- `needs-human` is set by `agent_guard.escalate()` (`tools/agent_guard.py:229-244`), `restart.park_with_owner()` (`tools/restart.py:107-109`), `agent-fix.yml:89`,
  `agent-review.yml:74-79`, `dependabot-automerge.yml:79` and by agents by hand. `review:N` is bumped by `agent_guard.count_round()` (`tools/agent_guard.py:79-95`)
  and mirrored in `status.fix_round()` / `status.limit_prs()` (`tools/status.py:186-205`). All of them go through `agent_guard.add_labels` (`:73`) or
  `gh pr edit --add-label`; none looks at who removed the label before.
- Only `trusted_issues.label_set_by()` (`tools/trusted_issues.py:60`) reads label events, and only to check who set a label.
- The unblocker (`unblocker.yml`, `tools/unblock.py`, design 0002) shows the pattern of design 0004: read-only token for gate and fetch, model step without app
  token and without Bash (`--settings .github/claude-judge-settings.json`, `Edit(verdict.json)` only), `validate`, write token created afterwards, `apply`.
  It starts on `labeled`, not on comments.
- The German note is free text. Nothing says what "ja"/"nein" do (`AGENTS.md` "Waiting for Daniel", `orchestrator.md:32`, `reviewer.md:16`, `unblock._owner_note`).
- Likely cause of the #184 re-label (open, not measured here): Daniel removed `needs-human` and `review:3`; `status.limit_prs()` selects agent PRs at `review:N`
  without `needs-human` and `count_round()` bumps from "no label" to `review:1`, so the next status or review run parks it again. Implementation issue 1 reproduces
  it from the #184 timeline before fixing.

## 3. Options with trade-offs

Answer interpretation:
- A. Literal parser (`ja`/`nein`). Safe, but Daniel writes "ja, aber ohne X"; unclear answers are the normal case.
- B. Orchestrator reads the comment in its next run. No new trigger, but slow (scheduled), shares the orchestrator's broad token and gives no immediate confirmation.
- C. Dedicated workflow on `issue_comment`, model step on the design 0004 boundary. One more workflow, but small tokens and instant feedback. Chosen.

What the action comes from:
- D. The model chooses any action. Injection in the thread could steer it.
- E. The note carries a machine-readable marker that maps answers to actions; the model only picks which answer Daniel gave. The set of possible effects is fixed
  by whoever parked the item and by the script allowlist. Chosen.

Label removals:
- F. Mark "owner removed X" in a label or comment. Extra state that can drift.
- G. Read the label timeline (`issues/N/events`): the latest `unlabeled` event for the label by OWNER decides. No new state. Chosen.

## 4. Chosen approach

C + E + G.

### 4.1 Trigger (point 1)
`.github/workflows/answer-receiver.yml`, `on: issue_comment: created` (zizmor ignore `dangerous-triggers` with the same reason as `agent-dev.yml:5`: workflow from
`main`, never PR code). Job `if`: `author_association == 'OWNER'`, `user.login == vars.OWNER` (default Bankaifan), `user.type != 'Bot'`, and the item's labels (from the event
payload) contain `needs-human`. The `gate` script step re-checks all of it on live data with the read-only token (item open, label still set, comment id exists, author
OWNER). Comments by bots or other accounts never start a model step. Off switch: repo variable `ANSWER_RECEIVER=off`.

Debounce: concurrency group `answer-receiver-<number>` with `cancel-in-progress: false` (an applying run is never cancelled; GitHub keeps only the newest pending run).
Each run sleeps 45 s first, then `gate` requires that the trigger comment is the newest OWNER comment on the item and that no receiver confirmation newer than it exists;
otherwise it exits 0 without a model call. A burst of comments therefore produces one run on the last one, which reads all OWNER comments since the note.

### 4.2 Reading the answer (point 2)
Order as in `unblocker.yml`: read-only token (`contents`, `issues`, `pull-requests` read) -> `answer.py gate` -> `answer.py fetch` writing masked, capped files
`untrusted/note.txt` (the last note carrying a decision marker), `untrusted/owner.txt` (Daniel's comments since that note, the trusted input), `untrusted/thread.txt`
(everything else, untrusted, for context only) -> model step (`--model sonnet`, no `github_token` write scope, no app token, no Bash, `--settings .github/claude-judge-settings.json`,
tools `Read,Glob,Grep,Edit(verdict.json)`) -> clean checkout -> `answer.py validate` -> write token created only now (`issues`, `pull-requests`, `actions` write, `contents` read)
-> `answer.py apply`. Checkout is the default branch, never PR code.

Verdict file (fixed schema, ASCII, all strings through `exec_log` masking and the secret-shape filter in one function as in `unblock.outgoing_strings`):
`{"intent": "yes|no|option|instruction|unclear", "option": "<key from the marker, only for option>", "instruction": "<English, max 600 chars, only for instruction>",
"question": "<German, max 300 chars, only for unclear>", "evidence": "<exact quote from untrusted/owner.txt, max 200 chars>"}`.
`validate` refuses: an `option` key not in the marker, `yes`/`no` when the marker lacks them, an `evidence` that is not a substring of `owner.txt`, any `@`, any field not
allowed for the intent. Intent semantics: `yes`/`no`/`option` = Daniel picks that answer without changing it; "ja, aber ohne X" is `instruction` (the marker action is not run
because Daniel changed the terms); a clear question or anything ambiguous is `unclear`.

### 4.3 Marker and allowlist (point 3)
The party that parks an item writes, in the same comment as the German note, a hidden marker: `<!-- decision: yes=restart-recut no=close-pr -->`. Keys are `yes`, `no`
or short option names (`a`, `b`, ...); values are action ids. The marker counts only in a comment by the author app, the approver app or OWNER (checked by login, never by text),
and only the newest marker before Daniel's answer. A marker in a comment by anyone else is ignored.

Allowlist (`tools/answer.py`, one function per action, each re-runs its own safety refusals; unknown id = refusal, validated when the marker is parsed and again in `apply`):

| id | effect | reuses |
| --- | --- | --- |
| `close-pr`, `close-issue` | close the item with a comment | `gh pr/issue close` |
| `restart-issue` | `agent:dev` removed then added (new slip comment) | `unblock._restart`, `restart.restart_issue` |
| `restart-recut` | close the PR as superseded and restart its issue | `restart.handle_limit` path |
| `fix-pr` | dispatch `agent-fix.yml` with `pr=N` | `unblock._restart` |
| `reapprove` | run the approver path for an unchanged patch | `tools/reapprove.py` (keeps its refusals: no `risk:security`, no CODEOWNERS path, no design PR) |
| `drop-block` | remove `needs-human` and the review request only | - |
| `label:<name>` | add or remove one label from `prio:1..3`, `approved`, `auto-ok`, `agent:dev`, `agent:review` | `agent_guard.add_labels` |

Never in the list: merge, push, tag, edit a workflow, ruleset, permission or secret, approve a `risk:security` PR (Daniel does that in the GitHub review himself; a text answer
is not an approval of the security class). `merge` stays with the existing automerge path after a normal approval.

Free instruction (`instruction` intent): the script posts one comment `<!-- owner-instruction comment=<id> -->` with the validated English text and the link to Daniel's
comment, adds nothing else and starts the orchestrator (`workflow run orchestrator.yml`). The orchestrator acts on it only if the marker comment is by the author app and the
named comment id is an OWNER comment (role file rule), and AGENTS.md Limits apply to it unchanged. Items without any marker (old notes): only `drop-block` and `instruction`
are possible; never close or restart.

### 4.4 Closing the loop (point 4)
After a successful action `apply` (a) removes `needs-human`, (b) removes the owner review request or assignment (as `unblock._withdraw_owner`), (c) posts one German
confirmation built by the script from a fixed template per action ("Verstanden: <what happens now>. Der Block ist aufgehoben.") plus, for `instruction`, the quoted
English text; the model writes no German confirmation, so the post has no model-written German channel, (d) dispatches the orchestrator when the action needs it. The
confirmation carries `<!-- answer-receiver comment=<id> -->` (the debounce and idempotence key; a re-run for the same comment id does nothing). `unclear`: one German follow-up
question from the verdict (`question`, validated, masked), `needs-human` stays, marker `<!-- answer-receiver comment=<id> unclear -->`. Max one follow-up per OWNER comment; a
further unclear reply produces the next question, there is no automatic loop beyond what Daniel writes. A failed run never ends silently: comment "answer receiver ended
without an applied action, needs-human stays" with the run URL, as `unblocker.yml:115-121`.

### 4.5 Respect Daniel's label changes (point 5)
New `tools/owner_hold.py`: `owner_removed(events, label, owner, head_date)` is true if the latest `labeled`/`unlabeled` event for `label` is an `unlabeled` by OWNER and, for a PR,
newer than the head commit date (a new push is a new head and ends the hold); for an issue it ends with the next OWNER-set label event on the item or an OWNER comment containing
a new decision. `agent_guard.add_labels(kind, number, labels)` calls it for `needs-human` and `review:N` (the single choke point of all setters, plus the `--add-label` calls in shell
steps, which move to `guard label`). Refused: the label is not added, one comment says "Daniel removed <label>; not set again for this head" (no review request, no new
`needs-human`), and `count_round` / `status.limit_prs` skip the item. An OWNER removal of `review:N` resets nothing else; the round marker `round:<sha7>` stays. A silent agent run on such an item
comments but does not label.

### 4.6 Rules and notes (point 6)
- AGENTS.md "Waiting for Daniel": the question names what "ja" and "nein" do, and the note carries the decision marker (mandatory, one line). This edits AGENTS.md, so that PR needs Daniel's OK (Limit 5).
- Role files that park items (`orchestrator.md:23,32`, `reviewer.md:16`, `unblocker.md`, `restart.py` `NOTE_*`, `unblock._owner_note`, `agent_guard.escalate`) get the marker; `tests/test_role_rules.py` checks the rule text.
- `orchestrator.md`: skip an item whose newest comment is a receiver marker newer than the `needs-human` event (same rule as for the unblocker); act on `owner-instruction`.
- `unblocker.md`: class 3 notes carry the marker.

### 4.7 Delineation from #125
#125 keeps the other events the orchestrator should react to (new issues, PRs, reviews, CI, non-owner comments). This design covers one event only: an OWNER comment on an item that has
`needs-human`. Anything else in #125 stays out; the orchestrator's skip rule above prevents double handling.

## 5. Migration and compatibility

Additive. Old notes without a marker still work through `drop-block` and `instruction`. The label hold changes behaviour only where an OWNER removed a label. `ANSWER_RECEIVER=off`
disables the workflow. `setup.yml` documents the variable. Template sync (design 0001): the workflow, `tools/answer.py`, `tools/owner_hold.py` are managed paths. Needs `actions: write` on the
write token (already granted to the unblocker's).

## 6. Test and verification plan

All fail on today's code (no `answer.py`, no `owner_hold.py`, `add_labels` re-adds unconditionally):
- `tests/test_owner_hold.py`: OWNER unlabel of `needs-human` / `review:N` blocks `add_labels` and `count_round`; a new head ends the hold; a bot unlabel does not hold; a timeline from #184 (fixture) reproduces the re-label on today's code.
- `tests/test_answer.py`: gate (OWNER only, `needs-human` only, bot or other author refused, not newest comment refused); marker parsing (author app / approver / OWNER only, newest only, malformed refused);
  allowlist (unknown id refused, `label:` outside the list refused, `reapprove` keeps its refusals); verdict validation (option not in marker, evidence not a substring, `@`, extra field, secret shape in
  every string field, one test per field); `instruction` hand-over comment; `unclear` follow-up and no state change; idempotence on the same comment id; confirmation text comes from the template, not the model.
- `tests/test_answer_workflow.py`: `if` gate, no app token and no Bash in the model step, write token created after validate, `--settings` present, `ANSWER_RECEIVER` switch (pattern of `tests/test_unblocker_workflow.py`).
- `tests/test_role_rules.py` (extended): AGENTS.md and role files name the marker.
- Measurement before rollout: one test-repo run with Daniel's account replying "ja, aber ohne X" and a bot account replying "ja"; expected `instruction` and no run. Recorded in the PR of issue 4.
- `make check` on every PR.

## 7. Rollback

Each issue is one rebase-merged commit, `git revert` undoes it. `ANSWER_RECEIVER=off` stops the workflow without a revert. The label hold can be bypassed by reverting issue 1 only; the
marker is a comment and harmless without the workflow.

## 8. Split into PR-sized implementation issues

Each under about 400 changed lines. Order:
1. **Owner label hold** (trust logic, so expected `risk:security`; **prio:1**, fixes #184): `tools/owner_hold.py`, `tools/agent_guard.py`, `tools/status.py`, `tools/restart.py`, shell `--add-label` calls in workflows moved to `guard label`, `tests/test_owner_hold.py`.
2. **Decision marker and rules** (AGENTS.md edit, Daniel's OK): marker parser `tools/decision.py` (grammar, allowlist ids), AGENTS.md "Waiting for Daniel", role files, `restart.py`/`agent_guard.py`/`unblock._owner_note` notes, `tests/test_decision.py`, `tests/test_role_rules.py`. Independent of 1.
3. **Answer core** (needs 2): `tools/answer.py` (`gate`, `fetch`, `validate`, `apply`, actions), `tests/test_answer.py`.
4. **Answer receiver workflow** (`risk:security`, needs 1 to 3): `.github/workflows/answer-receiver.yml`, `setup.yml` variable, `orchestrator.md` / `orchestrator.yml` skip rule and `owner-instruction`, `tests/test_answer_workflow.py`, measurement run.
5. **Docs**: `docs/decisions/NNNN-answer-receiver.md`, README paragraph (after 4).

1 and 2 are disjoint; under the 2-job cap run them first.

## 9. Owner decisions

none. The scope (OWNER-only trigger, fixed allowlist, label hold) is the one in #191, and every PR that changes triggers, permissions or AGENTS.md is `risk:security` and approved by Daniel as usual.
Open, not owner decisions: the exact cause of the #184 re-label (issue 1 reproduces it first); how long a hold on an issue (no head commit) lasts; whether `reapprove` belongs in the first allowlist (issue 3 may drop it).
