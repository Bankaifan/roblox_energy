#!/usr/bin/env bash
# Luau checks for `make check` (via project.mk): format, lint, Lune tests, Rojo build.
# Installs the tools from rokit.toml when they are missing (Linux x86_64 only; elsewhere install Rokit yourself).
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
ROKIT_VERSION=1.2.0

missing=0
for tool in rojo lune selene stylua luau-lsp; do
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
    # A token may already be stored (agent runners): that is fine, only a missing one matters.
    if [ -n "${GH_TOKEN:-}" ]; then rokit authenticate github --token "$GH_TOKEN" --skip-verify || true; fi
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
# The test project (adds the tests and the Studio TestRunner) must build too, so it does not rot.
rojo build test.project.json -o "$(mktemp -d)/PowerGridTests.rbxl"
# Typed instances in src/client: an unknown property (`Key 'X' not found in external type`) fails the check.
# luau-lsp reads the Roblox types from the pinned globalTypes.d.lua; the sourcemap lets it follow the requires.
analysis="$(mktemp -d)"
curl -fsSL -o "$analysis/globalTypes.d.lua" "https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/1.70.1/scripts/globalTypes.d.lua"
echo "2857efa8245485f8c25c19c018ee1ef9b46afab4efd2ea70fc3257cd3faf7080  $analysis/globalTypes.d.lua" | sha256sum -c --quiet
rojo sourcemap default.project.json -o "$analysis/sourcemap.json"
status=0
out="$(luau-lsp analyze --platform roblox --definitions=@roblox="$analysis/globalTypes.d.lua" --sourcemap "$analysis/sourcemap.json" src/client 2>&1)" || status=$?
[ "$status" -le 1 ] || { echo "$out" >&2; echo "luau-check: luau-lsp failed (exit $status)" >&2; exit 1; }
case "$out" in
  *"not found in external type"*)
    echo "$out" | grep "not found in external type" >&2
    echo "luau-check: unknown property on a typed instance in src/client" >&2
    exit 1 ;;
esac
