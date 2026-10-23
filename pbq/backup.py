"""Biblioteca no pendrive: salvar as músicas prontas e importá-las em outro computador.

Portado do kraoke. No pendrive: <montagem>/palheta/library/<id>/, com os mesmos arquivos de
data/library/<id>/ (só os listados em `files` do song.json, mais o próprio song.json). Quem
importa não reprocessa nada: processar num PC com GPU e jogar no Deck.

- Salvar é incremental: copia só o que falta ou mudou (tamanho diferente, ou o conteúdo de um
  .json). Nada é apagado no pendrive.
- Importar traz as músicas cujo id não está na biblioteca.
- Cada arquivo vai para um temporário e é renomeado, com o song.json por último: pasta com
  song.json está completa, mesmo se o pendrive for removido no meio.
- Importar recusa `version` maior que a nossa (biblioteca de um Palheta & Baqueta mais novo).
"""

from __future__ import annotations

import json
import os
from collections.abc import Callable
from dataclasses import dataclass, field
from pathlib import Path

from pbq.config import Config
from pbq.drive import Progress, library_dir
from pbq.fsutil import check_space, copy_atomic
from pbq.library import FORMAT_VERSION, ready_ids, write_index
from pbq.manifest import MANIFEST


@dataclass
class SongCopy:
    song_id: str
    files: list[tuple[Path, Path]] = field(default_factory=list)  # (origem, destino), song.json por último

    @property
    def size(self) -> int:
        return sum(src.stat().st_size for src, _ in self.files)


def export_library(config: Config, mount: Path, progress: Progress | None = None) -> int:
    """Salva no pendrive o que falta ou mudou; retorna quantas músicas foram copiadas."""
    progress = progress or Progress()
    dest = library_dir(config, mount, create=True)
    assert dest is not None
    songs = []
    for song_json in sorted(config.paths.library.glob(f"*/{MANIFEST}")):
        copy = _plan_song(song_json.parent, dest / song_json.parent.name)
        if copy and copy.files:
            songs.append(copy)
    _run(songs, mount, progress)
    if songs:
        os.sync()  # o usuário tira o pendrive logo depois do "pronto"
    return len(songs)


def import_library(config: Config, mount: Path, progress: Progress | None = None) -> int:
    """Traz do pendrive as músicas que a biblioteca local não tem; retorna quantas vieram."""
    progress = progress or Progress()
    source = library_dir(config, mount)
    if source is None:
        return 0
    ids = sorted(ready_ids(source) - ready_ids(config.paths.library))
    songs = [c for i in ids if (c := _plan_song(source / i, config.paths.library / i, check=True))]
    config.paths.library.mkdir(parents=True, exist_ok=True)
    # index.json a cada música: se o pendrive sair no meio, as que vieram já aparecem.
    _run(songs, config.paths.library, progress, after_song=lambda: write_index(config))
    return len(songs)


def _run(
    songs: list[SongCopy], target: Path, progress: Progress, after_song: Callable[[], None] | None = None
) -> None:
    progress.copying = True
    progress.total = len(songs)
    progress.bytes_total = sum(s.size for s in songs)
    check_space(target, progress.bytes_total)
    for song in songs:
        copied = 0
        for src, dst in song.files:
            copy_atomic(src, dst)
            copied += src.stat().st_size
        if after_song:
            after_song()
        progress.step(bytes=copied)


def _plan_song(src: Path, dst: Path, check: bool = False) -> SongCopy | None:
    """Arquivos de `src` que faltam ou mudaram em `dst`; None se a música não é válida.

    `check` (importação): o song.json veio de fora, então confere id e versão.
    """
    try:
        data = json.loads((src / MANIFEST).read_text())
    except (OSError, ValueError):
        return None
    if check and (data.get("id") != src.name or data.get("version", 0) > FORMAT_VERSION):
        return None  # pasta renomeada à mão, ou biblioteca de uma versão mais nova
    names = [n for n in (data.get("files") or {}).values() if n and Path(n).name == n]
    if not all((src / n).is_file() for n in names):
        return None
    copy = SongCopy(src.name)
    # Áudio primeiro, depois os .json, e song.json no fim de tudo: marca a pasta como completa.
    for name in [*sorted(names, key=lambda n: n.endswith(".json")), MANIFEST]:
        if _differs(src / name, dst / name):
            copy.files.append((src / name, dst / name))
    return copy


def _differs(src: Path, dst: Path) -> bool:
    try:
        if src.stat().st_size != dst.stat().st_size:
            return True
    except FileNotFoundError:
        return True
    # Áudio não muda sem mudar de tamanho; json pode (título corrigido com o mesmo tamanho).
    return src.suffix == ".json" and src.read_bytes() != dst.read_bytes()
