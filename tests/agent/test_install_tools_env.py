import os
import pathlib
import subprocess

ROOT = pathlib.Path(__file__).parent.parent.parent
SCRIPT = ROOT / "tools" / "ci" / "install_tools.sh"


def _run(tmp_path, extra_env, project_env=None):
    """Run install_tools.sh with stubbed pip/curl/tar so nothing is installed."""
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    for name in ("pip", "curl", "tar"):
        stub = bin_dir / name
        stub.write_text("#!/bin/sh\nexit 0\n")
        stub.chmod(0o755)
    work = tmp_path / "work"
    (work / ".agents").mkdir(parents=True)
    if project_env is not None:
        (work / ".agents" / "project.env").write_text(project_env)
    env = {
        "PATH": f"{bin_dir}:{os.environ['PATH']}",
        "RUNNER_TEMP": str(tmp_path / "tmp"),
        "HOME": str(tmp_path),
    }
    env.update(extra_env)
    return subprocess.run(["bash", str(SCRIPT)], check=False, cwd=work, env=env, capture_output=True, text=True)


def test_unset_runs_no_extra_command(tmp_path):
    r = _run(tmp_path, {})
    assert r.returncode == 0, r.stderr


def test_empty_runs_no_extra_command(tmp_path):
    marker = tmp_path / "marker"
    r = _run(tmp_path, {"EXTRA_INSTALL": ""})
    assert r.returncode == 0, r.stderr
    assert not marker.exists()


def test_env_command_runs(tmp_path):
    marker = tmp_path / "marker"
    r = _run(tmp_path, {"EXTRA_INSTALL": f"touch {marker}"})
    assert r.returncode == 0, r.stderr
    assert marker.exists()


def _git(work, *args):
    env = {**os.environ, "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@x", "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@x"}
    subprocess.run(["git", *args], cwd=work, check=True, env=env, capture_output=True)


def _repo_with_hook(tmp_path, base_hook, branch_hook):
    """Stub bin, a git repo whose `base` ref holds base_hook and whose working tree holds branch_hook."""
    work = tmp_path / "work"
    _run(tmp_path, {})  # creates bin and work/.agents
    _git(work, "init", "-q")
    if base_hook is not None:
        (work / ".agents" / "install.sh").write_text(base_hook)
        _git(work, "add", ".agents/install.sh")
    _git(work, "commit", "-q", "--allow-empty", "-m", "base")
    _git(work, "update-ref", "refs/remotes/origin/main", "HEAD")
    if branch_hook is not None:
        (work / ".agents" / "install.sh").write_text(branch_hook)
    return work


def _run_hook(tmp_path):
    env = {
        "PATH": f"{tmp_path / 'bin'}:{os.environ['PATH']}",
        "RUNNER_TEMP": str(tmp_path / "tmp"),
        "HOME": str(tmp_path),
    }
    return subprocess.run(
        ["bash", str(SCRIPT)], check=False, cwd=tmp_path / "work", env=env, capture_output=True, text=True
    )


def test_install_hook_from_base_runs_once(tmp_path):
    marker = tmp_path / "marker"
    _repo_with_hook(tmp_path, f"echo x >> {marker}\n", None)
    r = _run_hook(tmp_path)
    assert r.returncode == 0, r.stderr
    assert marker.read_text() == "x\n"


def test_install_hook_absent_is_noop(tmp_path):
    _repo_with_hook(tmp_path, None, None)
    r = _run_hook(tmp_path)
    assert r.returncode == 0, r.stderr


def test_install_hook_branch_version_is_ignored(tmp_path):
    marker = tmp_path / "marker"
    _repo_with_hook(tmp_path, None, f"touch {marker}\n")
    r = _run_hook(tmp_path)
    assert r.returncode == 0, r.stderr
    assert not marker.exists()


def test_project_env_file_is_ignored(tmp_path):
    marker = tmp_path / "marker"
    r = _run(tmp_path, {}, project_env=f"EXTRA_INSTALL=touch {marker}\n")
    assert r.returncode == 0, r.stderr
    assert not marker.exists()
