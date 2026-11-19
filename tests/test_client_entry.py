import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
MAIN = (ROOT / "src" / "client" / "Main.client.luau").read_text(encoding="utf-8")
LINES = [line.strip() for line in MAIN.splitlines()]


def test_plot_public_remote_is_declared_next_to_the_others():
    assert 'local plotPublic = net:WaitForChild("PlotPublic") :: RemoteEvent' in LINES


def test_welcome_connect_is_its_own_statement():
    assert "welcomeMessage.OnClientEvent:Connect(welcome)" in LINES


def test_plot_public_listener_is_its_own_statement():
    assert "plotPublic.OnClientEvent:Connect(function() end)" in LINES


def test_ready_is_still_fired_last():
    assert LINES[-1] == "ready:FireServer()"
