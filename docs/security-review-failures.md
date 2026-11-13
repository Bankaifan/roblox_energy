# agent-security-review failures

Note for issue #519 (duplicate signature of #520). It records what the repo shows about the recurring failure of
`.github/workflows/agent-security-review.yml`, job `security-review`, and what is still open. It changes no gate;
the workflow fix belongs to #520.

## The failure

- Failing step: the `anthropics/claude-code-action` step (step id `claude`), pinned to
  `61a9c274fa7110a66dfafc1bbbced03833eb25fe` (v1.0.269). Earlier steps are separate named steps.
- #519 counts 4 failures; the comments list the runs 43135819883, 43162929000, 43164121088, 43382699542,
  43382728254 and 43457228351. The failure watch closed the issue after some green runs, and it came back after each.
- The issue comments name no fix commit ("after the fix in none"), so the repairs cannot be matched to the runs.

## What the workflow does (repo evidence)

- Trigger: `workflow_run` of `validate`, only when it succeeded, the head branch starts with `agent/` and the head
  repository is this repository.
- Token: `contents: read`, `pull-requests: read` at top level; the job adds `statuses: write`. The step
  `actions/create-github-app-token` mints an app token from `APPROVER_CLIENT_ID` and `secrets.APPROVER_APP_KEY`.
- Checkout: the default branch, never the PR head.
- Claude step inputs: `secrets.CLAUDE_CODE_OAUTH_TOKEN`, model `sonnet`, `--max-turns` from
  `tools/ci/stage_review.py` (`min(30, 12 + ceil(diff lines / 1500))`), `--settings .github/claude-judge-settings.json`
  (denies reads of `/proc`, `/etc`, `/root`, `/run`, `/var` and the runner's temp, action and tool directories),
  and `--allowedTools` limited to `Read`, `Glob`, `Grep` and `gh pr view`, `gh pr diff`, `gh issue view`.

## Fail-closed behaviour (repo evidence)

- `Post the verdict` runs with `continue-on-error: true` whenever the claude step was not skipped. It posts only a
  first line `security-review: approve|changes <sha>` from the final reply.
- `Publish status security-review` runs as well. `tools/ci/risk.py` sets the status to failure with
  "security reviewer left no verdict" when no verdict exists, so a failed claude step does not pass silently.

## Causes ruled out from repo files

- The app-token, checkout, PR-lookup and staging steps are separate named steps before the claude step; the failure
  is reported in the claude step, so these did not fail in the reported runs.
- A denied tool call is not a stop by itself: the prompt tells the model to continue, and the allow list is plain.

## Open questions (run logs not read here)

1. Which error the action reports in the failing step: turn budget exhausted, OAuth token rejected or expired, an
   action-internal error, or the 30-minute job timeout?
2. Is `CLAUDE_CODE_OAUTH_TOKEN` set and valid? The secret is not visible in the repo.
3. Does the failure follow the diff size (the turn budget) or particular PRs?
4. Did all four failing runs use the same action pin, or did a pin change in between?

Next step: read the failed run logs with `python3 tools/run_log.py <run id>` (see #520). This note did not use
`gh run view` or `gh api`, as the slip required.
