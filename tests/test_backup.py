"""Salvar e importar a biblioteca pelo pendrive (pbq/backup.py, portado do kraoke)."""

import json
import shutil

from pbq import backup, drive
from pbq.library import FORMAT_VERSION
from tests.conftest import make_config
from tests.test_drive import plug


def packaged(config, sid, title="Música", audio=b"ogg" * 100):
    """Música pronta na biblioteca, no formato do package."""
    d = config.paths.library / sid
    d.mkdir(parents=True)
    (d / "guitar.ogg").write_bytes(audio)
    (d / "notes.chart").write_text("[Song]\n")
    (d / "beatmap.json").write_text('{"beats": []}')
    files = {"guitar": "guitar.ogg", "chart": "notes.chart", "beatmap": "beatmap.json", "cover": None}
    (d / "song.json").write_text(
        json.dumps(
            {
                "version": FORMAT_VERSION,
                "id": sid,
                "title": title,
                "artist": "Fulano",
                "duration": 60,
                "files": files,
            }
        )
    )
    return d


def test_export_is_incremental(config):
    packaged(config, "aaa", "Primeira")
    packaged(config, "bbb", "Segunda")
    mount = plug(config, folder="outra-coisa")  # pendrive sem pasta palheta

    progress = drive.Progress()
    assert backup.export_library(config, mount, progress) == 2
    dest = mount / "palheta" / "library"
    assert sorted(p.name for p in (dest / "aaa").iterdir()) == [
        "beatmap.json",
        "guitar.ogg",
        "notes.chart",
        "song.json",
    ]
    assert progress.fraction == 1.0 and progress.done == 2

    assert backup.export_library(config, mount) == 0  # nada mudou
    song_json = config.paths.library / "aaa" / "song.json"
    song_json.write_text(song_json.read_text().replace("Primeira", "Primeirx"))  # mesmo tamanho
    assert backup.export_library(config, mount) == 1
    assert json.loads((dest / "aaa" / "song.json").read_text())["title"] == "Primeirx"

    shutil.rmtree(config.paths.library / "bbb")
    backup.export_library(config, mount)
    assert (dest / "bbb" / "song.json").exists()  # nada é apagado no pendrive


def test_export_writes_song_json_last(config, monkeypatch):
    packaged(config, "aaa")
    order = []
    real = backup.copy_atomic
    monkeypatch.setattr(backup, "copy_atomic", lambda s, d: order.append(d.name) or real(s, d))
    backup.export_library(config, plug(config))
    assert order == ["guitar.ogg", "notes.chart", "beatmap.json", "song.json"]


def test_import_between_two_computers(config, tmp_path):
    packaged(config, "aaa", "Primeira")
    packaged(config, "bbb", "Segunda")
    mount = plug(config)
    backup.export_library(config, mount)

    other = make_config(tmp_path / "outro")
    shutil.copytree(mount, other.paths.state / "media" / "PEN")
    other_mount = drive.mounts(other)[0]
    packaged(other, "bbb", "Segunda (já tinha)")
    (other_mount / "PALHETA" / "library" / "incompleta").mkdir()  # sem song.json

    assert backup.import_library(other, other_mount) == 1
    index = json.loads((other.paths.library / "index.json").read_text())
    assert [(s["id"], s["title"]) for s in index["songs"]] == [
        ("aaa", "Primeira"),
        ("bbb", "Segunda (já tinha)"),
    ]
    assert backup.import_library(other, other_mount) == 0


def test_import_skips_invalid_songs(config):
    mount = plug(config)
    src = packaged(make_config(config.paths.state / "x"), "ccc")
    lib = mount / "PALHETA" / "library"
    lib.mkdir()
    shutil.copytree(src, lib / "renomeada")  # id não bate com a pasta
    shutil.copytree(src, lib / "ccc")
    data = json.loads((lib / "ccc" / "song.json").read_text())
    (lib / "ccc" / "song.json").write_text(json.dumps({**data, "version": FORMAT_VERSION + 1}))
    shutil.copytree(src, lib / "ddd")
    (lib / "ddd" / "song.json").write_text(json.dumps({**data, "id": "ddd"}))
    (lib / "ddd" / "guitar.ogg").unlink()  # arquivo listado faltando
    (lib / "eee").mkdir()
    (lib / "eee" / "song.json").write_text("não é json")
    assert backup.import_library(config, mount) == 0
    assert not config.paths.library.exists() or not any(config.paths.library.glob("*/song.json"))


def test_import_without_library_folder(config):
    assert backup.import_library(config, plug(config)) == 0
