import json

import numpy as np
import pytest

from pbq import audio
from pbq.manifest import Song
from pbq.stages import guitar_split as gs
from pbq.stages.guitar_split import ACOUSTIC, ELECTRIC, GuitarSplit, SplitOptions
from tests.fakes import FakeTimbre


def test_decide_smooths_isolated_flips():
    scores = np.array([[0.9, 0.1]] * 4 + [[0.1, 0.9]] + [[0.9, 0.1]] * 4)  # 1 janela "elétrica" no meio
    labels, _ = gs.decide(scores, np.ones(9, dtype=bool), smooth=5)
    assert labels == [ACOUSTIC] * 9


def test_decide_inactive_and_empty_scores():
    scores = np.array([[0.9, 0.1], [0.0, 0.0], [0.1, 0.9]])
    labels, s = gs.decide(scores, np.array([True, True, False]), smooth=1)
    assert labels == [ACOUSTIC, None, None]
    assert np.isnan(s[1]) and np.isnan(s[2])


def test_fill_gaps_takes_nearest_active():
    assert gs.fill_gaps([None, ACOUSTIC, None, None, ELECTRIC, None]) == [
        ACOUSTIC,
        ACOUSTIC,
        ACOUSTIC,
        ELECTRIC,
        ELECTRIC,
        ELECTRIC,
    ]
    assert gs.fill_gaps([None, None]) == [ELECTRIC, ELECTRIC]  # sem guitarra: tanto faz


def test_mask_has_short_ramps():
    mask = gs.acoustic_mask([ACOUSTIC, ELECTRIC], hop_samples=100, length=200, fade_samples=10)
    assert mask[0] == pytest.approx(1.0) and mask[-1] == pytest.approx(0.0)
    ramp = mask[90:110]
    assert np.all(np.diff(ramp) <= 0) and 0 < ramp[10] < 1
    assert len(gs.acoustic_mask([ACOUSTIC], 100, 250, 1)) == 250  # áudio maior que os blocos
    assert len(gs.acoustic_mask([], 100, 50, 1)) == 50


def test_segments_and_summary():
    labels = [None, ACOUSTIC, ACOUSTIC, ELECTRIC]
    s = np.array([np.nan, 0.9, 0.7, 0.2])
    assert gs.segments(labels, s, 1.0) == [
        {"start": 0.0, "end": 1.0, "label": None, "acoustic_score": None},
        {"start": 1.0, "end": 3.0, "label": ACOUSTIC, "acoustic_score": 0.8},
        {"start": 3.0, "end": 4.0, "label": ELECTRIC, "acoustic_score": 0.2},
    ]
    assert gs.summary(labels, s, 1.0) == {
        ACOUSTIC: {"seconds": 2.0, "confidence": 0.6},
        ELECTRIC: {"seconds": 1.0, "confidence": 0.6},
    }
    assert gs.summary([None], np.array([np.nan]), 1.0)[ACOUSTIC] == {"seconds": 0.0, "confidence": 0.0}


def test_options_from_config():
    opts = SplitOptions.from_opts({"window": "3", "smooth": 7, "outro": 1, "classifier": "panns"})
    assert (opts.window, opts.smooth, opts.hop) == (3.0, 7, 1.0)


def guitar_stem(song, seconds=8.0, rate=44100, quiet_from=None):
    t = np.arange(int(seconds * rate)) / rate
    tone = 0.3 * np.sin(2 * np.pi * 220 * t)
    if quiet_from is not None:
        tone[int(quiet_from * rate) :] = 0
    audio.write(song.path("stems", "guitar.flac"), np.stack([tone, tone]).astype(np.float32), rate)


@pytest.fixture
def song(config):
    path = config.paths.input / "a.mp3"
    path.write_bytes(b"x")
    return Song.open(path, config.paths.work)


def test_stage_splits_stem_in_two(config, song):
    guitar_stem(song)
    config.stages["guitar_split"] = {"smooth": 1, "fade": 0.01}
    timbre = FakeTimbre()
    GuitarSplit(config, timbre=timbre).run(song)
    acoustic = audio.decode(song.path("stems", "acoustic.flac"), 44100)
    electric = audio.decode(song.path("stems", "electric.flac"), 44100)
    original = audio.decode(song.path("stems", "guitar.flac"), 44100)
    assert np.allclose(acoustic + electric, original, atol=2e-3)  # nada se perde
    rms = lambda x: float(np.sqrt(np.mean(x**2)))  # noqa: E731
    assert rms(acoustic[:, : 3 * 44100]) > 0.1 and rms(electric[:, : 3 * 44100]) < 0.01
    assert rms(electric[:, -3 * 44100 :]) > 0.1 and rms(acoustic[:, -3 * 44100 :]) < 0.01
    report = json.loads(song.path("guitar_split.json").read_text())
    assert report[ACOUSTIC]["seconds"] == report[ELECTRIC]["seconds"] == 4.0
    assert [seg["label"] for seg in report["segments"]] == [ACOUSTIC, ELECTRIC]
    assert timbre.seen == 8


def test_silent_windows_are_not_classified(config, song):
    guitar_stem(song, seconds=6.0, quiet_from=2.0)
    config.stages["guitar_split"] = {"smooth": 1}
    timbre = FakeTimbre()
    GuitarSplit(config, timbre=timbre).run(song)
    report = json.loads(song.path("guitar_split.json").read_text())
    assert timbre.seen == 3  # ~2,5 s com som (a janela de 2 s pega o fim da nota)
    assert report["segments"][-1]["label"] is None


def test_silent_stem(config, song):
    audio.write(song.path("stems", "guitar.flac"), np.zeros((2, 44100), dtype=np.float32), 44100)
    timbre = FakeTimbre()
    GuitarSplit(config, timbre=timbre).run(song)
    assert timbre.seen == 0
    report = json.loads(song.path("guitar_split.json").read_text())
    assert report[ACOUSTIC]["seconds"] == report[ELECTRIC]["seconds"] == 0


def test_classifier_from_config(config, monkeypatch):
    built = []
    monkeypatch.setitem(gs.CLASSIFIERS, "falso", lambda opts: built.append(opts) or FakeTimbre())
    config.stages["guitar_split"] = {"classifier": "falso"}
    stage = GuitarSplit(config)
    assert stage.timbre() is stage.timbre()
    assert built[0]["models_dir"] == str(config.paths.state / "models")
    config.stages["guitar_split"] = {"classifier": "nenhum"}
    with pytest.raises(ValueError, match="classifier inválido"):
        GuitarSplit(config).timbre()


def test_default_classifier_builds_panns(config, monkeypatch):
    from pbq.models import panns

    made = []
    monkeypatch.setattr(panns, "PannsGuitarTimbre", lambda **kw: made.append(kw) or FakeTimbre())
    GuitarSplit(config).timbre()
    assert made[0]["device"] == "cpu" and made[0]["models_dir"] == config.paths.state / "models"
