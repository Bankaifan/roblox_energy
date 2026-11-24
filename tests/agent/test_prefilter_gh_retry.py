import pathlib
import subprocess
import sys

import pytest

sys.path.insert(0, str(pathlib.Path(__file__).parent.parent.parent / "tools"))

import prefilter


def fake_run(results, calls):
    def run(cmd, **kw):
        calls.append(cmd)
        r = results.pop(0)
        if r is None:
            raise subprocess.CalledProcessError(1, cmd, output="", stderr="HTTP 502")
        return subprocess.CompletedProcess(cmd, 0, stdout=r, stderr="")

    return run


def test_gh_retries_transient_failure(monkeypatch):
    calls = []
    monkeypatch.setattr(prefilter.subprocess, "run", fake_run([None, None, "[]"], calls))
    monkeypatch.setattr(prefilter.time, "sleep", lambda s: None)
    assert prefilter.gh("issue", "list") == "[]"
    assert len(calls) == 3


def test_gh_raises_after_last_try(monkeypatch):
    calls = []
    monkeypatch.setattr(prefilter.subprocess, "run", fake_run([None, None, None], calls))
    monkeypatch.setattr(prefilter.time, "sleep", lambda s: None)
    with pytest.raises(subprocess.CalledProcessError):
        prefilter.gh("issue", "list")
    assert len(calls) == prefilter.GH_TRIES
