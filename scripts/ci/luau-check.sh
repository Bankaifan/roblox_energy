#!/usr/bin/env bash
# Luau checks for `make check` (via project.mk): format, lint, Lune tests, Rojo build.
# Installs the tools from rokit.toml when they are missing (Linux x86_64 only; elsewhere install Rokit yourself).
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
ROKIT_VERSION=1.2.0

missing=0
for tool in rojo lune selene stylua; do
  command -v "$tool" >/dev/null 2>&1 || missing=1
done

if [ "$missing" = 1 ]; then
  if ! command -v rokit >/dev/null 2>&1; then
    [ "$(uname -s)-$(uname -m)" = "Linux-x86_64" ] || { echo "luau-check: install Rokit $ROKIT_VERSION and run 'rokit install'" >&2; exit 1; }
    tmp="$(mktemp -d)"
    curl -fsSL -o "$tmp/rokit.zip" "https://github.com/rojo-rbx/rokit/releases/download/v${ROKIT_VERSION}/rokit-${ROKIT_VERSION}-linux-x86_64.zip"
    python3 -c "import sys,zipfile; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" "$tmp/rokit.zip" "$tmp"
    chmod +x "$tmp/rokit"
    "$tmp/rokit" self-install
    export PATH="$HOME/.rokit/bin:$PATH"
    if [ -n "${GH_TOKEN:-}" ]; then rokit authenticate github --token "$GH_TOKEN" --skip-verify; fi
  fi
  rokit install --no-trust-check
fi

stylua --check src tests scripts sim
selene src tests scripts sim
lune run scripts/run-tests
# Balance report (Bauplan section 2): regenerated here, and the committed docs/balance must match it.
lune run scripts/balance
git diff --exit-code -- docs/balance
rojo build default.project.json -o "$(mktemp -d)/PowerGrid.rbxl"
