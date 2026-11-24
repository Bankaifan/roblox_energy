import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
SCRIPT = (ROOT / "scripts" / "ci" / "luau-check.sh").read_text(encoding="utf-8")
ROKIT = (ROOT / "rokit.toml").read_text(encoding="utf-8")
FETCH = re.compile(r"^    fetch (\S+) ([0-9a-f]{64}) (\S+)$", re.MULTILINE)


def pinned():
    return {name: (url, sha) for url, sha, name in FETCH.findall(SCRIPT)}


def test_each_tool_of_rokit_toml_is_fetched_from_its_release_at_the_pinned_version():
    got = pinned()
    rokit = dict(re.findall(r'^([\w-]+) = "([^"]+)"$', ROKIT, re.MULTILINE))
    assert sorted(got) == sorted(rokit)
    for name, (url, _) in got.items():
        repo, version = re.fullmatch(r"(.+)@(.+)", rokit[name]).groups()
        assert url.startswith(f"https://github.com/{repo}/releases/download/"), (name, url)
        assert re.search(rf"/releases/download/v?{re.escape(version)}/", url), (name, url)


def test_the_bootstrap_does_not_call_the_github_api():
    assert "api.github.com" not in SCRIPT
    assert "rokit self-install" not in SCRIPT
