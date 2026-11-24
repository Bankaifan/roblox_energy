import pathlib

SCRIPT = (pathlib.Path(__file__).resolve().parent.parent / "scripts" / "balance.luau").read_text(encoding="utf-8")


def test_a_worker_never_starts_workers():
    """The campaign splits into worker processes. A process started with BALANCE_WORKER must print its block and exit
    before the code that starts workers, or the workers multiply without end."""
    worker = SCRIPT.index("local workerJob = process.env.BALANCE_WORKER")
    exits = SCRIPT.index("process.exit(0)", worker)
    spawn = SCRIPT.index('pcall(process.exec, "lune"')
    assert worker < exits < spawn
    assert "{ env = { BALANCE_WORKER = id } }" in SCRIPT[spawn:spawn + 200]
    assert 'error("balance: bad BALANCE_WORKER value")' in SCRIPT[worker:exits]  # a bad value fails, it does not fall through
