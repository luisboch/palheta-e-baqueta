from __future__ import annotations

from collections.abc import Callable
from pathlib import Path

from pbq import audio
from pbq.config import Config
from pbq.manifest import Song
from pbq.models import StemSeparator
from pbq.stages.base import Progress, Stage, no_progress

# Stems que as etapas seguintes esperam (os do htdemucs_6s).
STEMS = ("drums", "bass", "guitar", "piano", "vocals", "other")
STEM_DIR = "stems"


def _demucs(opts: dict[str, object]) -> StemSeparator:
    from pbq.models.demucs import DemucsSeparator

    return DemucsSeparator(
        model=str(opts.get("model", "htdemucs_6s")),
        device=str(opts.get("device", "cpu")),
        shifts=int(str(opts.get("shifts", 1))),
    )


# Motores de separação por nome (config `engine`). Outro motor = outra entrada aqui (ADR 0004).
ENGINES: dict[str, Callable[[dict[str, object]], StemSeparator]] = {"demucs": _demucs}


class Separate(Stage):
    """Separa a música em stems por instrumento.

    Entrada: MP3 original
    Saída:   stems/{drums,bass,guitar,piano,vocals,other}.flac (estéreo, taxa do modelo)
    Config:  engine (demucs), model (htdemucs_6s), device (cpu, cuda), shifts
    """

    name = "separate"
    summary = "stems por instrumento (Demucs htdemucs_6s)"
    requires = ("ingest",)

    def __init__(self, config: Config, separator: StemSeparator | None = None):
        super().__init__(config)
        self._separator = separator  # None: criado no primeiro uso e reaproveitado

    def outputs(self, song: Song) -> list[Path]:
        return [song.path(STEM_DIR, f"{name}.flac") for name in STEMS]

    def separator(self) -> StemSeparator:
        if self._separator is None:
            engine = str(self.opts.get("engine", "demucs"))
            if engine not in ENGINES:
                raise ValueError(f"engine inválido: {engine!r} (use {', '.join(ENGINES)})")
            self._separator = ENGINES[engine](self.opts)
        return self._separator

    def run(self, song: Song, progress: Progress = no_progress) -> None:
        sep = self.separator()
        missing = set(STEMS) - set(sep.stems)
        if missing:
            raise ValueError(f"o modelo não separa {', '.join(sorted(missing))} (use htdemucs_6s)")
        # A separação é ~95% do tempo da etapa; gravar os 6 FLACs, o resto.
        stems = sep.separate(Path(song.source), lambda f: progress(0.95 * f))
        for i, name in enumerate(STEMS, 1):
            audio.write(song.path(STEM_DIR, f"{name}.flac"), stems[name], sep.sample_rate)
            progress(0.95 + 0.05 * i / len(STEMS))
