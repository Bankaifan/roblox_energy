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
dir="${RUNNER_TEMP:-/tmp}/actionlint"
mkdir -p "$dir"
curl -fsSL "https://github.com/rhysd/actionlint/releases/download/v${ACTIONLINT}/actionlint_${ACTIONLINT}_linux_amd64.tar.gz" \
  | tar -xz -C "$dir" actionlint
if [ -n "${GITHUB_PATH:-}" ]; then echo "$dir" >> "$GITHUB_PATH"; fi
