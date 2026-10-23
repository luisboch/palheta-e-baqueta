"""Bateria transcrita (tempos por peça) → notas do chart Muito difícil (Expert).

Lanes do Clone Hero com "pro drums" (4 pads + bumbo; ADR 0007):
    0 bumbo · 1 caixa (vermelho) · 2 chimbal (amarelo, prato) · 3 tons (azul) · 4 pratos (verde, prato)
Os pratos levam a marca de prato da cor (66 amarelo, 68 verde): o jogo desenha prato, não pad.
"""

from __future__ import annotations

from collections import defaultdict
from collections.abc import Iterable, Mapping, Sequence

from pbq.charts.model import Note
from pbq.charts.quantize import SUBDIVISIONS, quantize
from pbq.charts.tempo import TempoMap

KICK, RED, YELLOW, BLUE, GREEN = 0, 1, 2, 3, 4
CYMBAL_FLAG = {YELLOW: 66, BLUE: 67, GREEN: 68}
# Peça do ADTOF → (lane, é prato?)
LANES = {
    "kick": (KICK, False),
    "snare": (RED, False),
    "hihat": (YELLOW, True),
    "tom": (BLUE, False),
    "cymbal": (GREEN, True),
}
# Duas mãos: com 3+ pads no mesmo instante, ficam os mais importantes para o groove.
HAND_PRIORITY = (RED, GREEN, YELLOW, BLUE)
MAX_HANDS = 2


def drum_notes(
    hits: Mapping[str, Iterable[float]], tempo_map: TempoMap, subdivisions: Sequence[int] = SUBDIVISIONS
) -> list[Note]:
    """Notas Expert: cada ataque na grade, uma nota por lane e tick, no máximo 2 pads por vez."""
    at: dict[int, set[int]] = defaultdict(set)
    cymbals: set[tuple[int, int]] = set()
    for piece, times in hits.items():
        lane, is_cymbal = LANES[piece]
        for t in times:
            tick = quantize(float(t), tempo_map, subdivisions)
            at[tick].add(lane)
            if is_cymbal:
                cymbals.add((tick, lane))
    notes: list[Note] = []
    for tick, lanes in sorted(at.items()):
        hands = [lane for lane in HAND_PRIORITY if lane in lanes][:MAX_HANDS]
        keep = ([KICK] if KICK in lanes else []) + hands
        for lane in sorted(keep):
            notes.append(Note(tick, lane))
            if (tick, lane) in cymbals:
                notes.append(Note(tick, CYMBAL_FLAG[lane]))
    return sorted(notes)
