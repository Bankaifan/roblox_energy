# 0014 Template sync applied by a script, a model only merges real conflicts

Issue: #414 (design study, no implementation in this PR). Extends 0011 (version gate) and 0010 (part 1 / part 2 split).

## 1. Goal

A template sync is ported by the developer model today. It failed twice in ha-luxtronik-shi (#134, #135) and needed four owner
issues and a manual port. Causes: (a) the model permission prompt denies writing `.github/claude-judge-settings.json`;
(b) `.template/` exists only for runs on the sync issue itself; (c) template-only tests and checks fail downstream
(`tests/test_check_version_bump.py` needs `VERSION`, `tests/test_managed_guard.py` needs `.agents/managed.json`);
(d) one "JA" retriggered the same denied run three times.

Goal: a script copies and merges the files and opens ONE PR. A model runs only for a file with real merge conflicts.

## 2. Current state (file references)

- `.github/workflows/template-sync.yml`: daily `schedule` and `workflow_dispatch` (`force`), `permissions: contents: read`, author
  app token with `permission-issues: write` only, no model. It calls `template_sync.main()`.
- `tools/template_sync.py`: `main()` reads `.agents/template.json`, gates on `needs_sync()` (`x` of `VERSION`), compares
  `synced_sha...main` through the compare API (`changed_files()`), splits clean/overridden (`split_overrides()`), and only creates or
  edits the issue `Template sync <sha>` (`render_issue()`, label `agent:dev`). `bump()` already rewrites `synced_sha` and
  `synced_version` in the JSON text. `read_template_file()` reads one file at a ref through the contents API. Nothing is copied.
- `.agents/roles/developer.md` (last two bullets about template sync): the developer ports `clean` files, ports `overridden` files by
  hand, sets `synced_sha`. `.template/` is a tarball of the template at the SHA, fetched by `agent-dev.yml:154-171` (decided by
  `tools/ci/template_fetch.py`) and kept out of git through `.git/info/exclude`; it exists only for the sync issue itself.
- `.agents/managed.json` lists the managed prefixes of the template. Its owner is `tools/managed_guard.py`.
  `Makefile:15-17` runs `check_version_bump.py` (only with `PR_BASE_REF`) and `managed_guard.py check`; both are template concerns.
  `tests/conftest.py` registers only the `slow` marker.
- Every other write workflow takes `permission-contents: write` from the author app (`agent-dev.yml:132`, `train.yml:41`, ...).
  `template-sync.yml` has none today.
- `tools/ci/risk.py` classifies a PR by its changed paths (`SECURITY_FILES`, CODEOWNERS owner paths); `.github/CODEOWNERS` makes
  Daniel a required reviewer for his paths. This gate works on any PR, whoever opened it.

## 3. Options with trade-offs

Who applies a clean file:
- A. Keep the model, fix the permission prompt. A prompt allow for a protected path is a permission change and still leaves (b)-(d).
  The model adds cost and risk for a pure file copy. Rejected.
- B. A script step in `template-sync.yml`, author app token, no model. Deterministic, testable, the protected-path gate is the
  normal PR gate. Chosen.

How to merge an `overridden` file (downstream edited it on purpose, `.agents/template.json` `overrides`):
- C. Always send it to the model. Works, but most overrides do not collide with the template change. Rejected as default.
- D. `git merge-file -p <ours> <base> <theirs>` (ours = downstream file, base = template at `synced_sha`, theirs = template at the
  target SHA). Exit 0 = clean merge, goes into the PR. Exit > 0 = conflict markers, goes to the developer. Exit < 0 = error, treated
  as a conflict. Chosen. A file added in the template that also exists downstream has no base: treated as a conflict.

Where the template files come from:
- E. A second checkout of the template. Needs `contents: read` on the template for the app (already installed, 0001) and a
  clone; the workflow tree would then hold template code next to downstream code.
- F. The contents API per file at the SHA (`read_template_file()`, exists). No clone, no extra permission, binary-safe through the
  raw media type. About one call per changed file, the compare list is already capped at 300. Chosen.

How the developer gets the three versions (fixes (b)):
- G. Keep `.template/` as a checkout on the sync issue only. A follow-up issue has none. Rejected.
- H. `tools/template_sync.py materialize <sha>` writes `<path>.ours`, `<path>.base`, `<path>.theirs` for every conflicted file into
  `.template/` (excluded through `.git/info/exclude` as today, never committed). `agent-dev.yml` runs it for any issue with a
  `Template-Sync:` line, replacing the tarball step. Chosen.

Template-only tests and checks (fixes (c)):
- I. A path list in `.agents/managed.json`. One more list to keep in step with the test files. Rejected.
- J. `@pytest.mark.template_only`, registered in `tests/conftest.py`, which skips marked tests when `.agents/template.json` exists
  (a downstream repo; the template has no such file, 0011 section 2). The two template-only make steps skip on the same
  condition. Chosen: the mark sits on the test, `conftest.py` is managed and syncs by itself.

Protected paths (fixes (a)):
- K. Allow-list them for the model. Rejected (permission change, still model-bound).
- L. No special case: the sync PR is opened by the script, so no prompt exists; `risk.py` labels it, the security reviewer runs, and
  CODEOWNERS requires Daniel. Chosen. A test proves a sync PR touching `.github/claude-judge-settings.json` gets the gate.

## 4. Chosen approach

B + D + F + H + J + L.

### 4.1 `tools/template_sync.py apply`

New module `tools/template_apply.py` holds the logic (pure functions plus thin git/gh calls); `template_sync.py` gains the `apply`
and `materialize` sub-commands and calls it. Flow, after the existing version gate and compare:

1. `plan(changed, overrides)` (existing `split_overrides`) gives clean and overridden files.
2. Clean `added`/`modified`: write the template file at the target SHA (a path outside the managed prefixes, an absolute path, or a
   `..` segment is refused and fails the run). Clean `removed` and `renamed-from`: delete the file.
3. Overridden: `git merge-file` on temp copies; clean result is written, a conflict leaves the working tree file untouched and is
   recorded as `conflicted`.
4. New managed prefixes in the template `.agents/managed.json` are added to the downstream `managed` list (union, never removed) and
   named in the PR body.
5. `bump()` sets `synced_sha` and `synced_version`, but only when there are no conflicts (see 4.3).
6. Commit on branch `template-sync/<version>` as Daniel (AGENTS.md), one commit, no trailer; `make check` runs (4.2); one PR
   (ASCII), body at most 5 lines, `Closes #<n>` or `Refs #<n>` (4.3). Title: `Template sync <version>` without conflicts; `Template
   sync <sha> part 1` with conflicts (4.3). The no-conflict title passes `managed_guard.is_sync_pr` only because the `synced_sha`
   bump puts `.agents/template.json` in the diff; the conflict title is the part-1 shape the guard accepts by title alone. A run on
   an existing open PR for the same branch force-pushes the branch (own branch, allowed) and edits that PR; it never opens a second one.

### 4.2 Workflow and token handling

`template-sync.yml` becomes two jobs. The job that holds the write token runs no file that `apply` wrote, so a template change
cannot reach the token:
1. Job `build`: the app token has `contents: read` and is passed only as `GH_TOKEN` to the `apply` step (template reads). The job
   checks out the base SHA into `base/` (`persist-credentials: false`) and runs `apply` from `base/tools/`, the downstream scripts at
   the base SHA. `apply` writes the template files and the commit into `work/`, a second checkout, never into `base/`.
2. Still in `build`: `make check` in `work/` with no token in the environment (`persist-credentials: false`, same tool setup as
   `validate.yml`). A red result stops the run before any push; the script then opens the issue (4.3) so the developer fixes the cause.
3. Still in `build`: the artifact holds `sync.patch` (`git format-patch` of the one commit) and `pr-body.md`. Both are data.
4. Job `publish` (`needs: build`): the app token has `contents: write` and `pull-requests: write`. It checks out the base SHA, downloads
   the artifact, runs `git am --no-verify sync.patch` on that checkout, `git push` of the branch, then `gh pr create --body-file
   pr-body.md` or `gh pr edit`. No step in `publish` runs a script from the artifact or from `work/`; the only programs it starts are
   `git` and `gh`.

Permissions: job `permissions` stay `contents: read`; the token widening is only in `publish`: `permission-contents: write` and
`permission-pull-requests: write` (plus `permission-issues: write`, already there). It is the same pair that `agent-dev.yml` already
requests, no new secret, no new trigger (`repository_dispatch` stays absent, 0011). A push that changes `.github/workflows/`
additionally needs the app permission `workflows: write`; see Owner decisions. The branch name, version text and file paths are
data: validated (`read_version`, a path allow-list), never put into a `run:` expression.

### 4.3 Conflicts go to the developer

- No conflict: one PR, `Closes` the sync issue if one exists, no issue is created, no model runs (acceptance 2).
- With conflicts: the PR holds everything else and is a part-1 PR (0010): title `Template sync <sha> part 1` (the shape
  `managed_guard.is_sync_pr` accepts without `.agents/template.json` in the diff; without it `managed_guard check` fails on the
  managed files and no PR is opened), body `Refs`, `synced_sha` NOT set. The issue
  `Template sync <sha>` is created or edited, carries `agent:dev`, lists only the conflicted files and the line `Template-Sync: <sha>`.
  The developer run first calls `materialize`, merges each file by hand keeping the recorded intent, sets `synced_sha`/`synced_version`
  and opens the final PR with `Closes` (the 0010 part 2 rule). The developer role loses all other porting steps.
- `make check` red: no PR, the issue carries `agent:dev` and the failing step name.
- The PR body names every file the developer must merge (acceptance 1).

### 4.4 Template-only tests

`tests/test_check_version_bump.py` and `tests/test_managed_guard.py` get `pytestmark = pytest.mark.template_only`. `tests/conftest.py` registers the marker and skips such tests when
`.agents/template.json` exists. `check_version_bump.py` exits 0 with a one-line `skipped` message under the same condition: downstream
it fails on every PR with `VERSION is missing` (`errors()`, the file exists only in the template). `managed_guard.py check` stays as it
is: `cmd_check` already skips without `.agents/template.json` and does its work only downstream, where `pr_errors` blocks PRs that edit
managed paths; the sync PR guard in section 6 depends on it. Of failure cause (c) only `tests/test_managed_guard.py` needs
`.agents/managed.json`, the command does not. The marked tests still run in the template repo, so nothing is lost there.

## 5. Migration and compatibility

- Additive for the template. Downstream repos get the new workflow with the first sync, which is applied by the old
  (model) path once: the new `template-sync.yml` is itself a clean managed file. Later syncs are scripted.
- The existing issue flow stays for conflicts and for `TEMPLATE_SYNC_MODE`/`force` (0011). `TEMPLATE_SYNC=off` still stops everything;
  a new `TEMPLATE_SYNC_APPLY=off` (default `on`, `docs/variables.md` row, `(vars.TEMPLATE_SYNC_APPLY || 'on') != 'off'`) returns to
  issue-only behaviour.
- Overrides keep their format. A repo without the app permission from Owner decision 1 gets the old issue flow (the publish step
  fails soft: it creates the issue, no PR).
- Downstream `.agents/template.json` needs no change; `managed` grows by union only.

## 6. Test and verification plan

All of these fail on today's code (no `apply`, no marker, no merge):
- `tests/test_template_apply.py`: `plan` splits as `split_overrides`; the path guard refuses `../x`, `/etc/x`, a path outside `managed`;
  `three_way` returns `clean` for non-overlapping edits and `conflict` for the same line changed, never writes markers into the
  result path; a removed clean file is deleted; a renamed file moves.
- Fixture repo (acceptance 1): 3 clean, 1 new, 1 overridden without conflict, 1 overridden with conflict. `apply` produces a commit
  with five files, `synced_sha` unchanged, a PR body naming the sixth file; `materialize` writes the three versions of that file.
- Fixture with the conflict file removed: `synced_sha` and `synced_version` are set, body has `Closes`.
- Acceptance 2: a fixture whose change touches `.github/claude-judge-settings.json` runs `apply` with no model call (the test fails
  if any `claude` or `anthropic` command is invoked) and `risk.classify` on the diff returns a gated level.
- Acceptance 3: a fresh downstream fixture (`.agents/template.json` present, no `VERSION`, no `.agents/managed.json`) copied from the
  template at the target SHA runs `make check` green after `apply`; the same fixture without the marker and the skips is red.
- `tests/test_template_sync_workflow.py` (extended): permissions are `contents: read` at job level, the app token requests exactly
  contents, pull-requests and issues write, and only in `publish`; the `make check` step has no `GH_TOKEN`; `publish` needs `build`;
  no step in `publish` invokes `python`, `make`, a path under `tools/` or `work/`, or a file from the artifact (only `git` and `gh`);
  `apply` runs from `base/tools/`, not `work/`; no `repository_dispatch`; no template-derived value in a `run:` expression;
  actionlint and zizmor stay green. The test fails on a workflow where `publish` runs `python3 tools/template_sync.py`.
- Sync PR guard (`tests/test_template_sync_apply.py`): `managed_guard.pr_errors` on the conflict PR (title `Template sync <sha> part 1`,
  managed files, no `.agents/template.json`) returns `[]`; the same files under title `Template sync <version>` without the config
  change return the protected-path errors. Fails if the conflict title shape is not accepted.
- Marker test: with `.agents/template.json` present, a `template_only` test is skipped; absent, it runs.
- Guard stays on: with `.agents/template.json` present, `managed_guard.py check` still returns the `pr_errors` of a PR that edits a
  managed path (fails if the command is skipped downstream).
- Before rollout: scratch downstream repo, dispatch with `force`, expect one PR and no model run. Not run yet (open).

## 7. Rollback

Set `TEMPLATE_SYNC_APPLY=off` for the old issue flow, or `TEMPLATE_SYNC=off` to stop. The marker and skips are inert without
`.agents/template.json`. Every implementation PR is one rebase-merged commit and can be reverted. The app permissions are removed by
Daniel in the app settings; without them the publish step falls back to the issue.

## 8. Split into PR-sized implementation issues

Each issue carries `Design: docs/design/0014-template-sync-by-script.md`, at most ~400 changed lines.

| Step | Title | Files | Depends on |
|---|---|---|---|
| 1 | Apply core: plan, path guard, three-way merge, write/delete | `tools/template_apply.py`, `tests/test_template_apply.py` | - |
| 2 | Template-only marker and skips (acceptance 3) | `tests/conftest.py`, `tests/test_conftest_markers.py`, `tools/check/check_version_bump.py`, `tests/test_check_version_bump.py`, `tests/test_managed_guard.py` | - |
| 3 | `apply` and `materialize` commands, PR body, conflict split (acceptance 1) | `tools/template_sync.py`, `tests/test_template_sync.py`, `tests/test_template_sync_apply.py` | 1 |
| 4 | Workflow: three steps, token split, `TEMPLATE_SYNC_APPLY` (acceptance 2, risk:security) | `.github/workflows/template-sync.yml`, `tests/test_template_sync_workflow.py`, `docs/variables.md`, `tools/check/check_var_defaults.py` (lists `TEMPLATE_SYNC_APPLY`) | 3 |
| 5 | Developer run materializes for any `Template-Sync:` issue | `.github/workflows/agent-dev.yml`, `tools/ci/template_fetch.py`, its test and the agent-dev workflow test | 3 |
| 6 | Downstream fixture end to end (acceptance 1-3) | `tests/test_template_sync_e2e.py` | 2, 3 |
| 7 | Docs and developer role: sync is scripted, conflicts only | `.agents/roles/developer.md`, `docs/decisions/0007-template-sync.md`, `README.md`, `README.de.md` | 4, 5 |

Steps 1 and 2 are independent with disjoint files; 4, 5 and 6 are disjoint and run in parallel after 3 (6 also after 2). Steps 2, 4, 5
change managed paths: each bumps `VERSION` (`x` for 4 and 5, `y` for the rest). Steps 4 and 5 are `risk:security` (workflows with
tokens). Steps 2 and 4 touch `tools/check/`, a code-owner path.

## 9. Owner decisions

1. **App permissions and write access for the sync job.** The sync job gets `contents: write` and `pull-requests: write` on the
   downstream repo (author app token, never the model). To push a sync that changes `.github/workflows/` the author app also needs
   the app permission `workflows: write`; without it those syncs fall back to the issue flow. This is a permission change (AGENTS.md
   limit 2): yes enables scripted syncs, no keeps the model port with its denial problem. Worst case: a compromised template pushes
   a workflow change to a downstream branch; it still cannot merge without the normal gate (CODEOWNERS, security reviewer).
   The `make check` step runs in `build` without the token, and `publish` runs no code from the tree, to keep that case small.
