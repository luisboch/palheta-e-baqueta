import json

import numpy as np
import pytest

from pbq import audio
from pbq.charts.chart_file import parse_chart
from pbq.charts.drums import GREEN, KICK, RED, YELLOW
from pbq.charts.tempo import RESOLUTION as R
from pbq.manifest import Song
from pbq.models import beat_this as beat_this_model
from pbq.stages import beats as beats_stage
from pbq.stages import drums_chart as drums_stage
from pbq.stages.beats import Beats, beat_energy
from pbq.stages.chart import ChartFile
from pbq.stages.drums_chart import DrumsChart
from tests.audio import make_mp3
from tests.fakes import FakeTracker, FakeTranscriber


@pytest.fixture
def song(config):
    path = make_mp3(config.paths.input / "Artista - Música.mp3", seconds=4.5)
    s = Song.open(path, config.paths.work)
    s.meta.update(
        title="Música", artist="Artista", instruments={"drums": True, "bass": True, "strings": False}
    )
    audio.write(s.path("stems", "drums.flac"), np.zeros((2, 4410), dtype=np.float32), 44100)
    return s


def test_beat_energy_is_relative_to_loudest_beat():
    rate = 100
    signal = np.concatenate([np.ones(100) * 0.1, np.ones(100) * 0.5, np.zeros(100)]).astype(np.float32)
    assert beat_energy(signal, rate, [0.0, 1.0, 2.0]) == [0.2, 1.0, 0.0]
    assert beat_energy(signal, rate, []) == []
    assert beat_energy(signal, rate, [0.5]) == [1.0]
    assert beat_energy(np.zeros(10, dtype=np.float32), rate, [0.0, 0.05]) == [0.0, 0.0]


def test_beats_stage_writes_beatmap(config, song):
    seen = []
    Beats(config, tracker=FakeTracker()).run(song, seen.append)
    beatmap = json.loads(song.path("beatmap.json").read_text())
    assert beatmap["version"] == 1 and beatmap["bpm"] == 120.0 and beatmap["tracker"] == "beat_this"
    assert beatmap["beats"][:3] == [0.5, 1.0, 1.5] and beatmap["downbeats"][:2] == [0.5, 2.5]
    assert len(beatmap["energy"]) == len(beatmap["beats"]) and max(beatmap["energy"]) == 1.0
    assert seen[-1] == 0.9


def test_beats_stage_refuses_silence(config, song):
    with pytest.raises(ValueError, match="sem andamento"):
        Beats(config, tracker=FakeTracker(start=99)).run(song)


def test_tracker_and_transcriber_from_config(config, monkeypatch):
    made = []
    monkeypatch.setattr(beat_this_model, "BeatThisTracker", lambda **kw: made.append(kw) or FakeTracker())
    assert Beats(config).tracker()[0] == "beat_this"
    assert made == [{"models_dir": config.paths.state / "models", "checkpoint": "final0", "device": "cpu"}]
    config.stages["beats"] = {"tracker": "nenhum"}
    with pytest.raises(ValueError, match="tracker inválido"):
        Beats(config)

    from pbq.models import adtof

    built = []
    monkeypatch.setattr(adtof, "AdtofTranscriber", lambda **kw: built.append(kw) or FakeTranscriber())
    stage = DrumsChart(config)
    assert stage.transcriber() is stage.transcriber()
    assert built == [{"models_dir": config.paths.state / "models", "device": "cpu"}]
    config.stages["drums_chart"] = {"transcriber": "nenhum"}
    with pytest.raises(ValueError, match="transcriber inválido"):
        DrumsChart(config).transcriber()
    assert set(beats_stage.TRACKERS) == {"beat_this", "librosa"} and set(drums_stage.TRANSCRIBERS) == {
        "adtof"
    }


