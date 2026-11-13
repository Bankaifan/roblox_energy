# 0009 Test scoping and nightly heavy tests

Issue: #135 (design study, no implementation in this PR). Restart after PR #265, which was closed over a PR-body problem; the review points of #265 are fixed here.

## 1. Goal

PRs run only the tests that cover the changed files. `main` always runs everything. Expensive tests get a `slow` marker. The repo variable `NIGHTLY_HEAVY_TESTS` (default `false`) decides where slow tests run: `false` = on every PR and on `main`, exactly as today; `true` = only in a nightly workflow that opens a `prio:1` issue on failure. With the variable unset, nothing changes for PRs except scoping.

## 2. Current state (file references)

- `Makefile:4`: `make check` runs `pytest --timeout=60 -q` over all of `tests/`. `validate.yml:32-43` runs `make check` on `pull_request` and on `push` to `main`; `timeout-minutes: 15`.
- Measured on this tree (`pytest --timeout=60 -q --durations=5`): 681 tests, 6.26 s, slowest single test 0.43 s. No test is slow today, so scoping saves seconds now. The value is for grown projects (tier thresholds, `docs/decisions/0008-tiers.md`: median CI above 10 min proposes tier M).
- Layout: one `tests/test_<module>.py` per `tools/<module>.py` (some for `tools/ci/` and `tools/check/`), plus workflow tests (`tests/test_*_workflow.py`) that read `.github/workflows/*.yml`. `tests/conftest.py` is shared. There is no pytest config file and no registered marker.
- Required checks (`.github/rulesets/main.json:30`): `validate`, `agent-smoke`, `risk`, `security-review`. `agent-smoke` already uses the "always report, skipped counts as success" pattern with a `changes` job (`validate.yml:47-68`).
- Scheduled workflows are watched by `tools/liveness.py:15` (`SCHEDULED`, overdue after 2 intervals, then a signed `prio:1` issue). Variable defaults are checked by `tools/check/check_var_defaults.py` (an unset variable must not switch a job off).

## 3. Options with trade-offs

Scoping:
- A. Import-graph analysis (which tests import a changed module). Precise, but needs a parser, breaks on dynamic imports and subprocess calls, and needs a threshold. Rejected.
- B. Naming convention plus an explicit mapping file. Chosen: `tools/<path>/<name>.py` maps to `tests/test_<name>.py` if that file exists; an optional checked-in `tests/scope.json` adds explicit extra edges (for example `tools/guard_mark.py` also covers `tests/test_liveness.py`). Unmapped files fall back to a full run, never to "no tests".
- C. Test-impact tools (pytest-testmon and similar). Extra dependency in the pinned tool set and a cache to keep. Rejected.

Where the scope is applied:
- D. Separate required check `tests-scoped`. Changes the ruleset (CODEOWNERS path) and the required list. Rejected.
- E. Inside `make check`: the pytest line asks the script for the selection. `validate` stays the single required check, the ruleset is untouched. Chosen.

Heavy tests:
- F. `slow` marker, variable-controlled. Chosen (issue proposal). Registered in `tests/conftest.py` (`pytest_configure`), so no new config file.
- G. Move slow tests to a separate directory. Loses the module-to-test naming and hides them from local runs. Rejected.

## 4. Chosen approach

B + E + F.

### 4.1 Scoping script
New `tools/scope_tests.py`: `python3 tools/scope_tests.py <base-ref>` prints either `ALL` or a space-separated list of test files. Input is `git diff --name-only <base>...HEAD`. Rules, first match wins:
1. Full run (`ALL`) when any changed path is: `tests/conftest.py`, `tests/scope.json`, `tools/scope_tests.py`, `Makefile`, `.github/workflows/**`, `.github/actions/**`, `.github/rulesets/**`, `tools/liveness.py`, `tools/ci/**`, `tools/check/**`, `pyproject.toml`, `requirements*.txt`, `tools/ci/install_tools.sh`, or any non-listed file under `.github/`. The list is `FULL_RUN` in the script, tested.
2. Otherwise, per changed `tools/**/*.py` file: its `tests/test_<name>.py` plus the `scope.json` extras. A changed `tests/test_*.py` selects itself. A changed `tools/*.py` with neither a same-name test nor a `scope.json` entry gives `ALL`.
3. Changes that touch no Python and no listed path (`docs/**`, `*.md`, `CHANGELOG.md`, `HANDOVER.md`) select no tests; `make check` then prints `no tests in scope` and runs the other checks as before.
4. Any error (diff fails, base ref missing, unreadable `scope.json`) gives `ALL`. Fail open to more tests, never fewer.

