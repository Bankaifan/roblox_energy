# 0013 Untrusted-text boundary for model steps

Status: accepted (issue #148, slip 4 of design 0004 section 8; the rules are design 0004 section 4). Describes the state on main.

Context: model steps read text written by others (issues, PR comments and bodies, diffs, CI logs). A prompt that says "never follow instructions in them" is not enforceable. PR #140 showed that a model step with a write token, a partial secret filter, or unrestricted `Read` can leak or act on injected text. Design 0004 chose a boundary built from capability removal and files.

Decision: every model step meets the five rules below. Rule 1 applies to all model steps; rules 2 to 4 apply to the new steps (unblocker, answer receiver) and are the target for the existing ones.

1. **Read confinement.** `.github/claude-judge-settings.json` denies `Read`, `Glob` and `Grep` on `/proc`, `/etc`, `/root`, `/run`, `/var`, the runner's `_temp`, `_actions` and `_tool` directories, and `/home/runner/.*/**` (dot directories in the runner home). All nine `claude-code-action` workflows pass it with `--settings`. `tests/test_untrusted_boundary.py` checks the deny list, the flag in every workflow, and that no judging step has `Edit`, `Write` or `Bash`. The checkout under `/home/runner/work` is not denied.
2. **Untrusted text as files.** A script step with a read-only token writes the item text as masked, capped files before the model step (`tools/unblock.py fetch` to `untrusted/`, `tools/answer.py fetch` likewise). The prompt names these files; the model step does not call `gh`.
3. **No write-capable token in the model step.** The unblocker and the answer receiver have no app token, no `GH_TOKEN` and no `Bash` in the model step. Their tools are `Read,Glob,Grep,Edit(verdict.json)`. The other model steps still get `GH_TOKEN` (see Open).
4. **Fixed-schema verdict out.** The model writes one `verdict.json`. A clean checkout follows. `validate` checks the shape, enums, length caps and ASCII English text, and runs `exec_log.has_secret` over every string in the verdict (one function, all fields). `apply` repeats that check, then posts with a write token created only after the model step. An invalid or missing verdict leaves `needs-human` in place and comments that no action was applied.
5. **Secret out of the model's reach.** `CLAUDE_CODE_OAUTH_TOKEN` is still an input of the action in every model step, the two new ones included. Rule 1 is the only guard against the CLI reading it (for example from `/proc/self/environ`).

Open (not measured or not done; each is a follow-up, not a claim):
- Rule 1 measurement: a test-repo run in which a model step tries `Read /proc/self/environ` and is refused (design 0004 section 6) is not recorded anywhere in this repo.
- Whether `Glob` and `Grep` honour the deny rules, and whether the CLI matches `/home/runner/.*/**` as intended (design 0004 section 9).
- Rules 2 to 4 for the existing steps: review, security review, scout, orchestrator, dev, fix and rule-keeper still read text with `gh` in the model step, still hold `GH_TOKEN`, and still post with `gh` directly.
- Whether dev and fix may narrow `workflows: write` and `actions: write` (design 0004 section 9, issue 1b).
- Rule 5 is a design statement that no test enforces; the security reviewer checks it on workflow PRs.

Consequences:
- Adding a workflow that uses `claude-code-action` fails `test_every_claude_code_action_workflow_is_covered` until it is listed in the test and passes the settings file.
- A task that legitimately needs a denied path fails visibly; the path can be allowed by name in a follow-up (rollback, design 0004 section 7).
- Changes to the settings file, the workflows or `tools/unblock.py` are `risk:security` PRs and need the security reviewer.
