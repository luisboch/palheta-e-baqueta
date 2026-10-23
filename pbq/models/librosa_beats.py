"""Batidas pela librosa (ISC): a reserva quando o beat_this não carrega (ADR 0013).

Pior que o beat_this: às vezes dobra ou corta o andamento pela metade, e não detecta tempos
fortes. Eles são estimados aqui supondo compasso de 4: das 4 fases possíveis, fica a que tem
mais grave (o bumbo costuma cair no 1).
"""

from __future__ import annotations

import numpy as np

from pbq.audio import Audio

SAMPLE_RATE = 22050
BEATS_PER_BAR = 4
LOW_HZ = 150  # abaixo disso: bumbo e baixo, que marcam o 1 do compasso


class LibrosaTracker:
    sample_rate = SAMPLE_RATE

    def __init__(self) -> None:
        import librosa

        self._librosa = librosa

    def track(self, signal: Audio) -> tuple[list[float], list[float]]:
        librosa = self._librosa
        _, frames = librosa.beat.beat_track(y=signal, sr=SAMPLE_RATE)
        beats = [float(t) for t in librosa.frames_to_time(frames, sr=SAMPLE_RATE)]
        spec = np.abs(librosa.stft(signal))
        freqs = librosa.fft_frequencies(sr=SAMPLE_RATE)
        low = spec[freqs < LOW_HZ].sum(axis=0)
        frame_of = librosa.time_to_frames(beats, sr=SAMPLE_RATE)
        strength = low[np.minimum(frame_of, len(low) - 1)] if len(beats) else np.array([])
        return beats, downbeats(beats, strength)


def downbeats(beats: list[float], strength: np.ndarray, per_bar: int = BEATS_PER_BAR) -> list[float]:
    """Tempos fortes: a fase (0 a per_bar-1) cujas batidas somam mais `strength`."""
    if not beats:
        return []
    phase = int(np.argmax([strength[p::per_bar].sum() for p in range(min(per_bar, len(beats)))]))
    return beats[phase::per_bar]
