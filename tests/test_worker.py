import json
import os

import pytest

from pbq import events
from pbq import worker as worker_module
from pbq.manifest import song_id
from pbq.scan import Scanner
from pbq.worker import Worker
from tests.fakes import Boom, Publish, Touch


def mp3(config, name="a.mp3", content=b"fake mp3"):
    path = config.paths.input / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(content)
    return path


def read_events(config):
    path = config.paths.state / "events.jsonl"
    return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []


def queue(config):
    return json.loads((config.paths.state / "queue.json").read_text())


# --- scanner -----------------------------------------------------------------


def test_scanner_waits_for_stable_file(config):
    mp3(config)
    scanner = Scanner(config)
    assert scanner.scan() == []  # visto pela primeira vez
    assert len(scanner.scan()) == 1  # mesmo tamanho: estável
    assert len(Scanner(config).scan()) == 1  # outro scanner: vem do cache, sem esperar


def test_scanner_ignores_growing_file(config):
    path = mp3(config)
    scanner = Scanner(config)
    scanner.scan()
    path.write_bytes(b"fake mp3 maior agora")
    assert scanner.scan() == []
    assert len(scanner.scan()) == 1


def test_scanner_skips_tmp_duplicates_and_forgets_removed(config):
    a = mp3(config, "a.mp3", b"um")
    mp3(config, "copia.mp3", b"um")  # mesmo conteúdo = mesmo id
    mp3(config, ".tmp.b.mp3", b"dois")  # cópia em andamento
    mp3(config, "sub/c.MP3", b"tres")
    scanner = Scanner(config)
    scanner.scan()
    songs = scanner.scan()
    assert sorted(s.source for s in songs) == sorted(
        [str(a.resolve()), str((config.paths.input / "sub/c.MP3").resolve())]
    )
    assert scanner.input_ids() == {s.id for s in songs}
    a.unlink()
    scanner.scan()
    assert str(a) not in scanner.cache


# --- eventos -----------------------------------------------------------------


def test_events_contract(tmp_path):
    path = tmp_path / "events.jsonl"
    events.emit(path, "ready", id="x", label="A - B")
    assert json.loads(path.read_text())["type"] == "ready"
    with pytest.raises(ValueError, match="fora do contrato"):
        events.emit(path, "ready", id="x")
    with pytest.raises(ValueError):
        events.emit(path, "inventado")


def test_rotate(tmp_path, monkeypatch):
    path = tmp_path / "events.jsonl"
    events.rotate(path)  # não existe: nada
    events.emit(path, "queue", pending=1)
    monkeypatch.setattr(events, "MAX_SIZE", 5)
    events.rotate(path)
    assert path.read_text() == ""


# --- worker ------------------------------------------------------------------


def test_worker_processes_new_song(config):
    mp3(config)
    worker = Worker(config, stage_classes=[Touch, Publish])
    assert worker.run_once() == 0  # arquivo ainda não estável
    assert queue(config)["pending"] == []
    assert worker.run_once() == 1

    types = [e["type"] for e in read_events(config)]
    assert types[:2] == ["queued", "queue"] and types[-2:] == ["ready", "queue"]
    assert "progress" in types
    index = json.loads((config.paths.library / "index.json").read_text())
    assert [s["id"] for s in index["songs"]] == [song_id(config.paths.input / "a.mp3")]
    assert queue(config)["current"] is None

    worker.run_once()  # nada novo: nenhum evento a mais
    assert len(read_events(config)) == len(types)


def test_progress_is_throttled_but_stage_edges_pass(config):
    mp3(config)
    t = [0.0]
    worker = Worker(config, stage_classes=[Touch, Publish], clock=lambda: t[0])
    worker.run_once()
    worker.run_once()
    progress = [(e["stage"], e["fraction"]) for e in read_events(config) if e["type"] == "progress"]
    # Touch reporta 0.25/0.5/0.75 no mesmo instante: só o início e o fim de cada etapa passam.
    assert progress == [("touch", 0.0), ("touch", 1.0), ("publish", 0.0), ("publish", 1.0)]


def test_queue_snapshot_while_processing(config):
    mp3(config, "a.mp3", b"um")
    mp3(config, "b.mp3", b"dois")
    snapshots = []

    class Spy(Touch):
        def run(self, song, progress=lambda f: None):
            snapshots.append(queue(self.config))

    worker = Worker(config, stage_classes=[Spy])
    worker.run_once()
    worker.run_once()
    first = snapshots[0]
    assert len(first["pending"]) == 2
    assert first["current"]["stage"] == "touch" and first["current"]["fraction"] == 0.0
    assert len(snapshots[1]["pending"]) == 1


def test_worker_failure_is_not_retried(config):
    mp3(config)
    worker = Worker(config, stage_classes=[Boom, Publish])
    for _ in range(3):
        worker.run_once()
    failed = [e for e in read_events(config) if e["type"] == "failed"]
    assert len(failed) == 1
    assert failed[0]["stage"] == "boom"
    assert "falhou de propósito" in failed[0]["error"]


def test_models_released_when_queue_empties(config):
    worker = Worker(config, stage_classes=[Touch])
    worker.stages()
    worker.run_once()
    assert worker._stages is None


def test_single_worker_lock(config):
    first = Worker(config)
    assert first.acquire_lock()
    assert not Worker(config).acquire_lock()
    # a tentativa recusada não apaga o PID de quem tem o lock
    assert (config.paths.state / ".worker.lock").read_text() == str(os.getpid())


def test_run_forever(config, monkeypatch):
    config.sections["watch"] = {"nice": 5, "torch_threads": 3, "interval": 0}
    niced = []
    monkeypatch.setattr(worker_module.os, "nice", niced.append)
    monkeypatch.delenv("OMP_NUM_THREADS", raising=False)

    class Stop(Exception):
        pass

    def stop(seconds):
        raise Stop

    monkeypatch.setattr(worker_module.time, "sleep", stop)
    with pytest.raises(Stop):
        Worker(config, stage_classes=[Touch]).run_forever()
    assert niced == [5] and os.environ["OMP_NUM_THREADS"] == "3"
    assert queue(config)["pending"] == []


def test_run_forever_gives_up_without_lock(config, monkeypatch):
    holder = Worker(config)
    assert holder.acquire_lock()
    monkeypatch.setattr(worker_module.os, "nice", lambda n: pytest.fail("não deveria rodar"))
    Worker(config).run_forever()
