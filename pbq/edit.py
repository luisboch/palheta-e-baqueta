"""Corrige título e artista de uma música pronta (menu do jogo → Editar).

A correção vale em todos os arquivos que mostram o nome: song.json, notes.chart, song.ini e o
index.json da biblioteca. Se a música tem pasta de trabalho, a correção também fica gravada no
estado dela (`meta["edited"]`): reprocessar não volta ao nome adivinhado pelo ingest.
"""

from __future__ import annotations

import re
from pathlib import Path

from pbq.charts.chart_file import quote
from pbq.config import Config
from pbq.fsutil import read_json, tmp_path, write_json
from pbq.library import write_index
from pbq.manifest import MANIFEST, Song

CHART_FIELDS = {"Name": "title", "Artist": "artist"}  # [Song] do .chart → campo editado
INI_FIELDS = {"name": "title", "artist": "artist"}


def _rewrite(path: Path, pattern: re.Pattern[str], values: dict[str, str]) -> None:
    """Troca o valor das linhas `chave = ...` (as que `pattern` reconhece), mantendo o resto."""
    if not path.exists():
        return
    raw = path.read_bytes().decode("utf-8")  # bytes: o .chart é CRLF e precisa continuar

    def replace(match: re.Match[str]) -> str:
        return f"{match['lead']}{match['key']} = {values[match['key']]}"

    tmp = tmp_path(path)
    tmp.write_bytes(pattern.sub(replace, raw).encode("utf-8"))
    tmp.replace(path)


def edit_song(config: Config, song_id: str, title: str, artist: str | None) -> None:
    """Grava `title` e `artist` (vazio = sem artista). LookupError se a música não está pronta."""
    title = title.strip()
    artist = (artist or "").strip() or None
    if not title:
        raise ValueError("o título não pode ficar vazio")
    folder = config.paths.library / song_id
    manifest = read_json(folder / MANIFEST, None)
    if not isinstance(manifest, dict):
        raise LookupError(f"música não encontrada na biblioteca: {song_id}")

    edited = {"title": title, "artist": artist}
    chart_values = {k: quote(edited[v] or "") for k, v in CHART_FIELDS.items()}
    _rewrite(
        folder / "notes.chart",
        re.compile(r"^(?P<lead>\s*)(?P<key>Name|Artist) = .*?(?=\r?$)", re.M),
        chart_values,
    )
    ini_values = {k: edited[v] or "" for k, v in INI_FIELDS.items()}
    _rewrite(folder / "song.ini", re.compile(r"^(?P<lead>)(?P<key>name|artist) = .*$", re.M), ini_values)
    write_json(folder / MANIFEST, {**manifest, **edited})  # por último, como no package
    write_index(config)

    work = config.paths.work / song_id
    if (work / MANIFEST).exists():
        song = Song.load(work)
        song.meta.update(edited, edited=edited)
        song.save()
