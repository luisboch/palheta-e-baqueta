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
