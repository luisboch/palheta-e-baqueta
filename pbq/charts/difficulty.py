"""As 4 dificuldades, por redução do Muito difícil (Expert).

Regras (só tiram notas, nunca as deslocam: o que sobra continua no tempo da música):

    Cordas/baixo   Muito difícil  tudo, 5 trastes, acordes até 3
                   Difícil        colcheias e tercinas, 5 trastes, acordes até 2
                   Médio          batidas + contratempo quando a batida está vazia, 4 trastes, sem acordes
                   Fácil          tempos fortes (1 e 3 no 4/4; 1 nos outros), 3 trastes, sem acordes
    Bateria        Muito difícil  tudo
                   Difícil        colcheias e tercinas, até 2 pads + bumbo
                   Médio          colcheias, mas pratos e chimbal só nas batidas; 1 pad + bumbo nas batidas
                   Fácil          batidas, uma peça por vez

Os trastes de cada dificuldade saem do contorno das notas que sobraram (pitched.to_notes): com
menos notas e menos botões, o desenho da melodia continua coerente.
"""

from __future__ import annotations

from collections import defaultdict
from collections.abc import Callable, Sequence
from dataclasses import dataclass

from pbq.charts import drums
from pbq.charts.model import DIFFICULTIES, Note
from pbq.charts.pitched import Event, to_notes
from pbq.charts.tempo import TimeSignature

EASY, MEDIUM, HARD, EXPERT = DIFFICULTIES


@dataclass(frozen=True)
class PitchedSpec:
    lanes: int
    max_chord: int


PITCHED = {
    EXPERT: PitchedSpec(5, 3),
    HARD: PitchedSpec(5, 2),
    MEDIUM: PitchedSpec(4, 1),
    EASY: PitchedSpec(3, 1),
}


def on_eighths(tick: int, resolution: int) -> bool:
    """Colcheia ou tercina de colcheia."""
    return tick % (resolution // 2) == 0 or tick % (resolution // 3) == 0


def strong_beats(time_signatures: Sequence[TimeSignature], end_tick: int, resolution: int) -> set[int]:
    """Ticks dos tempos fortes: o 1 de cada compasso, e o do meio em compassos pares de 4+ batidas."""
    strong: set[int] = set()
    for i, ts in enumerate(time_signatures):
        stop = time_signatures[i + 1].tick if i + 1 < len(time_signatures) else end_tick + 1
        bar = ts.beats * resolution
        accents = [0] + ([ts.beats // 2 * resolution] if ts.beats >= 4 and ts.beats % 2 == 0 else [])
        for start in range(ts.tick, stop, bar):
            strong.update(start + a for a in accents if start + a < stop)
    return strong


def select_ticks(
    ticks: Sequence[int], difficulty: str, resolution: int, time_signatures: Sequence[TimeSignature]
) -> set[int]:
    """Quais ataques (ticks) do Muito difícil ficam na dificuldade pedida."""
    present = set(ticks)
    if difficulty == EXPERT:
        return present
    if difficulty == HARD:
        return {t for t in present if on_eighths(t, resolution)}
    if difficulty == MEDIUM:
        half = resolution // 2
        return {
            t for t in present if t % resolution == 0 or (t % resolution == half and t - half not in present)
        }
    strong = strong_beats(time_signatures, max(present, default=0), resolution)
    return present & strong


def pitched_track(
    evts: Sequence[Event], difficulty: str, resolution: int, time_signatures: Sequence[TimeSignature]
) -> list[Note]:
    keep = select_ticks([e.tick for e in evts], difficulty, resolution, time_signatures)
    spec = PITCHED[difficulty]
    return to_notes([e for e in evts if e.tick in keep], spec.lanes, spec.max_chord)


# Bateria: no Fácil uma peça por instante, na ordem do que mais segura o groove.
EASY_PRIORITY = (drums.RED, drums.KICK, drums.GREEN, drums.YELLOW, drums.BLUE)
FLAGS = set(drums.CYMBAL_FLAG.values())


def drum_track(notes: Sequence[Note], difficulty: str, resolution: int) -> list[Note]:
    if difficulty == EXPERT:
        return list(notes)
    by_tick: dict[int, set[int]] = defaultdict(set)
    flags: set[tuple[int, int]] = set()
    for n in notes:
        if n.lane in FLAGS:
            flags.add((n.tick, n.lane))
        else:
            by_tick[n.tick].add(n.lane)

    rule: Callable[[int, set[int]], list[int]]
    if difficulty == HARD:

        def rule(tick: int, lanes: set[int]) -> list[int]:
            return sorted(lanes) if on_eighths(tick, resolution) else []
    elif difficulty == MEDIUM:
        # Pratos e chimbal só nas batidas: com o chimbal em colcheias, o Médio saía quase igual ao
        # Difícil (164 × 167 ataques/min em Pais e Filhos).
        def rule(tick: int, lanes: set[int]) -> list[int]:
            if not on_eighths(tick, resolution):
                return []
            on_beat = tick % resolution == 0
            allowed = [
                lane
                for lane in drums.HAND_PRIORITY
                if lane in lanes and (on_beat or lane not in drums.CYMBAL_FLAG or lane == drums.BLUE)
            ]
            pads = allowed[:1]
            kick = [drums.KICK] if drums.KICK in lanes and tick % resolution == 0 else []
            return kick + pads
    else:

        def rule(tick: int, lanes: set[int]) -> list[int]:
            if tick % resolution:
                return []
            return [lane for lane in EASY_PRIORITY if lane in lanes][:1]

    out: list[Note] = []
    for tick, lanes in sorted(by_tick.items()):
        for lane in rule(tick, lanes):
            out.append(Note(tick, lane))
            flag = drums.CYMBAL_FLAG.get(lane)
            if flag and (tick, flag) in flags:
                out.append(Note(tick, flag))
    return sorted(out)
