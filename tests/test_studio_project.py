import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
PROJECT = json.loads((ROOT / "default.project.json").read_text(encoding="utf-8"))
LUNE_ONLY_REQUIRE = re.compile(r'require\("\.\./')


def test_tests_with_lune_only_requires_are_not_synced_to_studio():
    # Studio cannot resolve relative requires like "../sim/Sim"; such tests must stay out of the Rojo tree.
    for path in sorted((ROOT / "tests").glob("*.test.luau")):
        if LUNE_ONLY_REQUIRE.search(path.read_text(encoding="utf-8")):
            assert f"tests/{path.name}" in PROJECT["globIgnorePaths"], path.name
