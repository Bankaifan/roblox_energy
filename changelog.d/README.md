# Changelog fragments

Every user-visible change adds `changelog.d/<issue>.md` (AGENTS.md). A PR that changes a managed path (`.agents/managed.json`) must add one: `tools/check/check_version_bump.py` enforces that for managed paths only. No PR touches `VERSION` or `CHANGELOG.md`.

- One or more lines, one per changelog entry (a leading `- ` is added when missing).
- Optional `step: x` or `step: y` line: `x` for a `sync:must` issue (breaking for downstream syncs), `y` otherwise (default).
- After the merge the merge train (`tools/train.py`, one writer) runs `tools/release_fragments.py` on main: each fragment gets
  the next version, a `## [x.y] - date` section in `CHANGELOG.md`, and is deleted. `make check` (`check_version_bump.py`) fails a
  managed change without a fragment and a PR that edits `VERSION`.
