# 0016 Extension points: projects need no overrides of managed files

Issue: #419 (design study, no implementation in this PR). Builds on 0001 (template sync), 0011 (version gate), 0014 (sync by script).

## 1. Goal

ha-luxtronik-shi overrides 22 managed files (`.agents/template.json` `overrides`). Each override is a whole-file copy that the
template sync cannot update: a three-way merge per sync (0014 section 3, option D) or a hand merge. Most overrides only add a
project specific to a template file. Goal: every such addition has a place that is NOT a managed file, so a normal project has zero
overrides and a sync is a clean copy. Acceptance: after the next sync the override list of ha-luxtronik-shi has at most 3 entries,
each with a reason why no extension point fits.

## 2. Current state (file references)

- `Makefile`: the single `check` target lists every step (lines 8-23); a project that adds one check overrides the whole file.
- `AGENTS.md` (managed) holds template rules; `CLAUDE.md` is only `@AGENTS.md`. A project adds rules by editing `AGENTS.md`.
- `.github/workflows/validate.yml`: jobs `validate`, `changes`, `agent-smoke` in one file; a project job means overriding it.
- `.github/rulesets/main.json:30`: the four required contexts `validate`, `agent-smoke`, `risk`, `security-review`. `tools/status.py:135-157`
  (`required_contexts`) reads the same file. A project check that must be required means overriding the ruleset.
- `tools/ci/install_tools.sh`: tool versions are variables at the top (lines 5-7); `EXTRA_INSTALL` (an Actions variable, never a file
  of the checkout, line 12-14) covers extra commands but not pins.
- `tests/conftest.py`: template fixtures and the `template_only` marker (0014 section 4.4); project fixtures cannot be added without
  overriding it. `tests/` is a managed prefix (`.agents/managed.json`), so project tests share the prefix with template tests.
- `.agents/managed.json`: managed prefixes. Overrides are whole files (`split_overrides`, 0001).
- `tools/scope_tests.py` and `tests/scope.json` map changed files to tests (0009); they must follow a test move.

## 3. Options with trade-offs

Makefile:
- A. Keep `check` as is, projects override. Status quo, rejected.
- B. `-include project.mk` and a `project-check` target that `check` calls; the template defines an empty `project-check` first, a
  project adds its recipe in `project.mk` (a double-colon rule so both exist). A missing file is not an error. Chosen.

AGENTS.md:
- C. Marked section inside `AGENTS.md`, merged by script. A marker merge is the fragility 0014 avoided. Rejected.
- D. `AGENTS.project.md` (not managed) imported by `CLAUDE.md` (`@AGENTS.md` then `@AGENTS.project.md`). Claude Code's behavior on a
  missing import is not measured yet (open: the step 2 PR measures it by hand; if it errors, the template ships an empty,
  unmanaged `AGENTS.project.md`). `AGENTS.md` stays template-only and size-capped (`docs/budgets.json`); the project file is not capped by the
  template. Chosen. Rule precedence: the template Limits win; `AGENTS.md` says so in one line.

validate.yml:
- E. Project edits `validate.yml` (override). Rejected.
- F. Template jobs stay in `validate.yml`, unchanged (`validate`, `changes`, `agent-smoke`, same triggers). Project jobs go in
  `.github/workflows/project-validate.yml` (not managed, own triggers, own job ids). No reusable workflow, so the required
  context names do not change. Chosen.
- F-alt. Template jobs in a reusable workflow `template-validate.yml` (`workflow_call`), `validate.yml` as a thin caller. Rejected:
  a job of a called workflow reports as `<caller job> / <called job>` (`validate / validate`), which renames the four required
  contexts and needs a ruleset change with a transition that keeps `main` protected and mergeable.

Required checks:
- G. Project edits `rulesets/main.json`. Rejected.
- H. `tools/ruleset.py` builds the ruleset file to import from the template ruleset (template checks) plus the project list
  `.agents/checks.json` (`{"required": ["name", ...]}`, not managed). `status.required_contexts` reads the same merged set. Chosen. The
  template file stays as it is, so CODEOWNERS and `risk.py` keep guarding it; `checks.json` is a new owner-guarded path.

