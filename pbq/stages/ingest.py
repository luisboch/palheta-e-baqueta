from __future__ import annotations

import re
from pathlib import Path
from typing import Any

from mutagen.mp3 import MP3

from pbq.ffmpeg import ffmpeg_to
from pbq.manifest import Song
from pbq.stages.base import Progress, Stage, no_progress
from pbq.titles import parse_title, parse_youtube_music

URL = re.compile(r"^https?://", re.I)


class Ingest(Stage):
    """Lê os metadados e a capa do MP3 (o mesmo do kraoke).

    O áudio não é convertido: as etapas seguintes leem o MP3 original direto.
    Artista/música vêm do TIT2 (título de vídeo, heurístico) ou, em faixas do YouTube Music,
    da descrição automática ("Música · Artista"), que vale mais.

    Entrada: song.source (MP3 original, nunca é modificado)
    Saída:   cover.jpg, se o MP3 tiver capa embutida
             song.meta: title, artist, featuring, live, medley, album, duration, cover...
    """

    name = "ingest"
    label = "lendo a música"
    summary = "metadados (artista, música, duração) e capa"

    def run(self, song: Song, progress: Progress = no_progress) -> None:
        src = Path(song.source)
        audio: Any = MP3(src)  # type: ignore[no-untyped-call]  # mutagen não é tipado
        tags: Any = audio.tags or {}

        # Em MP3s vindos de vídeo, TIT2 costuma ser "Artista - Música (...)" e TPE1 o canal.
        raw = str(tags["TIT2"]) if "TIT2" in tags else src.stem
        if URL.match(raw.strip()):
            raw = src.stem  # alguns downloaders gravam o link do vídeo no título
        uploader = str(tags["TPE1"]) if "TPE1" in tags else ""
        song.meta.update(parse_title(raw, uploader))
        official = parse_youtube_music(str(tags.get("TXXX:description", "")))
        if official:
            parsed = parse_title(official["title"])
            song.meta.update(
                parsed,
                artist=official["artist"],
                title_raw=raw,
                query=f"{official['artist']} {parsed['title']}",
                uploader=uploader or None,
            )
        song.meta.update(song.meta.get("edited") or {})  # corrigido no menu (pbq edit) vence
        song.meta["album"] = str(tags["TALB"]) if "TALB" in tags else None
        song.meta["duration"] = round(audio.info.length, 2)

        has_cover = any(k.startswith("APIC") for k in tags.keys())  # noqa: SIM118 (tags do mutagen)
        if has_cover:
            ffmpeg_to(song.path("cover.jpg"), "-i", src, "-map", "0:v:0", "-frames:v", "1", "-q:v", "3")
        song.meta["cover"] = has_cover
