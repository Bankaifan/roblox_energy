# 0010 Large template sync and the security review

Issue: #352 (design study, no implementation in this PR). Seen in Bankaifan/ha-luxtronik-shi PR #111 (103 files, 8,696 diff lines, 412 KB).

## 1. Goal

A template sync PR of about 400 KB / 100 files gets a real `security-review` verdict (approve, or findings in the code) without a hand-made re-commit. That includes the bootstrap case: the sync itself brings the reviewer fix, but `agent-security-review.yml` runs via `workflow_run` and therefore uses the version on the downstream `main`, which is still the old one.

## 2. Current state (file references)

- `.github/workflows/agent-security-review.yml:82-99` stages the change as files (`.review/pr.diff`, `.review/files.txt`, `.review/files/<path>`, #267). `:116-117` tells the model to give no verdict line if it could not read the change. `:123` is `--max-turns 12`. `agent-review.yml:109-149` does the same staging with `--max-turns 12`.
- `tools/ci/post_verdict.py:47` turns a `changes` verdict without a reason into no verdict. The `Publish status` step (`tools/ci/risk.py verdict`) then fails the required status, the run can be re-run, and the one-review-per-commit check (`:73-78` of the workflow) only counts posted verdicts. So the template already has the "no verdict instead of `changes`" mode; PR #111 saw the old reviewer, which says "Read the change with `gh pr diff`" and posts `changes`.
- `tools/ci/risk.py:29-32` knows the paths that matter: `SECURITY_FILES` (rulesets, CODEOWNERS, trust and guard tools, `risk.py`, `risk.yml`) and `INFRA_PATHS` (`.github/`, `.agents/`, `tools/`, `AGENTS.md`, `CLAUDE.md`, `Makefile`, `.claude/`, `.mcp.json`). `tests/` and `docs/` are in neither list.
- `tools/template_sync.py:75-85` renders the sync issue as one flat list (`Clean`, `Overridden`) plus `Template-Sync: <sha>`. `tools/managed_guard.py:49-50`: a PR may change managed paths only if its title starts with `Template sync` and it changes `.agents/template.json`.
- `.agents/roles/developer.md:26-28`: a sync is "one PR with `Closes #<sync issue>`", and the same file (line 19) already says partial work uses `Refs`. The "one PR with Closes" rule is in the developer role, not in `AGENTS.md` (the issue says `AGENTS.md`; `AGENTS.md` has no sync rule and needs no change).
- Measured in the issue: PR #97 had 525 diff lines, PR #111 has 8,696. Tests are 173 KB of the 412 KB, tools 148 KB, workflows/ruleset/`AGENTS.md`/Makefile 73 KB, roles 18 KB.
- Open: which 7 calls were denied in run 42857022978 (`permission_denials_count: 7`, `show_full_output: false`). Not guessed here. `post_verdict.py` prints denied calls on a no-verdict run in the current template; whether the downstream log would show them with the new script is to be measured.

## 3. Options with trade-offs

Bootstrap:
- A. Split-first sync. Part 1 ports only the reviewer pipeline (the two review workflows, `post_verdict.py`, `risk.py`, their tests) in a small PR; part 2 is the rest once part 1 is on `main`. The old reviewer judges a small diff and can read it. Chosen.
- B. Daniel merges over a red `security-review`. Works once, needs an admin bypass of the ruleset, weakens the gate it is meant to test. Rejected.
- C. Run the reviewer from the PR head. Executes untrusted PR content in a `workflow_run` job with an app token. Rejected (design 0004 boundary).
- D. Reusable workflow pinned in the template repo. Removes the bootstrap, but is a new trust edge between repos and a rewrite of both workflows. Out of scope.

Size:
- E. Stage only the security-relevant paths as the diff to read: everything `risk.py` classes as infra or security, minus `tests/`, `docs/` and the like. Tests and other paths are listed with `+added/-removed` counts in `.review/skipped.txt`, so the reviewer sees what was left out and can open `.review/files/<path>` on demand. Chosen.
- F. Scale `--max-turns` with the diff size. Chosen as a bounded add-on: `12 + ceil(diff_lines / 1500)`, capped at 30, computed by the staging script and passed as a number (not model text). On its own it keeps the old cost per line and still reads test churn.
- G. Split the review itself into several runs. More statuses, more quota. Rejected.

Tests: a changed test file is not security surface. A deleted test or a weakened assertion is "a check gets weaker", so deleted files and tests of `SECURITY_FILES` tools stay in the staged diff; other test changes are only listed with counts.

Failure mode: already covered in the template (section 2). Downstream gets it with part 1.

## 4. Chosen approach

A for the bootstrap, E plus a capped F for size.

### 4.1 Staging script
New `tools/ci/stage_review.py`: reads the full diff from stdin and the file list, writes `.review/pr.diff` (security-relevant files only), `.review/skipped.txt` (path, status, +/- counts), `.review/files/<path>` for the relevant files, and prints `turns=<n>`. Relevance reuses `risk.py` constants (imported, not copied). Fail-open: if nothing is relevant or the script errors, the full diff is staged as today. Both review workflows call it in place of their inline loop.

### 4.2 Workflow wiring
`agent-security-review.yml`: the stage step calls the script and exports `turns`; `--max-turns ${{ steps.stage.outputs.turns }}`; the prompt names `.review/skipped.txt`. `agent-review.yml` keeps its own staging for now (the normal reviewer reads code, not tests-only churn; same change later if measured to be needed, open).

### 4.3 Split sync
- `tools/template_sync.py` renders `## Part 1: reviewer pipeline` (a fixed `REVIEWER_FIRST` list: `agent-security-review.yml`, `agent-review.yml`, `tools/ci/post_verdict.py`, `tools/ci/risk.py`, `tools/ci/stage_review.py` and their `tests/`) before `## Part 2: rest`, only when part 1 files are in the change set and the change is larger than 40 files; otherwise the issue is unchanged.
- `managed_guard.is_sync_pr` also accepts a title starting `Template sync <sha> part 1` without a change to `.agents/template.json`. Part 1 does not touch `synced_sha` (the rest is still pending). The final part sets it and uses `Closes`.
- `developer.md`: for a part 1 task port only the Part 1 list, PR body `Refs #<sync issue>`, title `Template sync <sha> part 1`; the sync issue stays open and part 2 follows as a normal re-dispatch after the merge (a `Refs` PR leaves the issue open, existing rule in line 19). Open: confirm the orchestrator re-dispatches an open `agent:dev` issue after a merged `Refs` PR.

## 5. Migration and compatibility

Additive. Downstream repos that are already far behind do part 1 first on their next sync. Existing sync issues are re-rendered by the daily sync run (it edits the open issue). A small sync (at most 40 files) is untouched. Template repo itself: the script and the workflow change apply directly.

## 6. Test and verification plan

All fail on today's code (no script, no part split, no part-1 exemption):
- `tests/test_stage_review.py`: a diff with workflow, tool and test files stages the first two and lists the test in `skipped.txt`; a deleted test and a test of a `SECURITY_FILES` tool stay in the diff; `turns` is 12 for a small diff, grows per 1500 lines and is capped at 30; empty relevant set and a script error fall back to the full diff; a path with `..` or a leading `/` is skipped.
- `tests/test_agent_review_workflow.py` / a new security-review workflow test: `--max-turns` comes from the stage step output, which is a number; the stage step runs before the model step; no new secret reaches a step that runs model output.
- `tests/test_template_sync.py`: a 100-file change set with reviewer files renders both parts; a 10-file change set renders the old flat list; `Template-Sync:` line unchanged.
- `tests/test_managed_guard.py`: a `Template sync abc1234 part 1` PR without `.agents/template.json` is exempt; a PR with another title is not.
- Measurement on the real repo: re-run the stage step against PR #111's diff (saved with `gh pr diff 111 -R Bankaifan/ha-luxtronik-shi`) and record `pr.diff` lines and `turns` (open: expected to drop from 8,696 lines to the infra/tools share). Then one throw-away large sync on a scratch downstream must reach a verdict. Recorded in the PR bodies.
- `make check` on every PR.

## 7. Rollback

Each implementation PR is one rebase-merged commit; revert it. The workflow keeps working with the inline staging if the script PR is reverted last. The part 1 list is a constant; emptying it restores the flat issue.

## 8. Split into PR-sized implementation issues

Each under about 400 changed lines, disjoint files, in this order:
1. **Staging script**: `tools/ci/stage_review.py`, `tests/test_stage_review.py`. Nothing calls it yet.
2. **Wire it in**: `.github/workflows/agent-security-review.yml`, `tests/test_security_review_workflow.py`. `risk:security` (workflow with tokens). Needs 1.
3. **Part split in the sync issue**: `tools/template_sync.py`, `tests/test_template_sync.py`. Independent of 1 and 2.
4. **Part 1 exemption in the guard**: `tools/managed_guard.py`, `tests/test_managed_guard.py`. Independent; needed before a part 1 PR can pass `validate`.
5. **Role and docs**: `.agents/roles/developer.md` (part 1 rule, `Refs` for it), `docs/decisions/0007-template-sync.md` (one paragraph), `CHANGELOG.md` if present. `risk:infra`. Last.

Order: 1, 3, 4 together (disjoint), then 2, then 5.

## 9. Owner decisions

none
