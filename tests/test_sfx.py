"""Testa o gerador de efeitos sonoros sintéticos."""

import wave
from pathlib import Path

from tools.make_sfx import generate_error_sfx, generate_miss_sfx, main


def test_make_sfx_generates_valid_wav(tmp_path: Path) -> None:
    error_wav = tmp_path / "error.wav"
    miss_wav = tmp_path / "miss.wav"

    generate_error_sfx(error_wav)
    generate_miss_sfx(miss_wav)

    assert error_wav.exists() and error_wav.stat().st_size > 0
    assert miss_wav.exists() and miss_wav.stat().st_size > 0

    with wave.open(str(error_wav), "rb") as f:
        assert f.getnchannels() == 1
        assert f.getsampwidth() == 2
        assert f.getframerate() == 44100

    with wave.open(str(miss_wav), "rb") as f:
        assert f.getnchannels() == 1
        assert f.getsampwidth() == 2
        assert f.getframerate() == 44100


def test_main_runs_without_error(monkeypatch: object) -> None:
    main()
