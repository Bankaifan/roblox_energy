# 0011 Automatic template sync with a version number

Issue: #386 (design study, no implementation in this PR). Builds on 0001-template-sync.md and 0010-large-sync-security-review.md.

## 1. Goal

Downstream repos start a template sync on their own when the template has a change that matters, and stay quiet for small
fixes. A two-part version `x.y` tells them which is which: `x` = must-have updates (functional or problem-solving changes),
`y` = small fixes and documentation (no reason to sync). Setting this up in a downstream repo must be short and documented.

## 2. Current state (file references)

- `.github/workflows/template-sync.yml` runs on a weekly `schedule` (`cron: "41 6 * * 1"`) and `workflow_dispatch`, with
  `permissions: contents: read`, the author app token (`permission-issues: write`), no model. It runs `tools/template_sync.py`.
- `tools/template_sync.py` compares `synced_sha...main` of the template (0001, option A), filters by `managed`, and opens or
  edits the one `Template sync <sha>` issue. It reports every managed change, whatever its size, so a typo fix in a role file
  produces a sync issue and a Daniel-gated PR.
- `.agents/template.json` (downstream only, not in this repo) holds `template`, `synced_sha`, `managed`, `overrides`.
- There is no `VERSION` file and no `CHANGELOG.md` in this repo (checked with Glob). `developer.md` says "Update CHANGELOG.md if present".
- `tools/check/check_version.py` already runs in `make check` (`Makefile:14`) and is tested in `tests/test_check_version.py`. It is
  skipped without a `VERSION` file or `CHANGELOG.md`. With a `VERSION` it reads the first `x.y.z` (default regex `\d+\.\d+\.\d+`,
  then a full match) and requires `## [Unreleased]` and `## [<version>]` in `CHANGELOG.md`. Today a `VERSION` of `1.0` fails it
  (`no version found`), so adding `VERSION` in issue 2 would turn `make check` red without a change to this check.
- The template has no managed list of its own: `.agents/template.json` (with `managed`) exists only downstream (see 4.1c).
- The template cannot write into downstream repos: no workflow here holds a token for them. Downstream repos already read the
  template with the author app (0001, owner decision 1).
- Untrusted-text boundary: design 0004. The sync issue is trusted because the app wrote it from the template's own repo (0001, 4.4).

## 3. Options with trade-offs

Version scheme:
- A. `VERSION` file at the template root, one line `x.y`, bumped in the same PR as the change. Readable with one contents API
  call at any SHA. Chosen.
- B. Git tags or GitHub releases. Tags by hand are forbidden (AGENTS.md limit 3), releases are irreversible (limit 2). Rejected.
- C. Derive the level from the diff (managed paths changed means `x`). Cannot tell a docs fix in `AGENTS.md` from a real change. Rejected.

Trigger (how a downstream repo learns that `x` changed):
- D. **Scheduled poll** in the downstream repo. The existing `template-sync.yml` runs daily, reads `VERSION` of the template
  `main`, compares `x` with the `x` recorded in `.agents/template.json`, and only then runs the normal compare and issue step.
  No new token, no new permission, no secret in the template. Latency is at most one day.
- E. `repository_dispatch` from the template to each downstream repo. The template would need a token with write access to every
  downstream repo and a list of them. A leaked token starts workflows everywhere. New permission and a new trust edge. Rejected.
- F. A `release` event. A repo cannot subscribe to another repo's events, so it needs E or D anyway, and releases are
  irreversible (see B). Rejected.
- G. A downstream `workflow_dispatch` by hand. Stays available as the manual override for a `y`-only sync.

Who bumps and how the level is decided:
- H. The developer bumps `VERSION` in the PR that changes managed paths and writes a `CHANGELOG.md` entry; the level comes from the
  slip (issue label `sync:must` means `x`, otherwise `y`). A check fails a PR that changes managed paths without changing
  `VERSION`. Chosen: one place, enforced, reviewable in the PR.
- I. The orchestrator bumps after merge. Needs a push to `main` (limit 3). Rejected.

## 4. Chosen approach

A + D (+ G as manual path) + H.

### 4.1 Version and changelog

- `VERSION` at the root: exactly `x.y`, both non-negative integers, no `v`, regex `^[0-9]+\.[0-9]+$`. Start at `1.0`.
- `x` bump: a managed change a downstream repo should take (new or fixed workflow, tool, role or rule; security fixes). `y` bump:
  small fixes, wording, docs. Bumping `x` resets `y` to `0`.
