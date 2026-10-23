from __future__ import annotations

from collections.abc import Callable
from itertools import pairwise
from pathlib import Path
from typing import Any

import numpy as np

from pbq import audio
from pbq.config import Config
from pbq.fsutil import write_json
from pbq.manifest import Song
from pbq.models import BeatTracker
from pbq.stages.base import Progress, Stage, no_progress

BEATMAP = "beatmap.json"
BEATMAP_VERSION = 1


def _beat_this(opts: dict[str, Any]) -> BeatTracker:
    from pbq.models.beat_this import BeatThisTracker

    return BeatThisTracker(
        checkpoint=str(opts.get("checkpoint", "final0")), device=str(opts.get("device", "cpu"))
    )


TRACKERS: dict[str, Callable[[dict[str, Any]], BeatTracker]] = {"beat_this": _beat_this}


def beat_energy(signal: audio.Audio, rate: int, beats: list[float]) -> list[float]:
    """Energia (RMS) da mixagem em cada batida, de 0 a 1 (1 = a batida mais forte da música).

    Alimenta o fundo animado do jogo junto com o analisador de espectro em tempo real.
    """
    if not beats:
        return []
    edges = [*beats, beats[-1] + (beats[-1] - beats[-2] if len(beats) > 1 else 0.5)]
    values = []
    for a, b in pairwise(edges):
        seg = signal[int(a * rate) : max(int(b * rate), int(a * rate) + 1)]
        values.append(float(np.sqrt(np.mean(seg.astype(np.float64) ** 2))) if len(seg) else 0.0)
    peak = max(values) or 1.0
    return [round(v / peak, 3) for v in values]


class Beats(Stage):
    """Batidas, tempos fortes e energia por batida: a grade de todos os charts.

    Entrada: MP3 original (a mixagem completa tem mais pistas rítmicas que um stem)
    Saída:   beatmap.json {version, beats, downbeats, bpm (mediano), energy (por batida, 0-1)}
    Config:  tracker (beat_this), checkpoint (final0), device
    """

    name = "beats"
    summary = "batidas, tempos fortes e energia por batida (beat_this)"
    requires = ("ingest",)

    def __init__(self, config: Config, tracker: BeatTracker | None = None):
        super().__init__(config)
        self._tracker = tracker

    def outputs(self, song: Song) -> list[Path]:
        return [song.path(BEATMAP)]

    def tracker(self) -> BeatTracker:
        if self._tracker is None:
            name = str(self.opts.get("tracker", "beat_this"))
            if name not in TRACKERS:
                raise ValueError(f"tracker inválido: {name!r} (use {', '.join(TRACKERS)})")
            self._tracker = TRACKERS[name](self.opts)
        return self._tracker

    def run(self, song: Song, progress: Progress = no_progress) -> None:
        tracker = self.tracker()
        signal = audio.mono(audio.decode(Path(song.source), tracker.sample_rate, channels=1))
        progress(0.1)
        beats, downbeats = tracker.track(signal)
        if len(beats) < 2:
            raise ValueError(f"só {len(beats)} batida(s) detectada(s): sem andamento para montar a grade")
        progress(0.9)
        write_json(
            song.path(BEATMAP),
            {
                "version": BEATMAP_VERSION,
                "beats": [round(b, 4) for b in beats],
                "downbeats": [round(d, 4) for d in downbeats],
                "bpm": round(60.0 / float(np.median(np.diff(beats))), 2),
                "energy": beat_energy(signal, tracker.sample_rate, beats),
            },
        )
