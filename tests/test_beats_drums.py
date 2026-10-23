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
    assert beatmap["version"] == 1 and beatmap["bpm"] == 120.0
    assert beatmap["beats"][:3] == [0.5, 1.0, 1.5] and beatmap["downbeats"][:2] == [0.5, 2.5]
    assert len(beatmap["energy"]) == len(beatmap["beats"]) and max(beatmap["energy"]) == 1.0
    assert seen[-1] == 0.9


def test_beats_stage_refuses_silence(config, song):
    with pytest.raises(ValueError, match="sem andamento"):
        Beats(config, tracker=FakeTracker(start=99)).run(song)


def test_tracker_and_transcriber_from_config(config, monkeypatch):
    made = []
    monkeypatch.setattr(beat_this_model, "BeatThisTracker", lambda **kw: made.append(kw) or FakeTracker())
    Beats(config).tracker()
    assert made == [{"checkpoint": "final0", "device": "cpu"}]
    config.stages["beats"] = {"tracker": "nenhum"}
    with pytest.raises(ValueError, match="tracker inválido"):
        Beats(config).tracker()

    from pbq.models import adtof

    built = []
    monkeypatch.setattr(adtof, "AdtofTranscriber", lambda **kw: built.append(kw) or FakeTranscriber())
    stage = DrumsChart(config)
    assert stage.transcriber() is stage.transcriber()
    assert built == [{"models_dir": config.paths.state / "models", "device": "cpu"}]
    config.stages["drums_chart"] = {"transcriber": "nenhum"}
    with pytest.raises(ValueError, match="transcriber inválido"):
        DrumsChart(config).transcriber()
    assert set(beats_stage.TRACKERS) == {"beat_this"} and set(drums_stage.TRANSCRIBERS) == {"adtof"}


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


def test_beat_this_adapter_reports_unreachable_server(monkeypatch):
    import sys
    import types

    fake = types.ModuleType("beat_this.inference")

    def broken(**kw):
        raise ValueError("Could not load the checkpoint")

    fake.Audio2Beats = broken
    monkeypatch.setitem(sys.modules, "beat_this", types.ModuleType("beat_this"))
    monkeypatch.setitem(sys.modules, "beat_this.inference", fake)
    with pytest.raises(RuntimeError, match="servidor dos pesos"):
        beat_this_model.BeatThisTracker()

    fake.Audio2Beats = lambda **kw: lambda signal, sr: (np.array([0.5, 1.0]), np.array([0.5]))
    tracker = beat_this_model.BeatThisTracker()
    assert tracker.track(np.zeros(10, dtype=np.float32)) == ([0.5, 1.0], [0.5])
