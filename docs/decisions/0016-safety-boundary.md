# 0016 Safety boundary by token and checkout, with the command list kept as the default

Status: in effect for steps 1 to 4 and 6 (on main, see the step table). Step 5 is open. Owner decisions 1 and 2 of design 0017 are open. Issue #543, design `docs/design/0017-safety-boundary.md` (sections 4 and 8, step 7).

Context: the boundary of a model run was a list of allowed shell command forms per workflow plus prompt text ("one simple command per Bash call"). That list cost denied calls and failed runs (design 0017, section 1), and it limits wording, not capability: `Bash(python3:*)` and `Bash(make:*)` already run arbitrary code. The decision was: a developer or fix run should need no command list once the token and the checkout confine what it can do. Judging runs keep their read-only tools.

Decision:
1. Approach C of design 0017: the boundary of a dev or fix run is its token and its checkout, not its command list. The command list stays the default. A repo variable `DEV_SHELL=free` gives bare `Bash`; the `--settings` deny rules for `Read`, `Glob` and `Grep` stay in both cases (`docs/variables.md`).
2. Dev and fix model tokens lose `workflows` and `actions` write (step 3). A dev or fix run cannot push a change to a workflow file with its own token.
3. A second ruleset, `.github/rulesets/agent-refs.json`, confines branch creation, update and deletion to `agent/**` and the default branch, with the same bypass as `main.json`, plus tag creation (step 2). It applies only after Daniel imports it (owner decision 2).
4. Judging runs stay read-only and are pinned by test (step 4, `tests/test_judge_boundary.py`).
5. The orchestrator becomes comment-only (step 5). Not done: see the open list.
6. `DEV_SHELL=free` is built but off. Turning it on is owner decision 1.

Changed from the design: step 3 said a dev or fix push that changes `.github/workflows/` is refused by GitHub and reported to Daniel. That path is replaced. Workflow changes now travel as a patch file that a script step carries past the model token, and `workflow-apply` applies it after the security review (commits `f5bf195`, `9cb30c8`, `41a32eb`). Only `workflow-apply.yml` holds `permission-workflows`, and it refuses owner paths and any path outside `.github/workflows/` (`tools/workflow_patch.py`).

## Per-job table

Egress is open for every job: hosted runners have no egress filter, so the column lists what a job needs, not what is enforced. "Reach if compromised" is what injected text or a malicious dependency can do with the job's token and secrets. The "now" column is the state on main.

| Job | Model-job token (before -> now) | Secrets in the model job | Needs egress to | Reach if compromised |
|---|---|---|---|---|
| agent-dev, agent-fix | contents, workflows, pull-requests, issues, actions write -> contents, pull-requests, issues write (step 3); refs confined to `agent/**` once `agent-refs.json` is imported | OAuth token (action input), app token in env | api.anthropic.com, github.com, pypi.org (`EXTRA_INSTALL`) | OAuth token (by shell, which `DEV_SHELL=free` would allow, or by a pushed workflow; the pushed workflow route is closed by step 3); pushes to `agent/**`, comments |
| orchestrator | contents, pull-requests, issues write -> unchanged so far (step 5 open) | OAuth token, app token | api.anthropic.com, github.com | all issues, PR comments, labels; `contents` write (HANDOVER.md PRs) until step 5 |
| agent-review, agent-security-review | pull-requests write (approver app), checkout of `main` with `persist-credentials: false` | OAuth token, approver app token | api.anthropic.com, github.com | approve or request changes on any PR (the approval is still one of the required gates; CODEOWNERS and the checks stay) |
| unblocker, answer-receiver | read only in the model job, write token in the later script job | OAuth token only | api.anthropic.com, github.com | the OAuth token through `Read` outside the deny list (open, design 0004); the verdict file is validated before any write |
| scout | issues write, security alerts read | OAuth token, app token | api.anthropic.com, github.com | creates issues (labels `approved` are Daniel's; trust rules in `tools/trusted_issues.py`) |
| dispatcher (no model) | issues write | none | github.com | label and comment writes only |

Remaining gates for everything a free-shell run produces: required `validate`, `agent-smoke`, `risk` and `security-review` checks, the security reviewer on risk classes, CODEOWNERS review by Daniel on guarded paths, and one approval on `main` (`main.json`). These gates protect `main`. They do not protect a secret that leaves the runner during a run.

## Step status (design 0017, section 8)

| Step | Change | State on main |
|---|---|---|
| 1 | Denied calls per workflow in `run_stats` | merged (`dd87911`); the field name in a real execution file is still open |
| 2 | `.github/rulesets/agent-refs.json` | merged (`18558cd`); not imported (owner decision 2) |
| 3 | No `workflows` or `actions` write in the dev and fix model token | merged (`b3f2d7d`); workflow changes travel as a patch (see above) |
| 4 | Judging runs pinned read-only | merged (`10f2e16`, `tests/test_judge_boundary.py`) |
| 5 | Orchestrator comment-only tool set | open: the orchestrator still lists `Edit`, `Write`, `git` and `make`, and its token has `contents` write (`orchestrator.yml`) |
| 6 | `DEV_SHELL` switch | merged (`1640028`); off by default; owner decision 1 |

## Consequences

- The default is unchanged: with `DEV_SHELL` unset, dev and fix runs keep the command list. Nothing changes for Daniel until he sets the variable.
- A free shell can read the OAuth token (`cat /proc/self/environ` is not covered by the `Read` deny rules) and send it out (hosted runners have open egress). The worst case is the loss of the subscription token: cost and quota, not access to `main`. Design 0017 section 9 gives the German question for Daniel.
- Until `agent-refs.json` is imported, the app token can still write any branch. Step 3 and the rules on `main` remain the protection.
- The narrowed model token means a dev or fix run that changes a workflow file no longer pushes it directly; the change reaches `main` through the patch path and Daniel's review.

## Open

- Step 5 is not merged and has no date. Its tests (`tests/test_orchestrator_tools.py`) do not exist yet.
- The field name `permission_denials` in a real execution file is not verified (design 0017, section 6). Until it is, the denied-call count is a plan, not a measurement.
- Measurement run: whether `cat /proc/self/environ` shows the token in a model run on a test repo (design 0017, section 6). This decides whether owner decision 1 can be "ja" as the design describes it.
- Owner decision 1 (`DEV_SHELL=free`) and owner decision 2 (import of `agent-refs.json`) are Daniel's. This record does not claim either has happened.
