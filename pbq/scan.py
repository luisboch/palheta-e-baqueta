"""Encontra os MP3s de data/input prontos para processar (o mesmo do kraoke).

- Cache de hash por (caminho, tamanho, mtime) em data/work/.scan-cache.json, para não reler
  todos os arquivos a cada volta do laço.
- Arquivo novo só é entregue quando o tamanho se repete em duas voltas seguidas, para não
  pegar um MP3 que ainda está sendo copiado.
- Ignora cópias temporárias (".tmp.*") e o mesmo MP3 em dois lugares.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

from pbq.config import Config
from pbq.fsutil import TMP_PREFIX, read_json, write_json
from pbq.manifest import Song, song_id

CACHE = ".scan-cache.json"


class Scanner:
    def __init__(self, config: Config):
        self.config = config
        self.cache_path = config.paths.work / CACHE
        self.cache: dict[str, dict[str, Any]] = read_json(self.cache_path, {})
        self._last_sizes: dict[str, int] = {}

    def scan(self) -> list[Song]:
        """MP3s estáveis, como Song (cria o manifesto se for novo)."""
        songs, seen, sizes = [], set(), {}
        dirty = False

        for path in sorted(self.config.paths.input.rglob("*")):
            if path.suffix.lower() != ".mp3" or path.name.startswith(TMP_PREFIX) or not path.is_file():
                continue
            key = str(path)
            st = path.stat()
            sizes[key] = st.st_size

            entry = self.cache.get(key)
            if entry and entry["size"] == st.st_size and entry["mtime"] == st.st_mtime:
                sid = entry["id"]
            elif self._last_sizes.get(key) == st.st_size:
                sid = song_id(path)
                self.cache[key] = {"size": st.st_size, "mtime": st.st_mtime, "id": sid}
                dirty = True
            else:
                continue  # novo ou ainda crescendo: espera a próxima volta

            if sid in seen:
                continue
            seen.add(sid)
            songs.append(Song.open(path, self.config.paths.work, sid=sid))

        gone = [k for k in self.cache if k not in sizes]
        for k in gone:
            del self.cache[k]
        if dirty or gone:
            write_json(self.cache_path, self.cache)
        self._last_sizes = sizes
        return songs

    def input_ids(self) -> set[str]:
        """Ids dos MP3s de input que existem agora (segundo o cache)."""
        return {e["id"] for path, e in self.cache.items() if Path(path).exists()}
