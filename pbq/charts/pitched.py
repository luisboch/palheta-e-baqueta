"""Notas transcritas (altura e tempo) → eventos na grade → trastes por contorno melódico.

Cordas e baixo não têm "traste certo": o jogo tem 5 botões, a música tem dezenas de alturas.
O que importa para quem toca é o desenho da melodia: subiu, o traste vai para a direita; desceu,
para a esquerda; repetiu, o mesmo traste. Por isso cada evento guarda as alturas originais e os
trastes são calculados por dificuldade (`lanes`), com 3, 4 ou 5 botões.
"""

from __future__ import annotations

from collections.abc import Iterable, Sequence
from dataclasses import dataclass

import numpy as np

from pbq.charts.model import Note
from pbq.charts.quantize import SUBDIVISIONS, quantize
from pbq.charts.tempo import TempoMap


@dataclass(frozen=True)
class RawNote:
    """Uma nota como o transcritor devolve: tempos (s), altura MIDI e intensidade (0-1)."""

    start: float
    end: float
    pitch: int
    amplitude: float


@dataclass(frozen=True)
class Event:
    """Um ataque na grade: uma nota ou um acorde (alturas em ordem crescente)."""

    tick: int
    pitches: tuple[int, ...]
    length: int = 0  # ticks de sustentação

    @property
    def root(self) -> int:
        return self.pitches[0]


@dataclass(frozen=True)
class PitchedOptions:
    min_pitch: int  # extensão do instrumento (MIDI): fora disso é harmônico ou vazamento
    max_pitch: int
    max_notes: int  # notas por evento: baixo 1 (só a mais grave), Cordas até 3
    min_amplitude: float = 0.3
    min_duration: float = 0.06  # s: mais curto que isso é ruído de ataque
    chord_window: float = 0.04  # s: notas que começam juntas assim são um acorde
    sustain_beats: float = 1.0  # nota a partir de 1 batida vira sustentada


STRINGS = PitchedOptions(min_pitch=40, max_pitch=88, max_notes=3)  # E2 a E6 (violão e guitarra)
BASS = PitchedOptions(min_pitch=28, max_pitch=67, max_notes=1)  # E1 a G4


def events(
    notes: Iterable[RawNote],
    tempo_map: TempoMap,
    opts: PitchedOptions,
    subdivisions: Sequence[int] = SUBDIVISIONS,
) -> list[Event]:
    """Filtra, agrupa acordes e encaixa na grade. Eventos no mesmo tick se juntam."""
    kept = sorted(
        (
            n
            for n in notes
            if opts.min_pitch <= n.pitch <= opts.max_pitch
            and n.amplitude >= opts.min_amplitude
            and n.end - n.start >= opts.min_duration
        ),
        key=lambda n: n.start,
    )
    groups: list[list[RawNote]] = []
    for n in kept:
        if groups and n.start - groups[-1][0].start <= opts.chord_window:
            groups[-1].append(n)
        else:
            groups.append([n])

    by_tick: dict[int, tuple[set[int], float]] = {}
    for group in groups:
        tick = quantize(group[0].start, tempo_map, subdivisions)
        pitches, end = by_tick.get(tick, (set(), 0.0))
        by_tick[tick] = (pitches | {n.pitch for n in group}, max(end, *(n.end for n in group)))

    out: list[Event] = []
    ticks = sorted(by_tick)
    sustain_ticks = opts.sustain_beats * tempo_map.resolution
    for i, tick in enumerate(ticks):
        pitches, end = by_tick[tick]
        chosen = tuple(sorted(pitches)[: opts.max_notes])
        length = max(0, round(tempo_map.tick(end)) - tick)
        if i + 1 < len(ticks):  # a sustentação acaba antes do próximo ataque (folga de 1/16)
            length = min(length, ticks[i + 1] - tick - tempo_map.resolution // 4)
        out.append(Event(tick, chosen, length if length >= sustain_ticks else 0))
    return out


def contour_lanes(roots: Sequence[int], n_lanes: int, window: int = 16, min_span: int = 7) -> list[int]:
    """Traste (0 a n_lanes-1) de cada nota de referência, pelo desenho da melodia.

    1. Posição na extensão local: entre a mais grave e a mais aguda das `window` vizinhas (no
       mínimo `min_span` semitons, senão uma melodia de 2 notas pularia de ponta a ponta).
    2. Direção garantida: subiu → traste maior que o anterior; desceu → menor; igual → igual.
       Encostou na borda, fica na borda até a extensão local "abrir espaço" de novo.
    """
    if not roots:
        return []
    arr = np.asarray(roots, dtype=np.float64)
    half = window // 2
    lanes: list[int] = []
    top = n_lanes - 1
    for i, p in enumerate(arr):
        near = arr[max(0, i - half) : i + half + 1]
        lo, hi = near.min(), near.max()
        if hi - lo < min_span:
            mid = (hi + lo) / 2
            lo, hi = mid - min_span / 2, mid + min_span / 2
        lane = round((p - lo) / (hi - lo) * top)
        lane = min(max(lane, 0), top)
        if lanes:
            prev, prev_pitch = lanes[-1], arr[i - 1]
            if p > prev_pitch and lane <= prev:
                lane = min(prev + 1, top)
            elif p < prev_pitch and lane >= prev:
                lane = max(prev - 1, 0)
            elif p == prev_pitch:
                lane = prev
        lanes.append(lane)
    return lanes


def chord_lanes(root_lane: int, size: int, n_lanes: int) -> list[int]:
    """Trastes vizinhos a partir do da nota de referência; encostado à direita, o acorde recua."""
    size = min(size, n_lanes)
    start = min(root_lane, n_lanes - size)
    return list(range(start, start + size))


def to_notes(evts: Sequence[Event], n_lanes: int, max_chord: int) -> list[Note]:
    """Eventos → notas do chart com `n_lanes` trastes e acordes de até `max_chord` notas."""
    lanes = contour_lanes([e.root for e in evts], n_lanes)
    notes = []
    for event, lane in zip(evts, lanes, strict=True):
        for chord_lane in chord_lanes(lane, min(len(event.pitches), max_chord), n_lanes):
            notes.append(Note(event.tick, chord_lane, event.length))
    return notes