Tests:
- I. Template tests stay in `tests/`. Project tests collide in name and conftest. Rejected.
- J. Template tests move to `tests/agent/` with their own `tests/agent/conftest.py` (template fixtures, the marker hook); `tests/` stays
  free for the project, with its own `tests/conftest.py` (project, not managed). `managed.json` lists `tests/agent/` instead of `tests/`.
  The `template_only` skip (0014) stays. Chosen.

install_tools.sh:
- K. Pins in an optional project file `.agents/tool-pins.env` (`RUFF=...`), read by the script. The file is in the checkout, which the
  script's own comment forbids for COMMANDS: here the file holds only `NAME=version` lines, validated against `^[A-Z_]+=[0-9][0-9A-Za-z.]*$`,
  never sourced or evaluated. Chosen. The pins reach pip only as an argument.
- L. Only `EXTRA_INSTALL`. Cannot pin, rejected as the sole route.

Template workflows and tools by pinned SHA instead of copying:
- M. Keep copying (status quo plus the extension points above). A sync stays a PR; the diff is visible and reviewable.
- N. Projects call `uses: Bankaifan/agent-template/.github/workflows/x.yml@<sha>` and check out `tools/` at that SHA. A sync is a one-line
  pin bump (Dependabot can open it); managed workflow and tool copies disappear, so overrides of them cannot exist. Costs: the template
  repo must be public or grant access; a pinned workflow cannot use project `vars`/secrets without explicit `secrets:` passing; `tools/`
  checkout at run time needs a token or a public repo; the CODEOWNERS and risk gate see only a pin line, not the code, so review moves to
  the template repo; every workflow that is `permissions`-sensitive (author app tokens) runs template code the project never saw.
  That is a trust-model change (AGENTS.md Limits 2 and 5, design 0004).

M plus the extension points makes overrides unnecessary without moving trust. N is the larger lever and an owner decision (section 9);
nothing in this design depends on it. Step 5 (reusable workflow) is the same `workflow_call` file that N would call by SHA, so N
becomes a later one-line change of `uses:` and needs no redesign.

## 4. Chosen approach

B + D + F + H + J + K, M for now, N left to the owner.

### 4.1 Makefile

`check` ends with `$(MAKE) --no-print-directory project-check`. Top of file: `-include project.mk`; `project-check::` defined empty
in the template (`@:`), so `project.mk` adds `project-check::` recipes. `project.mk` is not managed. `make check` output order
and exit code are unchanged without the file.

### 4.2 AGENTS.project.md and CLAUDE.md

`CLAUDE.md` becomes two import lines. `AGENTS.md` gets one line: "Project rules: `AGENTS.project.md` (optional); the Limits above win."
`check_budget.py` caps only template files; the project file is read by no role by default: roles say "read AGENTS.md" and a one-line
addition in `developer.md` and `orchestrator.md` names the optional second file.

### 4.3 Workflow split and required checks

`validate.yml` stays as it is (jobs `validate`, `changes`, `agent-smoke`, same triggers): no reusable workflow, so the names do not
change. `changes` stays in `validate.yml` and `agent-smoke` keeps `needs: changes`. Project jobs go in `project-validate.yml` (not
managed, own triggers, own job ids). A plain job reports under its `name:` (its id when unset); open: the step 5 scratch run confirms
it before a project name enters `checks.json`.

Required names: `tools/ruleset.py build` writes `<template ruleset> + .agents/checks.json` to stdout; `status.required_contexts`
calls the same function. Nothing applies the ruleset automatically: the README (setup step 4) has Daniel import
`.github/rulesets/main.json` by hand in *Settings > Rules*, and `build` produces the file for that same manual import. Order: the
built file is imported before a PR adds a name to `checks.json`, otherwise the status tool treats a check as required that GitHub
does not enforce.
A name in `checks.json` that equals a template name is an error (no silent duplicates).

### 4.4 Tests layout

`git mv tests/test_*.py tests/agent/`, template `conftest.py` content to `tests/agent/conftest.py`; `tests/conftest.py` becomes empty
in the template (a project-owned file, kept so `pytest` finds `tests/`). `scope_tests.py`, `tests/scope.json` and the Makefile
`unit-tests` target (`pytest tests`) cover both directories. Managed prefix: `tests/agent/`. The move and the conftest change are one commit (step 7): no commit has test files in `tests/`
without their fixtures.

### 4.5 Pins

`install_tools.sh` reads `.agents/tool-pins.env` with a fixed-format parser. Only the names in the script (`RUFF`, `ZIZMOR`,
`ACTIONLINT`) are accepted; any other name, a bad version or a bad line fails the step. A PR branch cannot add a tool or choose one.

