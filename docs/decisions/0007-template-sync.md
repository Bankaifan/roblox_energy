# 0007 Template sync

Status: accepted (design `docs/design/0001-template-sync.md`, issue #19; implemented in the merged sync PRs). The porting step is scripted since design `docs/design/0014-template-sync-by-script.md` (#414); the model only merges conflicts (last bullet).

- Projects record the template commit they match in `.agents/template.json` (`synced_sha`, `managed` prefixes, `overrides` with a `why`). The file is not committed to the template, so new projects do not point back at it.
- `.github/workflows/template-sync.yml` runs weekly (and by hand) with the author app token and no model. `tools/template_sync.py` calls the compare API `synced_sha...main` of the template and keeps only `managed` paths. It creates or edits the single open issue `Template sync <short sha>` (labels `agent:dev`, `model:sonnet`, line `Template-Sync: <40 hex>`). Detecting by compare was chosen over hashing files (cannot tell template from project changes) and over a bot that copies files (overwrites adaptations).
- Adaptations are whole-file `overrides`. Originally the developer (sonnet) ported: `clean` files as they are, `overridden` files by hand keeping the intent. Merging by script was rejected as too fragile on adapted files (revised in the last bullet). The PR touches `.github/`, so Daniel approves it as code owner.
- agent-dev downloads the template (public, repo from `.agents/template.json`) at the issue's `Template-Sync` SHA into `.template/` before the developer starts, excluded via `.git/info/exclude` (not `.gitignore`: the runner checkout is throwaway, and the PR changes no tracked ignore rule). Only a trusted sync issue is used, the same rule as above, decided by `tools/ci/template_fetch.py`; the developer has no network or `gh api` tool of its own (#88). Open: the SHA is not yet checked to be in the template's history.
- `tools/trusted_issues.py` trusts a sync issue only when `AUTHOR_BOT` wrote it, the title starts with `Template sync ` and the body has the `Template-Sync:` line (owner decision 2 of the design).
- Fail loudly: a compare with 300 or more files may be truncated, so the run exits 1 and touches no issue. Missing config or empty `synced_sha` is a no-op; the template repo itself is skipped.
- Large syncs are split (design `docs/design/0010-large-sync-security-review.md`, section 4.3): when more than 40 files change and the reviewer pipeline files are among them, the issue gets a `## Part 1: reviewer pipeline` section before `## Part 2: rest`. Part 1 is a PR titled `Template sync <sha> part 1` that ports only the reviewer files, leaves `synced_sha` alone and uses `Refs`; `managed_guard` exempts that title. The sync issue stays open until the final part, which ports the rest, sets `synced_sha` and uses `Closes`. Smaller syncs keep the flat issue.
- Project values are repo variables: `PYTHON_VERSION`, `EXTRA_INSTALL` (never read from a PR branch, because it runs as shell code before review), `RUNNER`, `TEMPLATE_SYNC=off` to disable. `workflow_run.workflows` cannot use expressions, so a differing CI name stays a documented override.
- Open: reading a private template needs the author app installed on it (permission change, owner action). A full `workflow_dispatch` rollout test on a real project is not run yet.
- Rollback: `TEMPLATE_SYNC=off` or disable the workflow; `git revert` the rebase-merged commits.
- Version gate and setup (design `docs/design/0011-automatic-template-sync.md`, issue #386; the schedule is now daily, not weekly as above):
  the poll reports only when the template's `x` (from `VERSION`, `x.y`) is higher than `synced_version` in `.agents/template.json`,
  so `y` changes stay quiet; `force` and `TEMPLATE_SYNC_MODE=all` skip the gate. A project sets it up in six steps (README,
  "Keeping projects in sync"): install the author app, copy the workflow and `tools/template_sync.py` once (projects created from the
  template already have them), add `.agents/template.json` with `synced_sha` and `synced_version`, optionally set `TEMPLATE_SYNC` and
  `TEMPLATE_SYNC_MODE`, check with `force`, then let the sync PR move both fields. Another project reuses the template by creating it
  from this repo and naming this repo in its `template` field.
- Scripted port (design 0014, #414; revises the bullets above): `template-sync.yml` runs `tools/template_sync.py apply` with the
  author app token in a build job that holds only read access; a publish job pushes the one commit and opens the PR. A clean
  sync is `Template sync <version>` with `Closes`, no model. Overridden files are merged with `git merge-file`; only a file
  whose merge conflicts goes to the developer (part 1 PR, issue `Template sync <sha>` with `Template-Sync:`). The developer
  gets the three versions from `materialize` and opens the final PR. `TEMPLATE_SYNC_APPLY=off` keeps the issue-only report.
