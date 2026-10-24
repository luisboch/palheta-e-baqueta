"""As 4 dificuldades, por redução do que o transcritor achou (100% dos ataques).

Regras (só tiram notas, nunca as deslocam: o que sobra continua no tempo da música):

    Referência     colcheias e tercinas da transcrição (100%, que nenhum nível usa inteira)
    Muito difícil  80% da referência
    Difícil        70% da referência
    Médio          Cordas/baixo: batidas + contratempo quando a batida está vazia, 4 trastes, sem acordes
                   Bateria: colcheias, mas pratos e chimbal só nas batidas; 1 pad + bumbo nas batidas
    Fácil          Cordas/baixo: batidas (só os ataques que caem nelas), 3 trastes, sem acordes
                   Bateria: batidas, uma peça por vez

A referência já descarta as semicolcheias. Depois, Muito difícil e Difícil perdem primeiro os
ataques de pulso mais fraco (tercinas, depois contratempos) e, dentro do mesmo pulso, um a cada
tantos, espalhados pela música toda. A parcela é a mesma em qualquer andamento (ADR 0020).
Cordas/baixo: 5 trastes, acordes até 3 no Muito difícil e 2 no Difícil; bateria: até 2 pads + bumbo.

Os trastes de cada dificuldade saem do contorno das notas que sobraram (pitched.to_notes): com
menos notas e menos botões, o desenho da melodia continua coerente.
"""

from __future__ import annotations

from collections import defaultdict
from collections.abc import Callable, Iterable, Sequence
from dataclasses import dataclass

from pbq.charts import drums
from pbq.charts.model import DIFFICULTIES, Note
from pbq.charts.pitched import Event, to_notes

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


# Parcela da referência (colcheias e tercinas da transcrição) que cada nível alto mantém (ADR 0020).
EXPERT_SHARE = 0.8
HARD_SHARE = 0.7


def pulse_level(tick: int, resolution: int) -> int:
    """Quão forte é o pulso do tick: 0 batida, 1 colcheia, 2 tercina, 3 o resto (semicolcheias...)."""
    if tick % resolution == 0:
        return 0
    if tick % (resolution // 2) == 0:
        return 1
    if tick % (resolution // 3) == 0:
        return 2
    return 3


def thin(ticks: Iterable[int], share: float, resolution: int) -> set[int]:
    """Fica com `share` dos ataques: os de pulso mais forte primeiro; no último nível a caber,
    um subconjunto espaçado por igual (cortar do fim apagaria o final da música)."""
    ordered = sorted(set(ticks))
    quota = round(len(ordered) * share)
    kept: set[int] = set()
    for level in range(4):
        group = [t for t in ordered if pulse_level(t, resolution) == level]
        room = quota - len(kept)
        if room >= len(group):
            kept.update(group)
        else:
            kept.update(group[(2 * i + 1) * len(group) // (2 * room)] for i in range(room))
            break
    return kept


def select_ticks(ticks: Sequence[int], difficulty: str, resolution: int) -> set[int]:
    """Quais ataques (ticks) transcritos ficam na dificuldade pedida (ADR 0020)."""
    present = set(ticks)
    if difficulty in (EXPERT, HARD):
        reference = {t for t in present if on_eighths(t, resolution)}
        expert = thin(reference, EXPERT_SHARE, resolution)
        # O Difícil sai do Muito difícil (nunca tem ataque que o de cima não tenha).
        return expert if difficulty == EXPERT else thin(expert, HARD_SHARE / EXPERT_SHARE, resolution)
    if difficulty == MEDIUM:
        half = resolution // 2
        return {
            t for t in present if t % resolution == 0 or (t % resolution == half and t - half not in present)
        }
    # Só os tempos fortes (1 e 3) deixavam o Fácil quase parado; em toda batida ele fica a meio
    # caminho do Médio, que soma os contratempos.
    return {t for t in present if t % resolution == 0}


def pitched_track(evts: Sequence[Event], difficulty: str, resolution: int) -> list[Note]:
    keep = select_ticks([e.tick for e in evts], difficulty, resolution)
    spec = PITCHED[difficulty]
    return to_notes([e for e in evts if e.tick in keep], spec.lanes, spec.max_chord)


# Bateria: no Fácil uma peça por instante, na ordem do que mais segura o groove.
EASY_PRIORITY = (drums.RED, drums.KICK, drums.GREEN, drums.YELLOW, drums.BLUE)
FLAGS = set(drums.CYMBAL_FLAG.values())


def drum_track(notes: Sequence[Note], difficulty: str, resolution: int) -> list[Note]:
    by_tick: dict[int, set[int]] = defaultdict(set)
    flags: set[tuple[int, int]] = set()
    for n in notes:
        if n.lane in FLAGS:
            flags.add((n.tick, n.lane))
        else:
            by_tick[n.tick].add(n.lane)

    rule: Callable[[int, set[int]], list[int]]
    if difficulty in (EXPERT, HARD):
        kept = select_ticks(list(by_tick), difficulty, resolution)

        def rule(tick: int, lanes: set[int]) -> list[int]:
            return sorted(lanes) if tick in kept else []
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
