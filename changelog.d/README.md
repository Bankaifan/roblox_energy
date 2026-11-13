# Changelog fragments

A PR that changes a managed path (`.agents/managed.json`) adds `changelog.d/<issue>.md` and does not touch `VERSION` or `CHANGELOG.md`.

- One or more lines, one per changelog entry (a leading `- ` is added when missing).
- Optional `step: x` or `step: y` line: `x` for a `sync:must` issue (breaking for downstream syncs), `y` otherwise (default).
- After the merge the merge train (`tools/train.py`, one writer) runs `tools/release_fragments.py` on main: each fragment gets
  the next version, a `## [x.y] - date` section in `CHANGELOG.md`, and is deleted. `make check` (`check_version_bump.py`) fails a
  managed change without a fragment and a PR that edits `VERSION`.
