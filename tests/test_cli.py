import json
import subprocess
import sys

import pytest

from pbq import __version__, cli, protocol
from pbq.manifest import song_id
from tests.audio import make_mp3
from tests.test_backup import packaged
from tests.test_drive import plug


@pytest.fixture
def cfg_file(config, tmp_path):
    """config.toml apontando para o diretório temporário da fixture `config`."""
    root = config.paths.state
    path = tmp_path / "config.toml"
    path.write_text(
        f'[paths]\ninput = "{root}/in"\nwork = "{root}/work"\nlibrary = "{root}/lib"\n'
        f'state = "{root}"\n[drive]\nroots = ["{root}/media"]\n'
    )
    return path


def run(cfg_file, capsys, *args):
    code = cli.main(["--config", str(cfg_file), *args])
    lines = [json.loads(line) for line in capsys.readouterr().out.splitlines()]
    return code, lines


def test_version_prints_json(capsys, cfg_file):
    code, lines = run(cfg_file, capsys, "version")
    assert code == 0
    assert lines == [
        {"type": "version", "name": "pbq", "version": __version__, "config": str(cfg_file.resolve())}
    ]


def test_command_is_required():
    with pytest.raises(SystemExit):
        cli.main([])


def test_module_entry_point(tmp_path):
    """`python -m pbq` é como o jogo chama o backend quando não há o script `pbq` no PATH."""
    out = subprocess.run(
        [sys.executable, "-m", "pbq", "version"], cwd=tmp_path, capture_output=True, text=True, check=True
    ).stdout
    assert json.loads(out)["name"] == "pbq"


def test_protocol_contract():
    with pytest.raises(ValueError, match="fora do contrato"):
        protocol.write("done", count=1)


def test_drive_list(config, cfg_file, capsys):
    plug(config, "COM")
    plug(config, "SEM", folder="outra")
    code, lines = run(cfg_file, capsys, "drive", "list")
    assert code == 0
    assert [(d["name"], d["has_folder"]) for d in lines[0]["drives"]] == [("COM", True), ("SEM", False)]


def test_drive_process_streams_progress(config, cfg_file, capsys):
    mount = plug(config, files={"a.mp3": b"aaa", "b.mp3": b"bbb"})
    code, lines = run(cfg_file, capsys, "drive", "process", "--mount", str(mount))
    assert code == 0
    assert lines[-1] == {"type": "done", "count": 2, "errors": []}
    progress = [m for m in lines if m["type"] == "progress"]
    assert progress[-1] == {"type": "progress", "phase": "copying", "done": 2, "total": 2, "fraction": 1.0}
    assert {m["phase"] for m in progress} == {"reading", "copying"}


def test_drive_export_and_import(config, cfg_file, capsys):
    packaged(config, "aaa")
    mount = plug(config)
    code, lines = run(cfg_file, capsys, "drive", "export", "--mount", str(mount))
    assert (code, lines[-1]) == (0, {"type": "done", "count": 1, "errors": []})
    code, lines = run(cfg_file, capsys, "drive", "import", "--mount", str(mount))
    assert (code, lines[-1]) == (0, {"type": "done", "count": 0, "errors": []})


def test_drive_error_is_a_message(config, cfg_file, capsys, monkeypatch):
    mount = plug(config, files={"a.mp3": b"aaa"})

    def full(*args):
        raise OSError("espaço insuficiente: faltam 3 MB")

    monkeypatch.setitem(cli.DRIVE_ACTIONS, "process", full)
    code, lines = run(cfg_file, capsys, "drive", "process", "--mount", str(mount))
    assert code == 1
    assert lines == [{"type": "error", "message": "espaço insuficiente: faltam 3 MB"}]


def test_process_and_status(config, cfg_file, capsys):
    path = make_mp3(config.paths.input / "Artista - Música.mp3")
    sid = song_id(path)
    assert cli.main(["--config", str(cfg_file), "process", "--song", sid[:4]]) == 0
    capsys.readouterr()
    assert cli.main(["--config", str(cfg_file), "status"]) == 0
    out = capsys.readouterr().out
    assert sid in out and "Artista - Música" in out and "ingest:ok" in out


def test_process_reports_failure(config, cfg_file, capsys):
    (config.paths.input / "quebrado.mp3").write_bytes(b"nao e mp3")
    assert cli.main(["--config", str(cfg_file), "process"]) == 1
    capsys.readouterr()
    assert cli.main(["--config", str(cfg_file), "status"]) == 0
    assert "ingest:failed" in capsys.readouterr().out


def test_process_refuses_while_worker_runs(config, cfg_file):
    from pbq.worker import Worker

    holder = Worker(config)  # guardado: o lock dura enquanto o arquivo estiver aberto
    assert holder.acquire_lock()
    assert cli.main(["--config", str(cfg_file), "process"]) == 1


def test_watch(config, cfg_file, monkeypatch):
    calls = []
    monkeypatch.setattr(cli, "die_with_parent", lambda: calls.append("pdeathsig"))
    monkeypatch.setattr(cli.Worker, "run_forever", lambda self: calls.append("loop"))
    assert cli.main(["--config", str(cfg_file), "watch"]) == 1
    assert cli.main(["--config", str(cfg_file), "watch", "--die-with-parent"]) == 1
    assert calls == ["loop", "pdeathsig", "loop"]
