# Project checks (not managed by the template). `make check` runs this last.
# The guard keeps the template's fresh-downstream test green: it copies the template without tests/ (agent-template issue).
project-check::
	@if [ -f tests/Harness.luau ]; then bash scripts/ci/luau-check.sh; else echo "luau-check: no tests/Harness.luau, skipped"; fi
