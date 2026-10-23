from __future__ import annotations

import time
from collections.abc import Callable
from itertools import pairwise
from pathlib import Path
from typing import Any

import numpy as np

from pbq import audio
from pbq.config import Config
from pbq.fsutil import read_json, write_json
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


def _librosa(opts: dict[str, Any]) -> BeatTracker:
    from pbq.models.librosa_beats import LibrosaTracker

    return LibrosaTracker()


TRACKERS: dict[str, Callable[[dict[str, Any]], BeatTracker]] = {"beat_this": _beat_this, "librosa": _librosa}
# Depois de uma falha ao carregar o rastreador principal, quanto esperar para tentar de novo:
# o worker passa por todas as músicas a cada volta, e o servidor do beat_this pode ficar horas fora.
RETRY_SECONDS = 30 * 60


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

    Rastreador principal (`tracker`, beat_this) com reserva (`fallback`, librosa) quando ele não
    carrega (servidor dos pesos fora, sem internet). O beatmap.json registra quem gerou as
    batidas; uma grade da reserva não conta como "feita" quando o principal volta a carregar,
    então a música é refeita sozinha (com os charts e a biblioteca) assim que possível.

    Entrada: MP3 original (a mixagem completa tem mais pistas rítmicas que um stem)
    Saída:   beatmap.json {version, tracker, beats, downbeats, bpm (mediano), energy (0-1)}
    Config:  tracker (beat_this), fallback (librosa; "" desliga), checkpoint (final0), device
    """

    name = "beats"
    summary = "batidas, tempos fortes e energia por batida (beat_this; reserva: librosa)"
    version = 2  # 2: campo "tracker" e reserva automática
    requires = ("ingest",)

    def __init__(
        self,
        config: Config,
        tracker: BeatTracker | None = None,
        fallback: BeatTracker | None = None,
        clock: Callable[[], float] = time.monotonic,
    ):
        super().__init__(config)
        self.primary_name = str(self.opts.get("tracker", "beat_this"))
        self.fallback_name = str(self.opts.get("fallback", "librosa"))
        self._primary = tracker
        self._fallback = fallback
        self._failed_at: float | None = None
        self._clock = clock
        for name in filter(None, (self.primary_name, self.fallback_name)):
            if name not in TRACKERS:
                raise ValueError(f"tracker inválido: {name!r} (use {', '.join(TRACKERS)})")

    def outputs(self, song: Song) -> list[Path]:
        return [song.path(BEATMAP)]

    def primary(self) -> BeatTracker | None:
        """O rastreador principal, ou None se não carregou (tenta de novo a cada RETRY_SECONDS)."""
        if self._primary is None:
            now = self._clock()
            if self._failed_at is not None and now - self._failed_at < RETRY_SECONDS:
                return None
            try:
                self._primary = TRACKERS[self.primary_name](self.opts)
            except RuntimeError:
                self._failed_at = now
                return None
        return self._primary

    def tracker(self) -> tuple[str, BeatTracker]:
        """(nome, rastreador) a usar agora: o principal, ou a reserva se ele não carregou."""
        primary = self.primary()
        if primary is not None:
            return self.primary_name, primary
        if not self.fallback_name:
            raise RuntimeError(f"{self.primary_name} indisponível e sem reserva configurada")
        if self._fallback is None:
            self._fallback = TRACKERS[self.fallback_name](self.opts)
        return self.fallback_name, self._fallback

    def is_done(self, song: Song) -> bool:
        if not super().is_done(song):
            return False
        made_by = read_json(song.path(BEATMAP), {}).get("tracker")
        return made_by == self.primary_name or self.primary() is None

    def run(self, song: Song, progress: Progress = no_progress) -> None:
        name, tracker = self.tracker()
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
                "tracker": name,
                "beats": [round(b, 4) for b in beats],
                "downbeats": [round(d, 4) for d in downbeats],
                "bpm": round(60.0 / float(np.median(np.diff(beats))), 2),
                "energy": beat_energy(signal, tracker.sample_rate, beats),
            },
        )
