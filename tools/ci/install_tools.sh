#!/usr/bin/env bash
# Install the pinned tools that `make check` and CI use. Used by validate, agent-dev and agent-fix.
# Bump versions here only; one place for every workflow.
set -euo pipefail
RUFF=0.17.4
ZIZMOR=1.32.0
ACTIONLINT=1.7.7
# Optional project pins (design 0016): `.agents/tool-pins.env` may override RUFF, ZIZMOR and ACTIONLINT, one `NAME=version`
# line each. The file is read as data, never sourced; any other name or line fails the step.
pins=".agents/tool-pins.env"
if [ -f "$pins" ]; then
  pin_line='^(RUFF|ZIZMOR|ACTIONLINT)=[0-9][0-9A-Za-z.]*$'
  while IFS= read -r line || [ -n "$line" ]; do
    [[ $line =~ $pin_line ]] || { echo "tool-pins: refused line in $pins: $line" >&2; exit 1; }
    printf -v "${line%%=*}" '%s' "${line#*=}"
  done < "$pins"
fi
pip install "ruff==$RUFF" "zizmor==$ZIZMOR" pytest pytest-timeout pyyaml==6.0.2
for f in requirements.txt requirements_test.txt; do
  if [ -f "$f" ]; then pip install -r "$f"; fi
done
# Project-specific extra command: only from the environment (repo variable vars.EXTRA_INSTALL), never from a file in the
# checkout, because a PR branch must not be able to change what runs here.
if [ -n "${EXTRA_INSTALL:-}" ]; then bash -c "$EXTRA_INSTALL"; fi
# Optional project install hook: the unmanaged `.agents/install.sh`, run once with bash, only in the version on the base
# branch (`origin/main`, or INSTALL_BASE_REF), never the checked-out PR version. Absent on base (or no such ref): no-op.
base_ref="${INSTALL_BASE_REF:-origin/main}"
if git cat-file -e "$base_ref:.agents/install.sh" 2>/dev/null; then
  hook="$(mktemp)"
  git show "$base_ref:.agents/install.sh" > "$hook"
  bash "$hook"
  rm -f "$hook"
fi
dir="${RUNNER_TEMP:-/tmp}/actionlint"
mkdir -p "$dir"
curl -fsSL "https://github.com/rhysd/actionlint/releases/download/v${ACTIONLINT}/actionlint_${ACTIONLINT}_linux_amd64.tar.gz" \
  | tar -xz -C "$dir" actionlint
if [ -n "${GITHUB_PATH:-}" ]; then echo "$dir" >> "$GITHUB_PATH"; fi
