import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
PROJECT = json.loads((ROOT / "default.project.json").read_text(encoding="utf-8"))
TEST_PROJECT = json.loads((ROOT / "test.project.json").read_text(encoding="utf-8"))
LUNE_ONLY_REQUIRE = re.compile(r'require\("\.\./')


def test_tests_with_lune_only_requires_are_not_synced_to_studio():
    # Studio cannot resolve relative requires like "../sim/Sim"; such tests must stay out of the Rojo tree.
    for path in sorted((ROOT / "tests").glob("*.test.luau")):
        if LUNE_ONLY_REQUIRE.search(path.read_text(encoding="utf-8")):
            assert f"tests/{path.name}" in TEST_PROJECT["globIgnorePaths"], path.name


def test_published_place_has_no_tests():
    assert "Tests" not in PROJECT["tree"]["ReplicatedStorage"]
    assert "src/server/**/*.test.luau" in PROJECT["globIgnorePaths"]
    assert "Dev" not in PROJECT["tree"]["ServerScriptService"]


def test_test_project_is_the_game_plus_tests():
    # Same tree as the published place, plus only the tests and the runner.
    expected = json.loads(json.dumps(PROJECT["tree"]))
    expected["ReplicatedStorage"]["Tests"] = {"$path": "tests"}
    expected["ServerScriptService"]["Dev"] = {"$path": "src/dev"}
    assert TEST_PROJECT["tree"] == expected


def test_game_code_does_not_require_tests():
    for folder in ("src/client", "src/server", "src/shared"):
        for path in (ROOT / folder).rglob("*.luau"):
            if path.name.endswith(".test.luau"):
                continue
            assert "Tests" not in path.read_text(encoding="utf-8"), str(path)
