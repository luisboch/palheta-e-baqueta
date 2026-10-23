"""Mapa de tempo: segundos ↔ ticks a partir das batidas detectadas.

Cada batida vale RESOLUTION ticks (192, o padrão do Clone Hero). O andamento muda a cada batida
(BPM = 60 / intervalo), então a grade acompanha o músico, inclusive quando ele acelera.

O BPM vai para o .chart como inteiro em milésimos ("B 120000"). Para o jogo e o backend
concordarem até o fim da música, os tempos aqui são calculados a partir desses valores já
arredondados: o erro de arredondamento não acumula escondido (~1 ms em 500 batidas).
"""

from __future__ import annotations

import bisect
from collections.abc import Sequence
from dataclasses import dataclass
from itertools import pairwise

RESOLUTION = 192  # ticks por batida
MIN_BEATS = 2  # com menos que isso não há andamento para medir
DEFAULT_BEATS_PER_BAR = 4  # sem tempos fortes suficientes, o compasso mais comum


@dataclass(frozen=True)
class Tempo:
    tick: int
    milli_bpm: int  # BPM × 1000, como no .chart

    @property
    def bpm(self) -> float:
        return self.milli_bpm / 1000


@dataclass(frozen=True)
class TimeSignature:
    tick: int
    beats: int  # batidas por compasso (o denominador é sempre 4 aqui)


class TempoMap:
    def __init__(self, tempos: Sequence[Tempo], resolution: int = RESOLUTION):
        if not tempos or tempos[0].tick != 0:
            raise ValueError("o mapa de tempo precisa começar no tick 0")
        self.resolution = resolution
        self.tempos = list(tempos)
        # Início (s) de cada trecho de andamento constante, acumulado com os BPMs arredondados.
        self._starts = [0.0]
        for prev, cur in zip(self.tempos, self.tempos[1:], strict=False):
            self._starts.append(self._starts[-1] + self._seconds(cur.tick - prev.tick, prev))
        self._ticks = [t.tick for t in self.tempos]
        self.lead_beats = 0  # batidas de introdução antes da 1ª batida detectada (from_beats)

    def _seconds(self, ticks: float, tempo: Tempo) -> float:
        return ticks / self.resolution * 60.0 / tempo.bpm

    def time(self, tick: float) -> float:
        i = max(0, bisect.bisect_right(self._ticks, tick) - 1)
        return self._starts[i] + self._seconds(tick - self.tempos[i].tick, self.tempos[i])

    def tick(self, time: float) -> float:
        i = max(0, bisect.bisect_right(self._starts, time) - 1)
        tempo = self.tempos[i]
        return tempo.tick + (time - self._starts[i]) * tempo.bpm / 60.0 * self.resolution

    @classmethod
    def from_beats(cls, beats: Sequence[float], resolution: int = RESOLUTION) -> TempoMap:
        """Uma batida por `resolution` ticks; antes da primeira, uma introdução que termina nela.

        A introdução (do início do áudio até a 1ª batida) dura um número inteiro de batidas no
        andamento inicial, ao menos uma; assim a grade da música inteira continua alinhada.
        """
        if len(beats) < MIN_BEATS:
            raise ValueError(f"preciso de ao menos {MIN_BEATS} batidas para medir o andamento")
        first_ibi = beats[1] - beats[0]
        lead_beats = max(1, round(beats[0] / first_ibi)) if beats[0] > 0 else 0
        tempos: list[Tempo] = []
        if lead_beats:
            tempos.append(Tempo(0, round(60_000 * lead_beats / beats[0])))
        for i in range(len(beats) - 1):
            tick = (lead_beats + i) * resolution
            tempos.append(Tempo(tick, round(60_000 / (beats[i + 1] - beats[i]))))
        tempo_map = cls(_dedupe(tempos), resolution)
        tempo_map.lead_beats = lead_beats
        return tempo_map


def _dedupe(tempos: list[Tempo]) -> list[Tempo]:
    """Tira marcas que repetem o andamento anterior (o .chart fica menor e igual em efeito)."""
    out: list[Tempo] = []
    for t in tempos:
        if not out or out[-1].milli_bpm != t.milli_bpm:
            out.append(t)
    return out


def time_signatures(
    beats: Sequence[float], downbeats: Sequence[float], resolution: int = RESOLUTION, lead_beats: int = 0
) -> list[TimeSignature]:
    """Compassos a partir dos tempos fortes: um evento a cada mudança de batidas por compasso.

    `lead_beats`: batidas de introdução antes da primeira batida detectada (TempoMap.from_beats).
    O que vem antes do primeiro tempo forte e não fecha um compasso inteiro vira um compasso
    curto no início (anacruse): assim as linhas de compasso do jogo caem nos tempos fortes.
    """
    beat_index = {round(b, 4): i for i, b in enumerate(beats)}
    idx = [lead_beats + beat_index[round(d, 4)] for d in downbeats if round(d, 4) in beat_index]
    if len(idx) < 2:
        return [TimeSignature(0, DEFAULT_BEATS_PER_BAR)]
    first_bar = idx[1] - idx[0]
    remainder = idx[0] % first_bar
    out = [TimeSignature(0, remainder)] if remainder else []
    out.append(TimeSignature(remainder * resolution, first_bar))
    for a, b in pairwise(idx[1:]):
        if b - a != out[-1].beats:
            out.append(TimeSignature(a * resolution, b - a))
    return out
