import json

import numpy as np
import pytest

from pbq import audio
from pbq.charts.chart_file import parse_chart
from pbq.manifest import Song
from pbq.stages import pitched_chart as pitched_stage
from pbq.stages.beats import Beats
from pbq.stages.chart import ChartFile
from pbq.stages.drums_chart import DrumsChart
from pbq.stages.package import Package
from pbq.stages.pitched_chart import PitchedChart
from pbq.stages.separate import STEMS
from tests.audio import make_mp3
from tests.fakes import FakePitch, FakeTracker, FakeTranscriber

RATE = 44100


@pytest.fixture
def song(config):
    path = make_mp3(
        config.paths.input / "Artista - Música.mp3",
        seconds=5.0,
        cover=True,
        tags={"title": "Música", "artist": "Artista", "album": "Disco"},
    )
    s = Song.open(path, config.paths.work)
    from pbq.stages.ingest import Ingest

    Ingest(config).run(s)  # capa e metadados; os do teste vêm por cima
    s.meta.update(
        title="Música",
        artist="Artista",
        album="Disco",
        duration=5.0,
        instruments={"drums": True, "bass": True, "strings": True},
    )
    n = 5 * RATE
    for i, name in enumerate(STEMS):
        tone = (0.05 * np.sin(2 * np.pi * 110 * (i + 1) * np.arange(n) / RATE)).astype(np.float32)
        audio.write(s.path("stems", f"{name}.flac"), np.stack([tone, tone]), RATE)
    return s


def run_all(config, song, pitch=None):
    Beats(config, tracker=FakeTracker()).run(song)
    DrumsChart(config, transcriber=FakeTranscriber()).run(song)
    PitchedChart(config, transcriber=pitch or FakePitch(chord=True)).run(song)
    ChartFile(config).run(song)


def test_pitched_chart_writes_events_with_pitches(config, song):
    pitch = FakePitch(chord=True)
    Beats(config, tracker=FakeTracker()).run(song)
    PitchedChart(config, transcriber=pitch).run(song)
    assert pitch.calls == ["guitar.flac", "bass.flac"]
    strings = json.loads(song.path("charts", "strings.json").read_text())
    bass = json.loads(song.path("charts", "bass.json").read_text())
    assert strings["present"] and strings["events"][0] == [192, [52, 59], 115]  # 0,5 s = 1ª batida
    assert bass["events"][0] == [192, [52], 115]  # baixo: só a mais grave
    assert len(json.loads(song.path("charts", "strings_notes.json").read_text())) == 16


def test_pitched_chart_skips_absent_parts(config, song):
    song.meta["instruments"]["bass"] = False
    pitch = FakePitch()
    Beats(config, tracker=FakeTracker()).run(song)
    PitchedChart(config, transcriber=pitch).run(song)
    assert pitch.calls == ["guitar.flac"]
    assert json.loads(song.path("charts", "bass.json").read_text()) == {"present": False, "events": []}


def test_transcriber_from_config(config, monkeypatch):
    from pbq.models import basic_pitch

    monkeypatch.setattr(basic_pitch, "BasicPitchTranscriber", lambda: FakePitch())
    stage = PitchedChart(config)
    assert stage.transcriber() is stage.transcriber()
    config.stages["pitched_chart"] = {"transcriber": "nenhum"}
    with pytest.raises(ValueError, match="transcriber inválido"):
        PitchedChart(config).transcriber()
    assert set(pitched_stage.TRANSCRIBERS) == {"basic_pitch"}


def test_chart_has_four_difficulties_per_instrument(config, song):
    run_all(config, song)
    chart = parse_chart(song.path("notes.chart").read_text())
    expected = {
        f"{d}{s}" for d in ("Easy", "Medium", "Hard", "Expert") for s in ("Single", "DoubleBass", "Drums")
    }
    assert set(chart.tracks) == expected
    counts = [len(chart.tracks[f"{d}Single"]) for d in ("Easy", "Medium", "Hard", "Expert")]
    assert counts == sorted(counts) and counts[0] < counts[-1]  # mais difícil, mais notas
    assert max(n.lane for n in chart.tracks["EasySingle"]) <= 2
    assert chart.streams == {
        "MusicStream": "song.ogg",
        "GuitarStream": "guitar.ogg",
        "BassStream": "bass.ogg",
        "DrumStream": "drums.ogg",
    }


def test_package_builds_library_folder(config, song):
    run_all(config, song)
    seen = []
    Package(config).run(song, seen.append)
    out = config.paths.library / song.id
    data = json.loads((out / "song.json").read_text())
    assert data["version"] == 1 and data["title"] == "Música" and data["album"] == "Disco"
    assert data["instruments"] == {"drums": True, "bass": True, "strings": True}
    assert data["bpm"] == 120.0 and data["duration"] == 5.0 and data["artist"] == "Artista"
    assert data["files"] == {
        "song": "song.ogg",
        "strings": "guitar.ogg",
        "bass": "bass.ogg",
        "drums": "drums.ogg",
        "chart": "notes.chart",
        "beatmap": "beatmap.json",
        "cover": "cover.jpg",
        "ini": "song.ini",
    }
    for name in data["files"].values():
        assert (out / name).stat().st_size > 0
    assert audio.sample_rate(out / "guitar.ogg") == RATE
    ini = (out / "song.ini").read_text()
    assert "diff_guitar = 3" in ini and "pro_drums = True" in ini and "song_length = 5000" in ini
    assert seen[-1] == 0.8
    assert Package(config).is_done(song) is False and Package(config).outputs(song) == [out / "song.json"]


def test_absent_instrument_audio_goes_to_background(config, song):
    run_all(config, song)
    Package(config).run(song)  # 1ª vez: os três presentes
    song.meta["instruments"]["drums"] = False  # reprocessado: bateria ausente
    song.meta.pop("duration")
    song.path("cover.jpg").unlink()
    Package(config).run(song)
    out = config.paths.library / song.id
    data = json.loads((out / "song.json").read_text())
    assert data["files"]["drums"] is None and not (out / "drums.ogg").exists()
    assert data["files"]["cover"] is None
    assert "diff_drums = -1" in (out / "song.ini").read_text()
    assert data["duration"] == 5.0  # sem metadado: duração do áudio (stems de 5 s)
    rms = lambda p: float(np.sqrt(np.mean(audio.decode(p, RATE) ** 2)))  # noqa: E731
    with_drums = rms(out / "song.ogg")
    assert with_drums > 0.05  # o stem de bateria está no fundo


def test_basic_pitch_adapter_without_the_real_package(monkeypatch):
    import sys
    import types

    from pbq.models import basic_pitch

    root = types.ModuleType("basic_pitch")
    root.ICASSP_2022_MODEL_PATH = "nmp.onnx"
    inference = types.ModuleType("basic_pitch.inference")
    inference.Model = lambda path: ("modelo", path)
    inference.predict = lambda path, model, **kw: (None, None, [(0.5, 0.8, 60, 0.9, [])])
    monkeypatch.setitem(sys.modules, "basic_pitch", root)
    monkeypatch.setitem(sys.modules, "basic_pitch.inference", inference)
    from pathlib import Path

    assert basic_pitch.BasicPitchTranscriber().transcribe(Path("x.flac")) == [(0.5, 0.8, 60, 0.9)]