### 4.6 How the override list drops to at most 3

Mapping of the issue's override categories (the exact 22 paths live in ha-luxtronik-shi and are open: not readable from this repo;
the first migration PR there lists them):

| Today's override | Replacement | Remaining override |
|---|---|---|
| `Makefile` | `project.mk` | no |
| `AGENTS.md` | `AGENTS.project.md` | no |
| `.github/workflows/validate.yml` | `project-validate.yml` | no |
| `.github/rulesets/main.json` | `.agents/checks.json` | no |
| `tools/ci/install_tools.sh` | `.agents/tool-pins.env` | no |
| `tests/conftest.py` | project `tests/conftest.py` outside the managed `tests/agent/` | no |
| template tests skipped as they check template docs | `template_only` marker (0014), moved under `tests/agent/` | no |
| about 15 further files (open) | by category, see below | to be counted |

Expected remainder, each with a reason in `overrides[].why`: `.github/CODEOWNERS` (owner names are per project, no extension point
that keeps the owner gate), `.github/dependabot.yml` (ecosystem list is per project), and at most one more found during migration. If the
count after the first migration PR exceeds 3, a follow-up design names the missing extension point; this is open until the list is read.

## 5. Migration and compatibility

- Additive in the template: without `project.mk`, `AGENTS.project.md`, `checks.json` and `tool-pins.env`, behavior is as today.
- Downstream: the sync copies the new managed files. A project then moves its override content into the new project files and removes
  the override entry in the same PR. Overrides keep working until removed, so migration is per file.
- `tests/` to `tests/agent/` is the only breaking move: a downstream repo with overrides on `tests/test_*.py` must migrate the
  override path. The sync script treats a renamed managed file as delete plus add (0014 plan); a project override on the old path
  would block the delete: step 7 adds a conflict note for that case.
- Roles, workflows and `scope.json` get the new test path in the same step as the move (no window with a broken scope).

## 6. Test and verification plan

Each fails on today's code:
- Makefile: a fixture dir with `project.mk` defining `project-check::` that prints a marker; `make check` output contains it. Without
  `project.mk` the target is a no-op. Today `project-check` does not exist.
- CLAUDE.md: a test parses imports and requires `@AGENTS.md` and `@AGENTS.project.md`; `AGENTS.md` names the file.
- CLAUDE.md, missing import: the test cannot measure Claude Code; the step 2 PR records a manual run in a project without
  `AGENTS.project.md` (open: not run yet).
- Workflows: `tests/test_validate_workflow.py` (step 5) asserts `validate.yml` keeps the jobs `validate`, `changes`, `agent-smoke`
  with their ids and triggers; actionlint and zizmor stay green. A scratch run of a project job shows its reported name before a
  name enters `checks.json` (open: not run yet).
- Ruleset: `tools/ruleset.py build` with a `checks.json` of `["lint-docs"]` returns the four template contexts plus `lint-docs`; a
  duplicate or malformed name exits non-zero; `status.required_contexts` returns the same set. No test calls GitHub.
- Pins: a pins file with `RUFF=9.9.9` reaches the pip arguments (script run with `pip` stubbed on `PATH`); a line like `RUFF=1;rm -rf /`
  is refused and nothing runs.
- Tests layout: with a project `tests/test_x.py` and a failing-fixture-free `tests/conftest.py`, `pytest tests` runs both trees; the
  marker skip still skips a template test downstream.
- Drift fixture (like 0014 acceptance 3): a downstream fixture with `project.mk`, `AGENTS.project.md`, `checks.json`, no overrides of the
  managed files, takes a template sync as a clean copy and `make check` stays green.

## 7. Rollback

Every step is one rebase-merged commit and can be reverted. The new project files are optional, so removing the template hooks leaves
project files inert. The test move reverts with the inverse `git mv`. A project that has not removed its override keeps working.

## 8. Split into PR-sized implementation issues

Each issue carries `Design: docs/design/0016-extension-points.md`, at most ~400 changed lines.

### Step 1: Makefile project.mk hook and project-check
Files: `Makefile`, `tests/test_makefile_hooks.py`
Acceptance: `make check` runs `project-check` from an optional `project.mk`; without the file the output is unchanged.

