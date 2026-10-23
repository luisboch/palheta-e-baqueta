"""Encaixe de tempos (s) na grade de batidas (ticks)."""

from __future__ import annotations

from collections.abc import Sequence

from pbq.charts.tempo import TempoMap

SUBDIVISIONS = (4, 3)  # semicolcheias e tercinas de colcheia (por batida)
# Uma subdivisão alternativa (tercina) só ganha se errar menos que esta fração do erro da
# principal: um ataque um pouco fora da semicolcheia não deve virar tercina.
ALT_BIAS = 0.5


def quantize(
    time: float, tempo_map: TempoMap, subdivisions: Sequence[int] = SUBDIVISIONS, alt_bias: float = ALT_BIAS
) -> int:
    """Tick da posição de grade mais próxima de `time`. A 1ª subdivisão é a preferida."""
    tick = tempo_map.tick(time)
    beat = tempo_map.resolution
    best_tick, best_err = 0, float("inf")
    for i, sub in enumerate(subdivisions):
        step = beat / sub
        snapped = round(round(tick / step) * step)
        err = abs(snapped - tick) / (1.0 if i == 0 else alt_bias)
        if err < best_err:
            best_tick, best_err = snapped, err
    return max(best_tick, 0)