def test_drums_chart_on_grid(config, song):
    Beats(config, tracker=FakeTracker()).run(song)
    transcriber = FakeTranscriber()
    DrumsChart(config, transcriber=transcriber).run(song)
    part = json.loads(song.path("charts", "drums.json").read_text())
    assert part["present"] is True
    notes = [tuple(n) for n in part["notes"]]
    # 1ª batida (0,5 s) = tick R (1 batida de introdução): bumbo, chimbal (prato) e prato verde.
    first = [n for n in notes if n[0] == R]
    assert first == [(R, KICK, 0), (R, YELLOW, 0), (R, GREEN, 0), (R, 66, 0), (R, 68, 0)]
    assert (2 * R, RED, 0) in notes  # caixa adiantada 5 ms cai na batida
    assert (R + R // 2, YELLOW, 0) in notes  # chimbal na colcheia
    assert json.loads(song.path("drums_hits.json").read_text())["kick"][0] == 0.51


def test_drums_absent_skips_the_model(config, song):
    song.meta["instruments"]["drums"] = False
    Beats(config, tracker=FakeTracker()).run(song)
    transcriber = FakeTranscriber()
    DrumsChart(config, transcriber=transcriber).run(song)
    assert transcriber.calls == 0
    assert json.loads(song.path("charts", "drums.json").read_text()) == {"present": False, "notes": []}


def test_drums_chart_needs_beatmap(config, song):
    with pytest.raises(FileNotFoundError, match="beatmap"):
        DrumsChart(config, transcriber=FakeTranscriber()).run(song)


def test_chart_file_assembles_everything(config, song):
    Beats(config, tracker=FakeTracker()).run(song)
    DrumsChart(config, transcriber=FakeTranscriber()).run(song)
    ChartFile(config).run(song)
    chart = parse_chart(song.path("notes.chart").read_text())
    assert (chart.name, chart.artist) == ("Música", "Artista")
    assert chart.streams == {"MusicStream": "song.ogg", "DrumStream": "drums.ogg"}
    assert [t.milli_bpm for t in chart.tempos] == [120000]
    assert [(ts.tick, ts.beats) for ts in chart.time_signatures] == [(0, 1), (R, 4)]  # anacruse da introdução
    assert list(chart.tracks) == ["EasyDrums", "MediumDrums", "HardDrums", "ExpertDrums"]
    assert chart.tracks["ExpertDrums"][0].tick == R


def test_chart_without_drums(config, song):
    song.meta["instruments"]["drums"] = False
    Beats(config, tracker=FakeTracker()).run(song)
    DrumsChart(config, transcriber=FakeTranscriber()).run(song)
    ChartFile(config).run(song)
    chart = parse_chart(song.path("notes.chart").read_text())
    assert chart.tracks == {} and chart.streams == {"MusicStream": "song.ogg"}


def test_chart_uses_file_name_without_title(config, song):
    song.meta.clear()
    Beats(config, tracker=FakeTracker()).run(song)
    DrumsChart(config, transcriber=FakeTranscriber()).run(song)
    ChartFile(config).run(song)
    assert parse_chart(song.path("notes.chart").read_text()).name == "Artista - Música"


def test_beat_this_adapter_checks_the_weights_before_loading(monkeypatch, tmp_path):
    import sys
    import types

    loaded = []
    fake = types.ModuleType("beat_this.inference")
    fake.Audio2Beats = lambda **kw: (
        loaded.append(kw) or (lambda signal, sr: (np.array([0.5, 1.0]), np.array([0.5])))
    )
    monkeypatch.setitem(sys.modules, "beat_this", types.ModuleType("beat_this"))
    monkeypatch.setitem(sys.modules, "beat_this.inference", fake)

    def offline(asset, dest):
        raise RuntimeError("não consegui baixar beat_this-final0.ckpt: HTTP 503")

    monkeypatch.setattr(beat_this_model, "fetch", offline)
    with pytest.raises(RuntimeError, match="503"):  # a etapa cai na reserva
        beat_this_model.BeatThisTracker(models_dir=tmp_path)
    assert loaded == []  # nada foi aberto sem o hash conferido
    with pytest.raises(ValueError, match="sem hash conferido"):
        beat_this_model.BeatThisTracker(models_dir=tmp_path, checkpoint="final1")

    monkeypatch.setattr(beat_this_model, "fetch", lambda asset, dest: dest)
    tracker = beat_this_model.BeatThisTracker(models_dir=tmp_path)
    assert loaded[0]["checkpoint_path"] == str(tmp_path / "beat_this-final0.ckpt")
    assert tracker.track(np.zeros(10, dtype=np.float32)) == ([0.5, 1.0], [0.5])


# --- reserva da librosa ----------------------------------------------------------


class Unavailable:
    """Fábrica do rastreador principal que falha como o beat_this sem servidor (conta as tentativas)."""

    def __init__(self):
        self.tries = 0
        self.works = False

    def __call__(self, opts):
        self.tries += 1
        if not self.works:
            raise RuntimeError("servidor dos pesos fora do ar")
        return FakeTracker()


@pytest.fixture
def flaky(monkeypatch):
    factory = Unavailable()
    monkeypatch.setitem(beats_stage.TRACKERS, "beat_this", factory)
    monkeypatch.setitem(beats_stage.TRACKERS, "librosa", lambda opts: FakeTracker(bpm=60))
    return factory


def test_fallback_when_primary_does_not_load(config, song, flaky):
    t = [0.0]
    stage = Beats(config, clock=lambda: t[0])
    stage.run(song)
    beatmap = json.loads(song.path("beatmap.json").read_text())
    assert beatmap["tracker"] == "librosa" and beatmap["bpm"] == 60.0
    song.mark("beats", "done", Beats.version)
    assert stage.is_done(song)  # principal fora: a reserva vale
    assert flaky.tries == 1  # e não insiste antes do intervalo

    flaky.works = True  # o servidor voltou...
    assert stage.is_done(song)  # ...mas ainda dentro do intervalo
    t[0] += beats_stage.RETRY_SECONDS
    assert not stage.is_done(song)  # passou o intervalo: refazer com o principal
    stage.run(song)
    assert json.loads(song.path("beatmap.json").read_text())["tracker"] == "beat_this"
    assert stage.is_done(song)


def test_no_fallback_configured(config, song, flaky):
    config.stages["beats"] = {"fallback": ""}
    with pytest.raises(RuntimeError, match="sem reserva"):
        Beats(config).run(song)


def test_worker_redoes_songs_made_by_the_fallback(config, flaky):
    """Música completa com batidas da reserva volta para a fila quando o principal carrega."""
    from pbq.stages.ingest import Ingest
    from pbq.worker import Worker
    from tests.fakes import Publish

    class Grid(Beats):
        name = "beats"

    class AfterBeats(Publish):
        requires = ("beats",)

    make_mp3(config.paths.input / "a.mp3", seconds=3.0)
    worker = Worker(config, stage_classes=[Ingest, Grid, AfterBeats])
    worker.run_once()
    assert worker.run_once() == 1  # pronta com a reserva
    assert worker.run_once() == 0
    flaky.works = True
    # Etapas novas (o worker as recria depois de a fila esvaziar) tentam o principal na hora.
    worker._stages = None
    assert worker.run_once() == 1  # refeita com o principal
    beatmap = next(config.paths.work.glob("*/beatmap.json"))
    assert json.loads(beatmap.read_text())["tracker"] == "beat_this"


def test_downbeats_follow_the_strongest_phase():
    from pbq.models.librosa_beats import downbeats

    beats = [float(i) for i in range(10)]
    strength = np.array([1, 1, 5, 1, 1, 1, 5, 1, 1, 1.0])  # grave forte nas batidas 2 e 6
    assert downbeats(beats, strength) == [2.0, 6.0]
    assert downbeats([], np.array([])) == []
    assert downbeats([0.0, 1.0], np.array([0.0, 3.0])) == [1.0]


def test_librosa_tracker_on_a_click_track():
    pytest.importorskip("librosa")
    from pbq.models.librosa_beats import SAMPLE_RATE, LibrosaTracker
    from tests.test_dsp import clicks

    signal = clicks([0.5 + 0.5 * i for i in range(16)], seconds=9.0, rate=SAMPLE_RATE, freq=60.0)
    beats, downs = LibrosaTracker().track(signal)
    assert len(beats) >= 12 and abs(60 / np.median(np.diff(beats)) - 120) < 5
    assert set(downs) <= set(beats) and len(downs) >= 3