- `CHANGELOG.md` (new, template repo): keeps the `## [Unreleased]` section that `check_version.py` requires, plus one
  `## [x.y] - YYYY-MM-DD` heading per version, newest first (the form the existing check matches). An `x` entry has a line
  `Sync: <why a downstream repo should take this>`. The sync issue quotes these lines.
- Checks (issue 2):
  - a. `tools/check/check_version.py` is **extended, not replaced**: its version pattern accepts `x.y` as well as `x.y.z` (default
    regex `\d+\.\d+(?:\.\d+)?`, still a full match), so downstream projects with `x.y.z` keep working. The CHANGELOG contract does
    not change. `tests/test_check_version.py` keeps its cases and gains: `1.0` with `## [1.0]` passes; `1.0` without that section
    fails; `v1.0` fails (the regex rejects it).
  - b. New `tools/check/check_version_bump.py`, run by a `Makefile` line after `check_version.py`, only when `PR_BASE_REF` is set
    (same pattern as `check_test_evidence.py`). It takes the changed files from `git diff --name-only origin/$PR_BASE_REF...HEAD`
    and fails when (1) a changed path is managed and `VERSION` is not changed, (2) `VERSION` does not match `^[0-9]+\.[0-9]+$`,
    or (3) `VERSION` is lower than `git show origin/$PR_BASE_REF:VERSION`. A docs-only diff passes. Without `PR_BASE_REF` it is skipped.
  - c. The template's managed list is a new file `.agents/managed.json` in the template repo: `{"managed": [...]}`, the same path
    prefixes that a downstream repo copies into `managed` in its `.agents/template.json` (0001). The owning module is
    `tools/managed_guard.py`, which gets `template_managed()` (reads that file) and reuses `is_managed` from `template_sync.py`.
    Nothing else reads it. The check in (b) is the only user in the template repo.

### 4.2 Downstream record

`.agents/template.json` gets one new field, `synced_version` (string `x.y`), set together with `synced_sha` by the sync PR. A missing
field means "unknown": the poll treats it as `x = 0`, so the first run after the rollout opens one sync issue.

### 4.3 Poll

`tools/template_sync.py` gains `read_version(gh_json)` and `needs_sync(template_version, synced_version)`: true when the `x` of the
template is greater than the recorded `x`. The workflow runs daily; on `schedule` it exits 0 with `template-sync: x unchanged,
skipped` when `needs_sync` is false. `workflow_dispatch` has a boolean input `force` that skips the version gate (G). An open
`Template sync` issue is still edited, never duplicated (0001, 4.2). The issue shows both versions and the `Sync:` lines.

### 4.4 Trust and permissions

- No new permission, token or secret. The job keeps `contents: read` and the author app token with `issues: write`.
- The version text comes from another repo: it is read as data, validated with the regex above, rejected otherwise (exit 1, no issue),
  and never put into a shell command or an expression. `Sync:` lines are quoted in the issue body inside a fenced block, length
  capped, and the issue is still trusted only by the 0001 rule (app author plus `Template-Sync:` SHA line). The developer reads the
  files at the SHA from `.template/`, not the changelog text, as instructions.
- Rollout of the check touches `tools/check/`, which is a code-owner path: security reviewer plus Daniel.

## 5. Migration and compatibility

- Additive. Downstream repos without `synced_version` get one sync issue on the next run, then follow `x`.
- A repo that wants today's behaviour (every managed change) sets repo variable `TEMPLATE_SYNC_MODE=all`; the gate is skipped.
  Default is `version`. `TEMPLATE_SYNC=off` still disables everything.
- Large syncs keep using the part 1 / part 2 split of 0010.
- Downstream setup documentation (goes to `README.md` and `README.de.md` "Keeping projects in sync"):
  1. Install the author app on the template repo and the project (owner step).
  2. Copy `.github/workflows/template-sync.yml` and `tools/template_sync.py` from the template (or take the first sync).
  3. Create `.agents/template.json` with `template`, `synced_sha`, `synced_version`, `managed`, `overrides`.
  4. Optional variables: `TEMPLATE_SYNC` (`off` disables), `TEMPLATE_SYNC_MODE` (`version` default, `all`).
  5. Check: run the workflow with `force`; expect one issue; a second run edits it.
  6. When a sync PR merges, `synced_sha` and `synced_version` move forward and the next issue waits for the next `x`.

