"""Orquestrador: roda as etapas pendentes de uma música, em ordem."""

from __future__ import annotations

import logging
from collections.abc import Callable

from pbq.manifest import Song
from pbq.stages.base import Stage

log = logging.getLogger(__name__)

DONE, FAILED, CANCELLED = "done", "failed", "cancelled"

# Andamento da música: (etapa, fração de 0 a 1 dentro dela).
SongProgress = Callable[[str, float], None]


def process_song(
    song: Song,
    stages: list[Stage],
    force: bool = False,
    cancelled: Callable[[], bool] = lambda: False,
    progress: SongProgress = lambda stage, fraction: None,
) -> str:
    """Roda as etapas pendentes de uma música.

    Uma etapa refeita (versão nova, saída apagada, `force`) refaz também as que dependem dela:
    a saída antiga delas foi calculada sobre a entrada antiga.

    Retorna DONE, FAILED (uma etapa obrigatória falhou; detalhes em song.stages) ou
    CANCELLED (`cancelled()` ficou verdadeiro entre duas etapas).
    """
    rerun: set[str] = set()
    for stage in stages:
        if cancelled():
            return CANCELLED
        stale = rerun.intersection(stage.requires)
        if not force and not stale and stage.is_done(song):
            continue
        missing = [r for r in stage.requires if not song.stage_done(r)]
        if missing:
            log.info("   %-14s aguardando %s", stage.name, ", ".join(missing))
            continue

        log.info("   %-14s ...", stage.name)
        rerun.add(stage.name)
        progress(stage.name, 0.0)
        try:
            stage.run(song, _clamped(progress, stage.name))
            song.mark(stage.name, "done", stage.version)
            progress(stage.name, 1.0)
        except Exception as e:
            song.mark(stage.name, "failed", stage.version, f"{type(e).__name__}: {e}")
            log.warning("   %-14s falhou: %s", stage.name, e)
            if stage.required:
                return FAILED
        finally:
            song.save()
    return DONE


def _clamped(progress: SongProgress, name: str) -> Callable[[float], None]:
    def report(fraction: float) -> None:
        progress(name, min(max(fraction, 0.0), 1.0))

    return report
