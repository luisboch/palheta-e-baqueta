"""Interfaces dos modelos de IA (ADR 0006).

As etapas dependem destes Protocols, nunca do modelo concreto: os testes rápidos usam fakes,
e trocar o motor (ex.: Demucs via CLI Vulkan, ADR 0004) não mexe na etapa. Os adaptadores reais
ficam nos módulos ao lado e importam torch só quando são construídos.
"""

from __future__ import annotations

from collections.abc import Callable
from pathlib import Path
from typing import Protocol

from pbq.audio import Audio

# O mesmo tipo de pbq.stages.base.Progress, repetido aqui: importar pbq.stages daria ciclo.
Progress = Callable[[float], None]


class StemSeparator(Protocol):
    """Separa a mixagem em stems (`stems`), todos na mesma taxa e com 2 canais."""

    sample_rate: int
    stems: tuple[str, ...]

    def separate(self, path: Path, progress: Progress) -> dict[str, Audio]: ...