## 6. Test and verification plan

All fail on today's code (no `VERSION`, no gate, no field):
- `tests/test_template_sync.py`: `read_version` accepts `1.0` and `12.3`, rejects `v1.0`, `1`, `1.0.0`, `1.0\n; rm`, and empty text;
  `needs_sync` is true for `2.0` vs `1.5`, false for `1.9` vs `1.0`, false for equal, true for a missing record; `force` skips the
  gate; `y`-only change creates and edits no issue; an `x` change creates one issue and a second run edits it.
- `tests/test_template_sync.py`: the issue body shows both versions; a `Sync:` line with markdown, a mention or 2,000 characters is
  fenced and cut.
- `tests/test_check_version.py` (extended, see 4.1): `VERSION` `1.0` with `## [1.0]` passes and fails on today's code (`no version found`);
  without the section it fails; `v1.0` fails; the existing `x.y.z` cases still pass unchanged.
- `tests/test_check_version_bump.py`: a changed managed path without a `VERSION` change fails; with a bump passes; a lowered, malformed
  or `v`-prefixed `VERSION` fails; a docs-only diff passes; no `PR_BASE_REF` skips. The changed-file list is passed in, no git call in the test.
- `tests/test_managed_guard.py` (extended): `template_managed()` reads `.agents/managed.json` and returns
  the prefixes; missing file gives an empty list.
- `tests/test_template_sync_workflow.py`: workflow has no new permission, no `repository_dispatch` trigger, version text is not used in
  a `run:` expression; `make check` runs actionlint and zizmor on it.
- Before rollout: one scratch downstream repo with `synced_version: 0.0`: dispatch gives one issue; after the sync PR a daily run with
  an unchanged `x` is a no-op; a template `y` bump keeps it a no-op; an `x` bump opens a new issue. Not run yet (open).

## 7. Rollback

Set `TEMPLATE_SYNC_MODE=all` to return to "report every managed change", or `TEMPLATE_SYNC=off` to stop. Each implementation PR is one
rebase-merged commit and can be reverted. `VERSION`, `CHANGELOG.md` and `synced_version` are inert without the gate and the check.

## 8. Split into PR-sized implementation issues

Each issue carries `Design: docs/design/0011-automatic-template-sync.md`, at most ~400 changed lines. Order:
1. **Version core**: `tools/template_sync.py` (`read_version`, `needs_sync`, `synced_version` bump, issue text), `tests/test_template_sync.py`.
   No workflow change yet.
2. **Version file and check**: `VERSION` (`1.0`), `CHANGELOG.md` (`## [Unreleased]` and `## [1.0]`), `.agents/managed.json`,
   `tools/check/check_version.py` (accepts `x.y`), new `tools/check/check_version_bump.py`, `tools/managed_guard.py` (`template_managed()`),
   `Makefile` line for the bump check, `tests/test_check_version.py` (extended), `tests/test_check_version_bump.py`, developer role
   line (bump rule, `sync:must` label). `risk:infra`. Independent of 1.
3. **Workflow** (needs 1): `.github/workflows/template-sync.yml` daily cron, `force` input, `TEMPLATE_SYNC_MODE` (with its
   `docs/variables.md` row, see below), `tests/test_template_sync_workflow.py`. `risk:security` (workflow with tokens).
   The `docs/variables.md` row belongs here, not in 4: `tests/test_variables_doc.py` fails on any `vars.X` in a workflow without a row.
   Write the expression as `(vars.TEMPLATE_SYNC_MODE || 'version') == 'all'`: `check_var_defaults.py` only flags `!=` on `vars.X`.
4. **Docs** (last): `README.md`, `README.de.md` setup section, `docs/decisions/0007-template-sync.md` paragraph.

1 and 2 touch disjoint files and may run in parallel.

## 9. Owner decisions

1. **Version meaning and start**: confirm `x` = must-have, `y` = small fixes/docs, start at `1.0`, and that a `y`-only change never
   starts a sync by itself (only a manual `force` or `TEMPLATE_SYNC_MODE=all`). This sets how often downstream repos get a Daniel-gated PR.
2. **Daily poll cost**: one scheduled run per downstream repo per day (a few API calls, no model, no quota). Confirm daily, or choose weekly.
