import numpy as np
import pytest

from pbq import audio, dsp

RATE = 22050


def clicks(times, seconds=4.0, rate=RATE, freq=1000.0):
    """Ataques curtos (seno com decaimento) nos instantes pedidos."""
    out = np.zeros(int(seconds * rate), dtype=np.float32)
    n = int(0.08 * rate)
    env = np.exp(-np.arange(n) / (0.01 * rate))
    tone = (np.sin(2 * np.pi * freq * np.arange(n) / rate) * env).astype(np.float32)
    for t in times:
        i = int(t * rate)
        out[i : i + n] += tone[: len(out) - i]
    return out


def test_onsets_find_each_attack():
    times = [0.5, 1.0, 1.5, 2.25, 3.0]
    found = dsp.onsets(clicks(times), RATE)
    assert len(found) == len(times)
    assert np.allclose(found, times, atol=0.02)


def test_onsets_of_silence_and_steady_tone():
    assert len(dsp.onsets(np.zeros(RATE, dtype=np.float32), RATE)) == 0
    n = 2 * RATE
    fade = np.minimum(1, np.minimum(np.arange(n), n - np.arange(n)) / (0.2 * RATE))
    tone = (np.sin(2 * np.pi * 440 * np.arange(n) / RATE) * fade).astype(np.float32)
    assert len(dsp.onsets(tone, RATE)) <= 1  # no máximo a entrada do som


def test_frame_rms_and_db():
    signal = np.ones(1000, dtype=np.float32) * 0.5
    rms = dsp.frame_rms(signal, 100, 50)
    assert len(rms) == 19 and np.allclose(rms, 0.5)
    assert len(dsp.frame_rms(np.ones(10, dtype=np.float32), 100, 50)) == 1  # curto: preenchido
    assert dsp.to_db(1.0) == pytest.approx(0.0)
    assert dsp.to_db(0.0) == dsp.SILENCE_DB
    assert dsp.to_db(0.01, power=True) == pytest.approx(-20.0)


def test_audio_roundtrip(tmp_path):
    stereo = np.stack([np.linspace(-0.5, 0.5, 4410), np.zeros(4410)]).astype(np.float32)
    path = tmp_path / "x.flac"
    audio.write(path, stereo, 44100)
    back = audio.decode(path, 44100)
    assert back.shape == (2, 4410)
    assert np.allclose(back, stereo, atol=1e-3)
    assert audio.sample_rate(path) == 44100
    assert audio.mono(back).shape == (4410,)
    assert audio.mono(back[0]).shape == (4410,)  # já mono: igual
    assert not list(tmp_path.glob(".tmp.*"))


def test_audio_errors(tmp_path):
    with pytest.raises(RuntimeError, match="ffmpeg falhou"):
        audio.decode(tmp_path / "nao.flac", 44100)
    with pytest.raises(RuntimeError, match="ffprobe falhou"):
        audio.sample_rate(tmp_path / "nao.flac")
    with pytest.raises(RuntimeError, match="ffmpeg falhou"):
        audio.write(tmp_path / "x.flac", np.zeros((2, 10), dtype=np.float32), 44100, "-c:a", "inexistente")
    assert list(tmp_path.iterdir()) == []
