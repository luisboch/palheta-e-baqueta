"""Pendrive: encontrar e copiar MP3s novos (pbq/drive.py, adaptado do usb.py do kraoke)."""

import json
from collections import namedtuple

import pytest

from pbq import drive, fsutil
from pbq.manifest import song_id
from pbq.worker import Worker
from tests.fakes import Publish, Touch


def plug(config, label="PEN", files=None, folder="PALHETA"):
    """Simula um pendrive montado em <media>/<label>/<folder>/."""
    mount = config.paths.state / "media" / label
    (mount / folder).mkdir(parents=True, exist_ok=True)
    for rel, content in (files or {}).items():
        (mount / folder / rel).parent.mkdir(parents=True, exist_ok=True)
        (mount / folder / rel).write_bytes(content)
    return mount


def id_of(tmp_path, content: bytes) -> str:
    path = tmp_path / "hash.tmp"
    path.write_bytes(content)
    return song_id(path)


def test_mounts_and_case_insensitive_folders(config):
    assert drive.mounts(config) == []
    mount = plug(config, folder="Palheta")
    assert drive.mounts(config) == [mount]
    assert drive.drive_dir(config, mount) == mount / "Palheta"
    assert drive.library_dir(config, mount) is None
    assert drive.library_dir(config, mount, create=True) == mount / "Palheta" / "library"


def test_default_roots_are_steamos_and_ubuntu(config, monkeypatch):
    config.sections["drive"] = {}
    monkeypatch.setattr(drive.getpass, "getuser", lambda: "deck")
    seen = []
    monkeypatch.setattr(drive.Path, "iterdir", lambda self: seen.append(str(self)) or iter(()))
    assert drive.mounts(config) == []
    assert seen == ["/run/media/deck", "/media/deck"]


def test_folder_is_configurable_and_kraoke_folder_is_ignored(config):
    mount = plug(config, folder="kraoke", files={"a.mp3": b"do kraoke"})
    assert drive.find_new(config, mount, drive.hash_cache(config)) == []
    config.sections["drive"]["folder"] = "kraoke"
    assert len(drive.find_new(config, mount, drive.hash_cache(config))) == 1


def test_unreadable_folder(config, tmp_path):
    assert drive.find_child(tmp_path / "sumiu", "x") is None
    assert drive.drive_dir(config, tmp_path / "sumiu") is None
    assert drive.library_dir(config, tmp_path / "sumiu") is None


def test_find_new_skips_known_ready_and_library_folder(config, tmp_path):
    (config.paths.work / id_of(tmp_path, b"ja processada")).mkdir(parents=True)
    in_library = config.paths.library / id_of(tmp_path, b"na biblioteca")
    in_library.mkdir(parents=True)
    (in_library / "song.json").write_text("{}")
    (config.paths.input / "manual.mp3").write_bytes(b"posta em input")
    mount = plug(
        config,
        files={
            "velha.mp3": b"ja processada",
            "sub/nova.mp3": b"nova",
            "copia/nova.mp3": b"nova",  # mesmo MP3 em duas pastas
            "biblioteca.mp3": b"na biblioteca",
            "input.mp3": b"posta em input",
            "pronta.mp3": b"pronta no pendrive",  # vem pela importação
            "library/abc/original.mp3": b"backup",  # backup não é entrada
            "notas.txt": b"x",
        },
    )
    ready = mount / "PALHETA" / "library" / id_of(tmp_path, b"pronta no pendrive")
    ready.mkdir(parents=True)
    (ready / "song.json").write_text("{}")

    progress = drive.Progress()
    new = drive.find_new(config, mount, drive.hash_cache(config), progress)
    assert [p.relative_to(mount / "PALHETA").as_posix() for p, _ in new] == ["copia/nova.mp3"]
    assert progress.done == progress.total == 6  # library/ nem entra na conta


def test_hash_cache_persists_between_commands(config, monkeypatch):
    mount = plug(config, files={"a.mp3": b"aaa", "b.mp3": b"bbb"})
    drive.find_new(config, mount, drive.hash_cache(config))
    calls = []
    monkeypatch.setattr(drive, "song_id", lambda p: calls.append(p) or "x")
    assert len(drive.find_new(config, mount, drive.hash_cache(config))) == 2
    assert calls == []  # tudo do cache em disco
    (mount / "PALHETA" / "a.mp3").write_bytes(b"mudou de tamanho")
    (mount / "PALHETA" / "b.mp3").unlink()
    drive.find_new(config, mount, drive.hash_cache(config))
    assert [p.name for p in calls] == ["a.mp3"]
    cached = json.loads((config.paths.work / drive.HASH_CACHE).read_text())
    assert [k.rsplit("/", 1)[1] for k in cached] == ["a.mp3"]  # b.mp3 saiu do pendrive


def test_process_copies_and_renames_conflicts(config):
    (config.paths.input / "pendrive").mkdir()
    (config.paths.input / "pendrive" / "x.mp3").write_bytes(b"outra musica, mesmo nome")
    mount = plug(config, files={"x.mp3": b"nova", "sub/y.mp3": b"outra"})

    seen = []
    progress = drive.Progress(on_change=lambda p: seen.append(p.as_dict()))
    result = drive.process_new(config, mount, progress)
    dest = config.paths.input / "pendrive"
    assert sorted(p.relative_to(dest).as_posix() for p in result.copied) == ["sub/y.mp3", "x (2).mp3"]
    assert progress.copying and progress.fraction == 1.0
    assert seen[0] == {"phase": "reading", "done": 1, "total": 2, "fraction": 0.5}
    assert seen[-1] == {"phase": "copying", "done": 2, "total": 2, "fraction": 1.0}
    assert drive.process_new(config, mount).copied == []  # já está em input


def test_copy_error_does_not_stop_the_others(config, monkeypatch):
    mount = plug(config, files={"a.mp3": b"aaa", "b.mp3": b"bbb"})
    real = drive.copy_atomic

    def flaky(src, dst):
        if src.name == "a.mp3":
            raise OSError("pendrive removido")
        real(src, dst)

    monkeypatch.setattr(drive, "copy_atomic", flaky)
    result = drive.process_new(config, mount)
    assert [p.name for p in result.copied] == ["b.mp3"]
    assert result.errors == ["a.mp3: pendrive removido"]


def test_worker_processes_what_was_copied(config):
    mount = plug(config, files={"musica.mp3": b"conteudo"})
    drive.process_new(config, mount)
    worker = Worker(config, stage_classes=[Touch, Publish])
    worker.run_once()
    assert worker.run_once() == 1
    assert (mount / "PALHETA" / "musica.mp3").exists()  # o pendrive nunca é tocado
    assert drive.process_new(config, mount).copied == []  # já processada


def test_not_enough_space(config, monkeypatch):
    mount = plug(config, files={"a.mp3": b"aaa"})
    Usage = namedtuple("Usage", "total used free")
    monkeypatch.setattr(fsutil.shutil, "disk_usage", lambda p: Usage(10, 10, 1))
    with pytest.raises(fsutil.NotEnoughSpace, match="espaço insuficiente"):
        drive.process_new(config, mount)
    assert not list(config.paths.input.rglob("*.mp3"))


def test_no_folder_no_songs(config):
    mount = plug(config, folder="outra")
    assert drive.find_new(config, mount, drive.hash_cache(config)) == []
    assert drive.process_new(config, mount).copied == []
