import json

import numpy as np
import pytest

from pbq import audio
from pbq.manifest import Song
from pbq.stages.presence import Presence, Thresholds, measure
from pbq.stages.separate import STEMS
from tests.test_dsp import clicks

RATE = 22050


def notes(seconds=30.0, every=0.5, level=1.0):
    """Instrumento tocando: ataques regulares (dois por segundo = 120/min)."""
    return clicks(np.arange(0.25, seconds - 0.25, every), seconds=seconds, rate=RATE) * level


def test_playing_instrument_is_present():
    stem = notes()
    mix = stem + notes(level=0.5)  # outro instrumento junto, no mesmo ritmo
    m = measure(stem, mix, RATE, Thresholds())
    assert m.present and m.reason is None
    assert 100 < m.onsets_per_min < 140
    assert -5 < m.level_db < 0


def test_leakage_is_quiet():
    other = notes()
    leak = other * 10 ** (-30 / 20)  # o mesmo som, 30 dB abaixo: vazamento
    m = measure(leak, other + leak, RATE, Thresholds())
    assert not m.present and m.reason == "quiet"


def test_sustained_pad_has_few_onsets():
    n = int(30 * RATE)
    pad = (0.3 * np.sin(2 * np.pi * 220 * np.arange(n) / RATE)).astype(np.float32)
    pad *= np.minimum(1, np.minimum(np.arange(n), n - np.arange(n)) / (0.5 * RATE)).astype(np.float32)
    m = measure(pad, pad + notes(level=0.3), RATE, Thresholds())
    assert not m.present and m.reason == "few_onsets"


def test_silence():
    silent = np.zeros(int(5 * RATE), dtype=np.float32)
    m = measure(silent, notes(seconds=5), RATE, Thresholds())
    assert m == measure(silent, notes(seconds=5), RATE, Thresholds())
    assert not m.present and m.reason == "quiet" and m.onsets_per_min == 0


def test_thresholds_from_config():
    t = Thresholds.from_opts({"min_active": "0.3", "min_onsets": 10, "outro": "x"})
    assert (t.min_active, t.min_onsets, t.relative_db) == (0.3, 10.0, -18.0)


@pytest.fixture
def song(config):
    path = config.paths.input / "a.mp3"
    path.write_bytes(b"x")
    return Song.open(path, config.paths.work)


def test_stage_reports_each_instrument(config, song):
    seconds = 20.0
    playing = notes(seconds)
    silent = np.zeros_like(playing)
    stems = {
        "drums": playing,
        "bass": notes(seconds, every=1.0),
        "guitar": playing,
        "piano": silent,
        "vocals": notes(seconds, level=0.5),
        "other": silent,
        "electric": playing,
        "acoustic": silent,
    }
    for name, x in stems.items():
        audio.write(song.path("stems", f"{name}.flac"), np.stack([x, x]), RATE)
    assert set(STEMS) <= set(stems)

    seen = []
    Presence(config).run(song, seen.append)
    assert song.meta["instruments"] == {"drums": True, "bass": True, "guitar": True, "acoustic": False}
    report = json.loads(song.path("presence.json").read_text())
    assert report["instruments"]["acoustic"]["reason"] == "quiet"
    assert report["thresholds"]["min_onsets"] == 30.0
    assert seen[-1] == pytest.approx(1.0)
