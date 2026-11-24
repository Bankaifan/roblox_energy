#!/usr/bin/env bash
# Luau checks for `make check` (via project.mk): format, lint, Lune tests, Rojo build.
# Installs the tools pinned in rokit.toml when they are missing: with Rokit, or by URL on Linux x86_64.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

missing=0
for tool in rojo lune selene stylua luau-lsp; do
  command -v "$tool" >/dev/null 2>&1 || missing=1
done

if [ "$missing" = 1 ]; then
  if command -v rokit >/dev/null 2>&1; then
    rokit install --no-trust-check
  else
    # No Rokit (CI): fetch the release archives by URL. Rokit asks the GitHub API, which answers 403 (rate limit) on
    # shared runners when the step has no token (template-sync). Each version must be the one in rokit.toml.
    [ "$(uname -s)-$(uname -m)" = "Linux-x86_64" ] || { echo "luau-check: install Rokit and run 'rokit install'" >&2; exit 1; }
    bin="$(mktemp -d)"
    while read -r repo version asset sha; do
      grep -q "\"$repo@$version\"" rokit.toml || { echo "luau-check: $repo $version is not the version in rokit.toml" >&2; exit 1; }
      curl -fsSL --retry 3 -o "$bin/tool.zip" "https://github.com/$repo/releases/download/$asset"
      echo "$sha  $bin/tool.zip" | sha256sum -c --quiet
      python3 -c "import sys,zipfile; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" "$bin/tool.zip" "$bin"
    done <<'TOOLS'
rojo-rbx/rojo 7.7.1 v7.7.1/rojo-7.7.1-linux-x86_64.zip 00feb4fa0829a1dd72b49df2639da519a352bfe13cadcd83969e2ba2bb5693c4
lune-org/lune 0.11.1 v0.11.1/lune-0.11.1-linux-x86_64.zip 39859282ce677fce19e6eb45c37596a90a25c324c95b4e7e02d428b6cae294a1
Kampfkarren/selene 0.32.0 0.32.0/selene-0.32.0-linux.zip d3773393578580074386e69337d35b7acddfbaa9fc38964c07fa3e28436ade9b
JohnnyMorganz/StyLua 2.6.0 v2.6.0/stylua-linux-x86_64.zip a485f72bbfa22e4642e77a84b5edc2611a5cab7477b34e2e709dd8f78e919895
JohnnyMorganz/luau-lsp 1.70.1 1.70.1/luau-lsp-linux-x86_64.zip 1a2ea1ae4f98f8946cefd970a4b54853e11ab4775e6932faa7f60cf920346567
TOOLS
    chmod +x "$bin"/*
    export PATH="$bin:$PATH"
  fi
fi

stylua --check src tests scripts sim
selene src tests scripts sim
lune run scripts/run-tests
# Balance report (Bauplan section 2): regenerated here, and the committed docs/balance must match it.
# The campaign takes about 14 minutes, close to the time limit of the validate job. On a pull request (PR_BASE_REF,
# set by validate.yml) it runs only when the PR changes what the campaign reads or writes; a push to main and a
# local run always run it, and so does a PR whose changed files cannot be listed.
balance=1
if [ -n "${PR_BASE_REF:-}" ] && changed="$(git diff --name-only "origin/$PR_BASE_REF...HEAD" 2>/dev/null)"; then
  if ! grep -Eq '^(src/shared/|sim/|scripts/balance\.luau$|docs/balance/|rokit\.toml$)' <<<"$changed"; then balance=0; fi
fi
if [ "$balance" = 1 ]; then
  lune run scripts/balance
  git diff --exit-code -- docs/balance
else
  echo "luau-check: balance campaign skipped (no change under src/shared, sim, scripts/balance.luau, docs/balance)"
fi
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