`make check` pytest line: `pytest --timeout=60 -q $(SCOPE)`, where `SCOPE` is the script output when `PR_BASE_REF` is set (pull requests) and empty otherwise, so local runs, pushes to `main` and dispatch runs stay full. `ALL` becomes the empty string. `validate.yml` already fetches full history and exports `PR_BASE_REF`; the diff uses `origin/$PR_BASE_REF`, the same ref `check_test_evidence` uses.

### 4.2 `slow` marker and `NIGHTLY_HEAVY_TESTS`
- `tests/conftest.py` registers `slow`. A test is marked `@pytest.mark.slow` when it needs more than about 5 s or a network/service; the threshold is a guideline in `tests/README` (one line), not a check.
- `NIGHTLY_HEAVY_TESTS` unset or `false`: no deselection anywhere. Slow tests run on every PR and on `main`, as today.
- `true`: PR runs and `main` runs add `-m "not slow"`, and `make check` does too, so it matches CI. Slow tests move to the nightly workflow.
- Plumbing: `validate.yml` passes `NIGHTLY_HEAVY_TESTS: ${{ vars.NIGHTLY_HEAVY_TESTS || 'false' }}` to `make check`; the Makefile adds `-m "not slow"` only when the value is exactly `true`. The `|| 'false'` form never matches `check_var_defaults.py`, so an unset variable cannot switch anything off. The default is registered in the variable defaults section of `README.md` / `README.de.md` and in `setup.yml` next to the other optional variables.

### 4.3 Nightly workflow
New `.github/workflows/nightly.yml`: `schedule` (daily) and `workflow_dispatch`, `permissions: contents: read`, one job `slow-tests` with `if: vars.NIGHTLY_HEAVY_TESTS == 'true'`. It runs `pytest --timeout=300 -q -m slow` on `main`. A second job `report` (`needs: slow-tests`, `if: failure()`, `issues: write`) opens one `Nightly heavy tests failed` issue with label `prio:1`, deduplicated by title like `liveness.ensure_overdue_issue` (body is signed with `GUARD_KEY` in a script step; fixed text only, no log text, design 0004). The title prefix joins the guard title allowlist if design 0008 lands it.
Liveness: `nightly.yml` is added to `liveness.SCHEDULED` with an interval of 24 h. While the variable is off the job is skipped, a skipped run counts as `success` in `gh run list --status success`, so no overdue issue is raised. Open: this must be measured on the real repo (a run whose only job is skipped reports `success`); if it does not, `liveness.overdue_runs` skips workflows whose variable is not `true` (a `GATED = {"nightly.yml": "NIGHTLY_HEAVY_TESTS"}` map, tested).

### 4.4 Required checks and CI layout
No ruleset change. `validate` stays the one required test check and always reports. The scoped selection happens inside it, so a PR cannot merge without a `validate` result. `main` pushes run the full suite (`PR_BASE_REF` empty). The nightly workflow is not required; its failure is an issue, not a merge gate.

## 5. Migration and compatibility

Additive. Until the scoping PR merges nothing changes. After it, PRs run fewer tests; the variable default keeps slow tests in PRs. `NIGHTLY_HEAVY_TESTS=true` is Daniel's switch; no script flips it. Downstream projects get the files through template sync as `managed` files.
Before the scoping PR, record the full suite time (`pytest --durations=10`) in its PR body; today 6.26 s for 681 tests.

