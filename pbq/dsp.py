"""Medidas de sinal em numpy puro: energia por quadro e detecção de ataques (onsets).

Usadas para decidir se um instrumento toca (stages/presence.py) e, nas próximas fases, como
apoio na geração de charts. Sem librosa: o núcleo e os testes rápidos não dependem dela.
"""

from __future__ import annotations

import numpy as np
import numpy.typing as npt

from pbq.audio import Audio

Floats = npt.NDArray[np.float64]

SILENCE_DB = -120.0  # piso para log de energia zero


def to_db(power_or_amp: Floats | float, power: bool = False) -> Floats:
    x = np.maximum(np.asarray(power_or_amp, dtype=np.float64), 1e-12)
    return np.asarray(np.maximum((10 if power else 20) * np.log10(x), SILENCE_DB), dtype=np.float64)


def frame_rms(signal: Audio, frame: int, hop: int) -> Floats:
    """RMS por quadro (janelas de `frame` amostras a cada `hop`), de um sinal mono."""
    if len(signal) < frame:
        signal = np.pad(signal, (0, frame - len(signal)))
    n = 1 + (len(signal) - frame) // hop
    idx = np.arange(frame)[None, :] + hop * np.arange(n)[:, None]
    frames = signal[idx].astype(np.float64)
    return np.asarray(np.sqrt(np.mean(frames**2, axis=1)), dtype=np.float64)


BANDS = 40  # bandas log-espaçadas: suavizam o espectro como um banco mel, sem librosa
TOP_DB = 80.0  # faixa dinâmica: o que estiver mais de 80 dB abaixo do pico vira piso


def _band_edges(n_bins: int, sample_rate: int, n_fft: int, low: float = 40.0) -> npt.NDArray[np.int_]:
    high = sample_rate / 2
    freqs = np.geomspace(low, high, BANDS + 1)
    edges = np.unique(np.clip(np.round(freqs * n_fft / sample_rate).astype(int), 1, n_bins))
    return edges


# Janela de 1024 (46 ms a 22 kHz): ataques ~10 ms antes do real; a de 2048 dava ~30 ms.
N_FFT, ONSET_HOP = 1024, 256


def spectral_flux(signal: Audio, sample_rate: int, n_fft: int = N_FFT, hop: int = ONSET_HOP) -> Floats:
    """Fluxo espectral em dB por banda: média das subidas (dB) entre quadros vizinhos.

    Quadros centrados (quadro i em i * hop), espectro agrupado em bandas e em dB com piso de
    TOP_DB abaixo do pico: um som contínuo dá fluxo ~0 e um ataque dá vários dB. Por ser em dB
    absolutos, o limiar de `onsets` não depende do volume do stem nem do maior pico da música.
    """
    window = np.hanning(n_fft)
    signal = np.pad(signal, (n_fft // 2, n_fft // 2))
    if len(signal) < n_fft:
        signal = np.pad(signal, (0, n_fft - len(signal)))
    n = 1 + (len(signal) - n_fft) // hop
    idx = np.arange(n_fft)[None, :] + hop * np.arange(n)[:, None]
    power = np.abs(np.fft.rfft(signal[idx] * window, axis=1)) ** 2
    edges = _band_edges(power.shape[1], sample_rate, n_fft)
    bands = np.add.reduceat(power, edges[:-1], axis=1)[:, : len(edges) - 1]
    db = to_db(bands, power=True)
    db = np.maximum(db, db.max() - TOP_DB)
    flux = np.maximum(np.diff(db, axis=0), 0).mean(axis=1)
    return np.asarray(np.concatenate([[0.0], flux]), dtype=np.float64)


def onsets(
    signal: Audio,
    sample_rate: int,
    hop: int = ONSET_HOP,
    delta: float = 3.0,
    min_gap: float = 0.05,
    median_window: float = 0.5,
) -> Floats:
    """Tempos (s) dos ataques: picos do fluxo acima da mediana local + `delta` dB.

    Picos a menos de `min_gap` segundos do anterior são o mesmo ataque.
    """
    flux = spectral_flux(signal, sample_rate, hop=hop)
    half = max(1, int(median_window * sample_rate / hop) // 2)
    padded = np.pad(flux, half, mode="edge")
    windows = np.lib.stride_tricks.sliding_window_view(padded, 2 * half + 1)
    threshold = np.median(windows, axis=1) + delta
    is_peak = (flux > threshold) & (flux >= np.roll(flux, 1)) & (flux >= np.roll(flux, -1))
    times = np.flatnonzero(is_peak) * hop / sample_rate
    kept: list[float] = []
    for t in times:
        if not kept or t - kept[-1] >= min_gap:
            kept.append(float(t))
    return np.array(kept)
