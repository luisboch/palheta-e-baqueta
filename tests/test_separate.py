import numpy as np
import pytest

from pbq import audio
from pbq.manifest import Song
from pbq.models import demucs as demucs_model
from pbq.stages import separate
from pbq.stages.separate import STEMS, Separate
from tests.fakes import FakeSeparator


def song(config):
    path = config.paths.input / "a.mp3"
    path.write_bytes(b"mp3 qualquer: o separador falso nem le")
    return Song.open(path, config.paths.work)


def test_writes_all_stems_with_progress(config):
    s = song(config)
    sep = FakeSeparator(seconds=0.5)
    seen = []
    stage = Separate(config, separator=sep)
    stage.run(s, seen.append)
    for name in STEMS:
        wav = audio.decode(s.path("stems", f"{name}.flac"), 44100)
        assert wav.shape == (2, 22050)
    assert seen[0] == pytest.approx(0.475) and seen[-1] == pytest.approx(1.0)
    assert seen == sorted(seen)
    assert stage.is_done(s) is False  # só o pipeline marca como feita
    s.mark("separate", "done", Separate.version)
    assert stage.is_done(s)


def test_model_without_guitar_is_refused(config):
    sep = FakeSeparator()
    sep.stems = ("drums", "bass", "vocals", "other")
    with pytest.raises(ValueError, match="htdemucs_6s"):
        Separate(config, separator=sep).run(song(config))


def test_engine_from_config(config, monkeypatch):
    built = []
    monkeypatch.setitem(separate.ENGINES, "falso", lambda opts: built.append(opts) or FakeSeparator())
    config.stages["separate"] = {"engine": "falso", "model": "x"}
    stage = Separate(config)
    assert stage.separator() is stage.separator()  # criado uma vez e reaproveitado
    assert built == [{"engine": "falso", "model": "x"}]
    config.stages["separate"] = {"engine": "nenhum"}
    with pytest.raises(ValueError, match="engine inválido"):
        Separate(config).separator()


def test_default_engine_builds_demucs_adapter(config, monkeypatch):
    made = []

    class Fake:
        def __init__(self, **kwargs):
            made.append(kwargs)

    monkeypatch.setattr(demucs_model, "DemucsSeparator", Fake)
    config.stages["separate"] = {"shifts": 2}
    Separate(config).separator()
    assert made == [{"model": "htdemucs_6s", "device": "cpu", "shifts": 2}]


def test_demucs_progress_math():
    """Fração = (modelo × shifts + shift) × duração + posição, sobre o total (sem torch)."""
    sep = object.__new__(demucs_model.DemucsSeparator)
    sep._shifts = 2
    seen = []
    sep._progress = seen.append
    base = {"models": 1, "model_idx_in_bag": 0, "audio_length": 100}
    sep._on_chunk({**base, "state": "start", "shift_idx": 0, "segment_offset": 0})
    sep._on_chunk({**base, "state": "end", "shift_idx": 0, "segment_offset": 50})
    sep._on_chunk({**base, "state": "end", "shift_idx": 1, "segment_offset": 50})
    assert seen == [0.25, 0.75]
    assert np.isclose(seen[-1], 0.75)
