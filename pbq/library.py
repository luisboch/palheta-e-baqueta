"""A biblioteca (data/library/): o contrato entre backend e jogo.

Formato em docs/library-format.md (a versão citada lá é conferida contra FORMAT_VERSION).
Mudança incompatível: subir FORMAT_VERSION e atualizar o documento no mesmo commit.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from pbq.config import Config
from pbq.fsutil import write_json
from pbq.manifest import MANIFEST

FORMAT_VERSION = 1
INDEX = "index.json"
# Campos de song.json copiados para o index.json (o menu monta a lista sem abrir cada pasta).
INDEX_FIELDS = ("id", "title", "artist", "duration", "instruments")


def ready_ids(folder: Path | None) -> set[str]:
    """Músicas completas numa biblioteca (pasta com song.json)."""
    if folder is None:
        return set()
    try:
        return {d.name for d in folder.iterdir() if (d / MANIFEST).is_file()}
    except OSError:
        return set()


def write_index(config: Config) -> None:
    """Regenera library/index.json a partir dos song.json já empacotados."""
    library = config.paths.library
    songs: list[dict[str, Any]] = []
    for path in sorted(library.glob(f"*/{MANIFEST}")):
        try:
            data = json.loads(path.read_text())
        except (OSError, ValueError):
            continue  # pasta sendo apagada ou copiada neste instante
        songs.append({k: data.get(k) for k in INDEX_FIELDS})
    write_json(library / INDEX, {"version": FORMAT_VERSION, "songs": songs})
