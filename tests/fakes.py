"""Etapas falsas para testar pipeline e worker sem modelos nem áudio."""

import json

from pbq.manifest import Song
from pbq.stages.base import Progress, Stage, no_progress


class Touch(Stage):
    name = "touch"
    summary = "etapa de teste"

    def outputs(self, song: Song):
        return [song.path("touched")]

    def run(self, song: Song, progress: Progress = no_progress) -> None:
        for i in range(1, 4):
            progress(i / 4)
        song.path("touched").parent.mkdir(parents=True, exist_ok=True)
        song.path("touched").write_text("x")


class Publish(Stage):
    """Faz o papel do package: a música fica "completa" quando esta etapa está feita."""

    name = "publish"
    requires = ("touch",)

    def outputs(self, song: Song):
        return [self.config.paths.library / song.id / "song.json"]

    def run(self, song: Song, progress: Progress = no_progress) -> None:
        out = self.config.paths.library / song.id
        out.mkdir(parents=True, exist_ok=True)
        (out / "song.json").write_text(json.dumps({"id": song.id, "title": song.label}))


class Boom(Stage):
    name = "boom"

    def run(self, song: Song, progress: Progress = no_progress) -> None:
        raise RuntimeError("falhou de propósito")


class Optional(Stage):
    name = "optional"
    required = False

    def run(self, song: Song, progress: Progress = no_progress) -> None:
        raise RuntimeError("opcional falhou")


class FakeSeparator:
    """StemSeparator falso: cada stem é um tom sintético (ou silêncio, se pedido)."""

    sample_rate = 44100
    stems = ("drums", "bass", "guitar", "piano", "vocals", "other")

    def __init__(self, seconds: float = 2.0, silent: tuple[str, ...] = ()):
        self.seconds = seconds
        self.silent = silent
        self.calls = 0

    def separate(self, path, progress):
        import numpy as np

        self.calls += 1
        progress(0.5)
        n = int(self.seconds * self.sample_rate)
        t = np.arange(n) / self.sample_rate
        out = {}
        for i, name in enumerate(self.stems):
            tone = 0.0 if name in self.silent else 0.2 * np.sin(2 * np.pi * (110 * (i + 1)) * t)
            out[name] = np.stack([tone * np.ones(n), tone * np.ones(n)]).astype(np.float32)
        progress(1.0)
        return out