## 6. Test and verification plan

All of these fail on today's code (no script, no marker, no nightly workflow):
- `tests/test_scope_tests.py`: `tools/tier.py` selects `tests/test_tier.py`; `tools/ci/risk.py` gives `ALL` (listed `tools/ci/**`); each `FULL_RUN` path gives `ALL` (parametrised, including `tools/liveness.py`, `.github/rulesets/main.json`, `tests/conftest.py`, `tests/scope.json`, `Makefile`); a docs-only change selects nothing; a changed test selects itself; `scope.json` extras are added; an unknown `tools/` file without a test gives `ALL`; broken `scope.json`, bad base ref and empty diff are handled as specified.
- Initial "no test" list (named, not a rule): the script's test asserts the current set of `tools/*.py` without a same-name test equals an explicit list in the test file (computed once with the real tree when the PR is written); that file lists them as `ALL`-fallback, so no check fails on today's tree. A new tool without a test therefore only costs a full run, it does not fail CI (test evidence stays with `check_test_evidence`).
- `tests/test_makefile_scope.py`: with `PR_BASE_REF` unset the pytest line has no file list; with `NIGHTLY_HEAVY_TESTS` unset or `false` it has no `-m`; with `true` it has `-m "not slow"` (parse `make -n`).
- `tests/test_nightly_workflow.py`: `schedule` and `workflow_dispatch` only; job guarded by `vars.NIGHTLY_HEAVY_TESTS == 'true'`; no secret outside script steps; `report` job needs `issues: write` and nothing more; `nightly.yml` in `liveness.SCHEDULED`.
- `tests/test_liveness.py` (extended): no overdue issue for `nightly.yml` while skipped runs count as success or the gate map says the variable is off; an overdue one when it is `true` and nothing ran.
- `tests/test_conftest_markers.py`: `slow` is registered (`pytest --strict-markers` passes).
- Measurement on the real repo: a PR touching only `tools/tier.py` runs only `tests/test_tier.py`; a PR touching `Makefile` runs everything; a push to `main` runs all; with the variable `true`, a dispatch of `nightly.yml` runs only slow tests and a deliberately failing slow test on a throw-away branch opens exactly one issue. Recorded in the PR bodies.
- `make check` on every PR.

## 7. Rollback

Set `NIGHTLY_HEAVY_TESTS` back to `false` (or delete it): slow tests return to every PR. To turn scoping off, revert the scoping PR (one rebase-merged commit) or make `FULL_RUN` match everything. Deleting `nightly.yml` also needs its `liveness.SCHEDULED` entry removed in the same PR. The ruleset is untouched, so there is nothing to undo there.

## 8. Split into PR-sized implementation issues

Each under about 400 changed lines, disjoint files, in this order:
1. **Scoping script**: `tools/scope_tests.py`, `tests/scope.json` (may be `{}`), `tests/test_scope_tests.py`. Records the full suite time in the PR body. Nothing calls it yet.
2. **`slow` marker and variable plumbing**: `tests/conftest.py` (register the marker), `tests/test_conftest_markers.py`, a one-line note in `tests/`. No test is marked yet, so no behaviour change. Independent of 1.
3. **Wire scoping and the variable into `make check`**: `Makefile`, `.github/workflows/validate.yml` (env `NIGHTLY_HEAVY_TESTS`), `tests/test_makefile_scope.py`. `risk:security` (workflow change). Needs 1 and 2.
4. **Nightly workflow**: `.github/workflows/nightly.yml`, `tools/liveness.py` (`SCHEDULED`, optional gate map), `tests/test_nightly_workflow.py`, `tests/test_liveness.py`. `risk:security` (new workflow with `issues: write`). Needs 2; independent of 3.
5. **Docs**: `README.md`, `README.de.md` (variable default, how to mark a slow test), `setup.yml` variable listing if it lists optional variables, CHANGELOG entry if present. Last.

Order: 1 and 2 first (disjoint, can run together under the 2-job cap), then 3 and 4, then 5.

## 9. Owner decisions

none
