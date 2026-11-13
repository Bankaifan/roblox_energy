# 0011 Answer receiver

Status: accepted (issue #191; design 0006, built in five parts, on the untrusted-text boundary of design 0004).

Context: every note that parks work with Daniel ends with a yes/no question, but nothing read his answer. Only `/dev` on an issue reacted to comments, so a reply like "ja" on a `needs-human` item had no effect. Removing `needs-human` or `review:N` by hand also did not stick: the next status or review run set the label again (issue #184).

Decision: `.github/workflows/answer-receiver.yml` starts on an `issue_comment` and acts only on an OWNER comment (default Bankaifan, `vars.OWNER`) on an item that has `needs-human`. `tools/answer.py gate` re-checks this on live data (open, label still set, the comment is the newest OWNER comment, no receiver confirmation yet). A 45 s sleep debounces bursts; the concurrency group per item never cancels a run that is applying. `fetch` writes the note, Daniel's comments and the thread as masked, capped files. A sonnet step with no app token, no Bash and no GitHub write scope reads them and writes one `verdict.json` (intent `yes`, `no`, `option`, `instruction` or `unclear`, with an exact quote as evidence). After a clean checkout of the default branch, `validate` checks the verdict and `apply` runs the action in a write token that is created only after the model step.

The action comes from a decision marker, never from the model. The party that parks an item writes `<!-- decision: yes=<action> no=<action> -->` in the same comment as the German note. Only the newest marker from the author app, the approver app or OWNER counts (checked by login). Actions are allowlisted in `tools/decision.py` and `tools/answer.py`: `close-pr`, `close-issue`, `restart-issue`, `restart-recut`, `fix-pr`, `reapprove` (keeps its own refusals), `drop-block`, and `label:<name>` for `prio:1..3`, `approved`, `auto-ok`, `agent:dev`, `agent:review`. Merge, push, tags, workflow, ruleset, permission and secret edits, and approval of a `risk:security` PR are never on the list. A free instruction ("ja, aber ohne X") is not run as a marker action; the script posts a hand-over comment `<!-- owner-instruction comment=<id> -->` and the orchestrator acts on it only when the author app wrote it and the named comment is by OWNER. Items without a marker can only drop the block or pass an instruction; they are never closed or restarted.

An applied action removes `needs-human` and the owner review request, then posts one German confirmation built from a fixed template per action. The model writes no German text. `unclear` posts one German follow-up question and keeps the block. A failed run comments that no action was applied and that `needs-human` stays, with the run URL.

Label hold: `tools/owner_hold.py` reads the label timeline. If OWNER's `unlabeled` is the latest event for `needs-human` or `review:N`, `agent_guard.add_labels`, `count_round`, `status` and `restart` do not set the label again for that head. A new commit on a PR ends the hold; a bot removal never holds. Lookup failures fail open, so the guard never blocks the pipeline.

Limits (AGENTS.md "Limits"): no secret is written or logged; no merge, push or tag; no production change; the receiver grants no permission and edits no workflow. Changes to the receiver, the marker or AGENTS.md are security-class PRs; Daniel approves those touching his CODEOWNERS paths.

Consequences:
- A reply by Daniel is a yes/no decision for the marker's actions only; anything else goes back to him as a question.
- The orchestrator skips an item whose newest comment is a receiver marker newer than its `needs-human` event.
- Daniel's removal of `needs-human` or `review:N` is respected until the next commit (PRs) or his next label event (issues).
- Kill switch: repo variable `ANSWER_RECEIVER=off` disables the workflow without a revert. `setup` reports the variable.
- Open: the measurement run from design 0006 section 6 (Daniel's "ja, aber ohne X" and a bot's "ja" in a test repo) is not recorded in this repo.
