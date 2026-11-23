import pathlib
import re
import subprocess

SCRIPT = pathlib.Path(__file__).resolve().parent.parent / "scripts" / "ci" / "luau-check.sh"
PATTERN = re.search(r"grep -Eq '([^']+)'", SCRIPT.read_text(encoding="utf-8")).group(1)


def runs_for(*paths):
    """Does a PR that changes these paths run the balance campaign? Same grep as the script."""
    done = subprocess.run(["grep", "-Eq", PATTERN], input="\n".join(paths), text=True, check=False)
    return done.returncode == 0


def test_the_balance_campaign_runs_only_for_what_it_reads_or_writes():
    for path in ("src/shared/Core/GameCore.luau", "src/shared/Config/Land.luau", "sim/Sim.luau", "scripts/balance.luau",
                 "docs/balance/tolerances.md", "rokit.toml"):
        assert runs_for("README.md", path), path
    assert not runs_for("src/client/Hud.luau", "src/server/PlotService.luau", "docs/canary.md", "tools/train.py",
                        "scripts/balance.luau.bak", ".agents/template.json")
    assert not runs_for()


def test_main_and_an_unknown_diff_always_run_it():
    text = SCRIPT.read_text(encoding="utf-8")
    assert 'balance=1\nif [ -n "${PR_BASE_REF:-}" ] && changed="$(git diff --name-only "origin/$PR_BASE_REF...HEAD" 2>/dev/null)"; then' in text
    assert 'if [ "$balance" = 1 ]; then\n  lune run scripts/balance\n  git diff --exit-code -- docs/balance\n' in text
