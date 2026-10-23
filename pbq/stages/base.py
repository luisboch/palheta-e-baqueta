from __future__ import annotations

from abc import ABC, abstractmethod
from collections.abc import Callable
from pathlib import Path
from typing import ClassVar

from pbq.config import Config, Section
from pbq.manifest import Song

# Andamento de uma etapa, de 0 a 1. O worker o transforma em eventos "progress".
Progress = Callable[[float], None]


def no_progress(fraction: float) -> None:
    pass


class Stage(ABC):
    """Uma etapa do pipeline (uma por arquivo em pbq/stages/).

    Contrato (o mesmo do kraoke, mais `version`):
    - `run()` é idempotente e só grava com escrita atômica;
    - imports pesados (torch...) só dentro de `run()`, e modelos guardados na instância;
    - `version` sobe quando a saída muda de forma (refaz a etapa nas músicas já processadas).
    """

    name: ClassVar[str]
    # Uma linha para a tabela de etapas da documentação (gerada).
    summary: ClassVar[str] = ""
    version: ClassVar[int] = 1
    # Etapas que precisam estar concluídas antes desta rodar.
    requires: ClassVar[tuple[str, ...]] = ()
    # False: uma falha não interrompe as etapas seguintes da música.
    required: ClassVar[bool] = True

    def __init__(self, config: Config):
        self.config = config
        self.opts: Section = config.stage(self.name)

    def outputs(self, song: Song) -> list[Path]:
        """Arquivos produzidos; se algum sumir, a etapa roda de novo."""
        return []

    def is_done(self, song: Song) -> bool:
        return song.stage_done(self.name, self.version) and all(p.exists() for p in self.outputs(song))

    @abstractmethod
    def run(self, song: Song, progress: Progress = no_progress) -> None:
        """Executa a etapa. Deve levantar exceção em caso de falha."""
