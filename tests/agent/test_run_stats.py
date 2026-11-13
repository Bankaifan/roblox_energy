"""Quota baseline (design 0007): model runs per day from fixture data."""
import datetime
import json

import run_stats as s

NOW = datetime.datetime(2026, 11, 10, 12, 0, tzinfo=datetime.UTC)
MODEL = [{"steps": [{"name": "Gate", "conclusion": "success"}, {"name": "Run claude", "conclusion": "success"}]}]
NO_MODEL = [{"steps": [{"name": "Gate", "conclusion": "success"}, {"name": "Run claude", "conclusion": "skipped"}]}]


def run(id_, day, conclusion="success"):
    return {"databaseId": id_, "conclusion": conclusion, "createdAt": f"2026-11-{day:02d}T08:00:00Z"}


def test_ran_model():
    assert s.ran_model(MODEL)
    assert not s.ran_model(NO_MODEL)
    assert not s.ran_model([{"steps": None}, {}])


def test_stats_counts_model_and_skipped_runs():
    runs = [run(1, 10), run(2, 10), run(3, 9), run(4, 9, "skipped"), run(5, 8)]
    jobs = {1: MODEL, 2: MODEL, 3: MODEL, 5: NO_MODEL}
    result = s.stats(runs, lambda i: jobs[i], days=14, now=NOW)
    assert result["model_runs"] == 3
    assert result["gate_skipped"] == 1
    assert result["per_day"] == {"2026-11-09": 1, "2026-11-10": 2}


def test_stats_ignores_runs_outside_window():
    runs = [run(1, 10), run(2, 1), run(3, 1, "skipped")]
    result = s.stats(runs, lambda i: MODEL, days=7, now=NOW)
    assert (result["model_runs"], result["gate_skipped"]) == (1, 0)


def test_format_stats():
    out = s.format_stats({"days": 14, "model_runs": 28, "gate_skipped": 5, "per_day": {"2026-11-10": 28}})
    assert "2026-11-10: 28" in out
    assert "Model runs: 28, gate-skipped runs: 5" in out
    assert "(average): 2.00" in out


def test_fetch_uses_gh_calls():
    calls = []

    def fake(*a):
        calls.append(a)
        if a[0] == "run":
            return json.dumps([run(7, 10)])
        return json.dumps({"jobs": MODEL})
    runs, jobs_of = s.fetch(repo="o/r", run=fake)
    assert runs[0]["databaseId"] == 7
    assert s.ran_model(jobs_of(7))
    assert calls[1][1] == "repos/o/r/actions/runs/7/jobs"


def exec_file(denials):
    return json.dumps([{"type": "assistant"}, {"type": "result", "permission_denials": denials}])


TWO_DENIALS = exec_file([{"tool_name": "Bash", "tool_input": {"command": "cat /proc/self/environ"}},
                         {"tool_name": "Edit", "tool_input": {"file_path": "x.py"}}])


def test_denied_per_workflow_sums_fixture():
    entries = [("agent-dev.yml", "2026-11-10T08:00:00Z", TWO_DENIALS),
               ("agent-dev.yml", "2026-11-09T08:00:00Z", exec_file([{"tool_name": "Bash"}])),
               ("agent-fix.yml", "2026-11-10T09:00:00Z", exec_file([])),
               ("agent-dev.yml", "2026-10-01T08:00:00Z", TWO_DENIALS)]
    assert s.denied_per_workflow(entries, days=7, now=NOW) == {"agent-dev.yml": 3, "agent-fix.yml": 0}


def test_format_denied():
    out = s.format_denied({"agent-dev.yml": 2, "agent-fix.yml": 0}, 7)
    assert "agent-dev.yml: 2" in out
    assert "agent-fix.yml: 0" in out
    assert "Denied tool calls: 2" in out


def test_execution_entries_reads_named_files(tmp_path):
    (tmp_path / "agent-dev.yml__2026-11-10T08:00:00Z.json").write_text(TWO_DENIALS, encoding="utf-8")
    (tmp_path / "notes.json").write_text(TWO_DENIALS, encoding="utf-8")
    entries = s.execution_entries(tmp_path)
    assert entries == [("agent-dev.yml", "2026-11-10T08:00:00Z", TWO_DENIALS)]
    assert s.denied_per_workflow(entries, days=7, now=NOW) == {"agent-dev.yml": 2}


def test_main_denied_prints_per_workflow(tmp_path, capsys):
    recent = (datetime.datetime.now(datetime.UTC) - datetime.timedelta(days=1)).strftime("%Y-%m-%dT%H:%M:%SZ")
    (tmp_path / f"agent-dev.yml__{recent}.json").write_text(TWO_DENIALS, encoding="utf-8")
    assert s.main(["run_stats.py", "denied", "30", str(tmp_path)]) == 0
    out = capsys.readouterr().out
    assert "agent-dev.yml: 2" in out
    assert "Denied tool calls: 2" in out