### Step 2: AGENTS.project.md imported by CLAUDE.md
Files: `CLAUDE.md`, `AGENTS.md`, `.agents/roles/developer.md`, `tests/test_claude_imports.py`
Acceptance: `CLAUDE.md` imports `AGENTS.md` and `AGENTS.project.md`, `AGENTS.md` names the project file and keeps its size cap.

### Step 3: Tool pins from an optional project file
Files: `tools/ci/install_tools.sh`, `tests/test_install_tools.py`
Acceptance: `.agents/tool-pins.env` overrides only `RUFF`, `ZIZMOR`, `ACTIONLINT` in the strict `NAME=version` format; any other name or line fails the step.

### Step 4: Scope mapping for tests/agent and tests side by side
Files: `tools/scope_tests.py`, `tests/scope.json`, `tests/test_scope_layout.py`
Acceptance: scope mapping accepts `tests/agent/` and a project `tests/` tree side by side; no file moves and conftest is unchanged.

### Step 5: Pin the validate job names that the required checks use
Files: `tests/test_validate_workflow.py`
Acceptance: a test pins the jobs `validate`, `changes`, `agent-smoke` and their triggers in `validate.yml`; a scratch run shows the reported name of a plain project job (open until run).

### Step 6: Required checks from template list plus checks.json
Files: `tools/ruleset.py`, `tools/status.py`, `tools/ci/risk.py`, `.github/CODEOWNERS`, `tests/test_ruleset_build.py`
Acceptance: `tools/ruleset.py build` writes the template contexts plus `.agents/checks.json`, duplicates and malformed names refused; `status.required_contexts` returns the same set; `checks.json` is an owner-guarded path. Daniel imports the built file (owner decision 2).
Depends on: 5

### Step 7: Move template tests and narrow the managed prefix
Files: `tests/agent/` (moved test files and the template conftest), `tests/conftest.py` (emptied), `tests/scope.json`, `.agents/managed.json`, `tools/template_apply.py`, `tests/agent/test_template_apply.py`
Acceptance: all template tests live in `tests/agent/` in one commit with their conftest, `managed.json` lists `tests/agent/`, a sync renames cleanly or reports a blocked override.
Depends on: 4

### Step 8: Downstream fixture and docs
Files: `tests/agent/test_extension_points_e2e.py`, `docs/decisions/0008-extension-points.md`, `README.md`, `README.de.md`
Acceptance: a fixture with the four project files and no overrides takes a sync as a clean copy and `make check` is green; docs explain the files.
Depends on: 1, 2, 3, 6, 7

Steps 1, 2, 3, 4 and 5 are independent with disjoint files and run in parallel. 6 needs 5, 7 needs 4. Step 6 is `risk:security`
(`checks.json` becomes a required-check source and an owner-guarded path) and touches `.github/CODEOWNERS`, so it needs Daniel as
code owner. Every step changes managed paths; step 7 bumps `VERSION` as `x`, the others as `y`.

## 9. Owner decisions

1. **Pin workflows and tools by SHA instead of copying them?** Today a project holds copies of the template workflows and tools and a
   sync is a reviewed PR. With SHA references a project holds one pin line per workflow and checks out `tools/` at that SHA; a sync is
   a pin bump Dependabot can open, and overrides of those files cannot exist. Cost: the review of template code moves to the template
   repo, the template must be readable by the projects, and workflows with write tokens run template code at once on a bump
   (this changes AGENTS.md Limit 5 in practice). Worst case: a bad template commit reaches every project through an auto-merged bump.
   This design needs neither answer: "ja" starts a follow-up design 0017 (pin gate, token and secrets passing, Dependabot rule);
   "nein" keeps copying with the extension points above. What the reviewers recommend: open until reviewed; this design recommends
   "nein" for now and revisiting after the overrides are gone.
2. **Import of the built ruleset (step 6)?** The ruleset is changed by hand in *Settings > Rules* (README), a permission change
   (AGENTS.md Limits 2 and 5). Worst case: a wrong import drops a required check and `main` merges unchecked. What the reviewers
   recommend: yes, Daniel imports the file `tools/ruleset.py build` produced, after the step 5 scratch run. "ja" = Daniel imports it
   when step 6 is merged; "nein" = step 6 merges with `build` only and `checks.json` stays empty.

Neither answer is needed to accept this design. Step 6 needs answer 2.
