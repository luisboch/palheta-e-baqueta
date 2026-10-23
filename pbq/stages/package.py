from __future__ import annotations

from pathlib import Path
from typing import Any

import numpy as np

from pbq import audio
from pbq.config import Config
from pbq.fsutil import copy_atomic, read_json, tmp_path, write_json
from pbq.library import FORMAT_VERSION
from pbq.manifest import MANIFEST, Song
from pbq.stages.base import Progress, Stage, no_progress
from pbq.stages.beats import BEATMAP
from pbq.stages.chart import CHART, STREAM_FILES
from pbq.stages.presence import INSTRUMENTS
from pbq.stages.separate import STEM_DIR, STEMS

SONG_INI = "song.ini"
COVER = "cover.jpg"
SAMPLE_RATE = 44100
# Instrumento → papel do áudio (os nomes de arquivo vêm de STREAM_FILES, padrão do Clone Hero).
ROLES = {"strings": "GuitarStream", "bass": "BassStream", "drums": "DrumStream"}


def _ini(meta: dict[str, Any], present: dict[str, bool], duration: float) -> str:
    """song.ini do Clone Hero: metadados e quais instrumentos têm chart (-1 = não tem)."""

    def diff(instrument: str) -> int:
        return 3 if present.get(instrument) else -1

    lines = [
        "[song]",
        f"name = {meta.get('title') or ''}",
        f"artist = {meta.get('artist') or ''}",
        f"album = {meta.get('album') or ''}",
        "charter = Palheta & Baqueta",
        f"song_length = {int(duration * 1000)}",
        "delay = 0",
        "pro_drums = True",
        f"diff_guitar = {diff('strings')}",
        f"diff_bass = {diff('bass')}",
        f"diff_drums = {diff('drums')}",
    ]
    return "\n".join(lines) + "\n"


class Package(Stage):
    """Monta data/library/<id>/, a pasta que o jogo lê (contrato: docs/library-format.md).

    Cada instrumento presente ganha o seu áudio. O resto da música (voz, piano, outros e o stem dos
    instrumentos ausentes, que também tem som) vira o song.ogg, o fundo que toca sempre.

    Entrada: stems/*.flac, notes.chart, beatmap.json, cover.jpg, song.meta
    Saída:   library/<id>/ {song.json, notes.chart, song.ini, beatmap.json, song.ogg,
             guitar.ogg/bass.ogg/drums.ogg dos presentes, cover.jpg}
    Config:  audio_quality (Vorbis, 0-10)
    """

    name = "package"
    label = "guardando na biblioteca"
    summary = "pasta da música na biblioteca (stems em OGG, chart, mapa de batidas, song.json)"
    requires = ("presence", "chart")

    def __init__(self, config: Config):
        super().__init__(config)
        self.quality = str(self.opts.get("audio_quality", 6))

    def folder(self, song: Song) -> Path:
        return self.config.paths.library / song.id

    def outputs(self, song: Song) -> list[Path]:
        return [self.folder(song) / MANIFEST]

    def _ogg(self, path: Path, signal: audio.Audio) -> None:
        audio.write(
            path,
            np.clip(signal, -1.0, 1.0).astype(np.float32),
            SAMPLE_RATE,
            "-c:a",
            "libvorbis",
            "-q:a",
            self.quality,
        )

    def run(self, song: Song, progress: Progress = no_progress) -> None:
        out = self.folder(song)
        out.mkdir(parents=True, exist_ok=True)
        present = {k: bool(v) for k, v in song.meta.get("instruments", {}).items()}
        stems = {name: audio.decode(song.path(STEM_DIR, f"{name}.flac"), SAMPLE_RATE) for name in STEMS}
        progress(0.2)

        files: dict[str, str | None] = {}
        own = {INSTRUMENTS[i] for i in ROLES if present.get(i)}  # stems com áudio próprio
        background = sum(signal for name, signal in stems.items() if name not in own)
        assert isinstance(background, np.ndarray)
        self._ogg(out / STREAM_FILES["MusicStream"], background)
        files["song"] = STREAM_FILES["MusicStream"]
        for instrument, role in ROLES.items():
            name = STREAM_FILES[role]
            if present.get(instrument):
                self._ogg(out / name, stems[INSTRUMENTS[instrument]])
                files[instrument] = name
            else:
                (out / name).unlink(missing_ok=True)  # sobra de um processamento anterior
                files[instrument] = None
        progress(0.8)

        copy_atomic(song.path(CHART), out / CHART)
        copy_atomic(song.path(BEATMAP), out / BEATMAP)
        files["chart"], files["beatmap"] = CHART, BEATMAP
        if song.path(COVER).exists():
            copy_atomic(song.path(COVER), out / COVER)
            files["cover"] = COVER
        else:
            files["cover"] = None
        duration = float(song.meta.get("duration") or stems["other"].shape[1] / SAMPLE_RATE)
        ini = tmp_path(out / SONG_INI)
        ini.write_text(_ini(song.meta, present, duration))
        ini.replace(out / SONG_INI)
        files["ini"] = SONG_INI

        beatmap = read_json(song.path(BEATMAP), {})
        # song.json por último: pasta com song.json está completa (o jogo e o pendrive confiam nisso).
        write_json(
            out / MANIFEST,
            {
                "version": FORMAT_VERSION,
                "id": song.id,
                "title": song.meta.get("title") or Path(song.source).stem,
                "artist": song.meta.get("artist"),
                "album": song.meta.get("album"),
                "duration": round(duration, 2),
                "bpm": beatmap.get("bpm"),
                "instruments": {i: present.get(i, False) for i in INSTRUMENTS},
                "files": files,
            },
        )
