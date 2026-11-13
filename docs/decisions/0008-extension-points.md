# 0008 Extension points: project files instead of overrides

Status: accepted (issue #533, design 0016 step 8). Describes the state on this branch; steps 1 to 7 of design 0016 are merged.

Context: a downstream project overrode managed files (`.agents/template.json` `overrides`). An override is a whole-file copy
that a template sync cannot update, so every template change to it is a hand merge (design 0016, section 1).

Decision:
1. A project puts its additions into four files that are not managed paths (`.agents/managed.json`):
   - `project.mk`: recipes with `project-check::`; `make check` runs them last. The Makefile includes the file when it exists.
   - `AGENTS.project.md`: project rules, imported by `CLAUDE.md` after `AGENTS.md`. The Limits in `AGENTS.md` win.
   - `.agents/checks.json`: `{"required": ["name", ...]}`, project required checks. `tools/ruleset.py build` adds them to the
     template ruleset; a name that repeats a template check or is malformed is refused. `status` reads the same set.
   - `.agents/tool-pins.env`: `RUFF`, `ZIZMOR` or `ACTIONLINT` pins as `NAME=version` lines. Any other line or name fails
     `tools/ci/install_tools.sh`; the file is never sourced.
2. Template tests live in `tests/agent/` (managed, with their own conftest). `tests/` is the project's own tree.
3. A project with these four files and no overrides takes a template sync as a clean copy and `make check` is green. The
   acceptance is `tests/agent/test_extension_points_e2e.py`: a sync beside the project files, a fresh downstream `make check`,
   and the `checks.json` build.

Open (not measured here; each is a follow-up, not a claim):
- The override list of ha-luxtronik-shi (22 entries) is not readable from this repo. Its first migration PR lists the paths
  and counts what is left; design 0016 section 4.6 expects at most 3 with a reason each.
- Claude Code's behavior on a missing `AGENTS.project.md` import is not measured. The import is in place, so a project
  without the file would see an error; the file is shipped empty for that reason.
- Project CI jobs: design 0016 puts them in an unmanaged `project-validate.yml`. No template file has that name yet; a
  scratch run must show the reported name of a plain job before a name enters `checks.json`.
- Required checks take effect only after the built ruleset is imported by hand in *Settings > Rules* (design 0016, owner
  decision 2).

Consequences:
- Moving template tests from `tests/` to `tests/agent/` is the one breaking change: a downstream override on an old
  `tests/test_*.py` path blocks the rename and must be migrated (design 0016, section 5).
- `.agents/checks.json` is a security path owned through CODEOWNERS (`risk` classifies it as `security`).
- Existing overrides keep working until removed, so migration is per file.
- Pinning workflows and tools by SHA instead of copying them (design 0016, option N) is not decided here; it is owner decision 1.

Rationale: [docs/design/0016-extension-points.md](../design/0016-extension-points.md).
