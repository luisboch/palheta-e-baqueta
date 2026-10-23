"""Pendrives: encontrar, analisar e copiar os MP3s novos para data/input.

Adaptado do usb.py do kraoke. O SteamOS (e Fedora/Arch) monta mídia removível em
/run/media/<usuário>/<rótulo>/, também no modo jogo; Ubuntu e derivados, em
/media/<usuário>/<rótulo>/. Em cada pendrive o jogo usa a pasta `[drive] folder` (padrão
"palheta", sem diferenciar maiúsculas) na raiz:

    palheta/*.mp3, palheta/subpastas/   MP3s para processar
    palheta/library/<id>/               músicas prontas (backup.py: salvar e importar)

Nada acontece ao conectar (ADR 0003): o jogo chama `pbq drive process|import|export` quando
o usuário escolhe no menu. O pendrive só é escrito por "salvar" (backup.py).

- "Novo" = id que não está em data/work, data/input nem na biblioteca, e que também não está
  pronto em palheta/library/ (esse vem pronto pela importação).
- Diferença do kraoke: lá o cache de hash vivia na memória do app; aqui cada ação é um processo
  `pbq drive` novo, então o cache fica em data/work/.drive-cache.json, por (caminho, tamanho,
  mtime). Entradas de arquivos que sumiram do pendrive analisado são descartadas.
"""

from __future__ import annotations

import getpass
from collections.abc import Callable
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from pbq.config import Config
from pbq.fsutil import check_space, copy_atomic, free_name, mp3s, read_json, size, write_json
from pbq.library import ready_ids
from pbq.manifest import song_id
from pbq.scan import CACHE as SCAN_CACHE

DEST = "pendrive"  # subpasta de data/input que recebe os MP3s
LIBRARY = "library"  # subpasta de palheta/ no pendrive com as músicas prontas
DEFAULT_FOLDER = "palheta"
HASH_CACHE = ".drive-cache.json"


@dataclass
class Progress:
    """Andamento de uma análise ou cópia.

    Começa lendo (`copying` False: done/total contam arquivos lidos) e passa a copiar
    (done/total contam músicas; a fração usa bytes). `on_change` é chamado a cada passo
    (o CLI o transforma em linhas JSON para o jogo).
    """

    copying: bool = False
    done: int = 0
    total: int = 0
    bytes_done: int = 0
    bytes_total: int = 0
    on_change: Callable[[Progress], None] = field(default=lambda p: None, repr=False, compare=False)

    @property
    def fraction(self) -> float:
        if self.bytes_total:
            return self.bytes_done / self.bytes_total
        return self.done / self.total if self.total else 0.0

    def step(self, files: int = 1, bytes: int = 0) -> None:
        self.done += files
        self.bytes_done += bytes
        self.on_change(self)

    def as_dict(self) -> dict[str, Any]:
        return {
            "phase": "copying" if self.copying else "reading",
            "done": self.done,
            "total": self.total,
            "fraction": round(self.fraction, 3),
        }


class HashCache:
    """Ids dos MP3s dos pendrives por (caminho, tamanho, mtime), persistido entre comandos."""

    def __init__(self, path: Path):
        self.path = path
        self.entries: dict[str, dict[str, Any]] = read_json(path, {})
        self._seen: set[str] = set()

    def id(self, mp3: Path) -> str:
        st = mp3.stat()
        key = str(mp3)
        self._seen.add(key)
        entry = self.entries.get(key)
        if entry and entry["size"] == st.st_size and entry["mtime"] == st.st_mtime:
            return str(entry["id"])
        sid = song_id(mp3)
        self.entries[key] = {"size": st.st_size, "mtime": st.st_mtime, "id": sid}
        return sid

    def save(self, scanned_root: Path) -> None:
        """Grava, descartando o que estava em `scanned_root` e não foi visto agora."""
        prefix = str(scanned_root) + "/"
        self.entries = {k: v for k, v in self.entries.items() if not k.startswith(prefix) or k in self._seen}
        write_json(self.path, self.entries)


def hash_cache(config: Config) -> HashCache:
    return HashCache(config.paths.work / HASH_CACHE)


def mounts(config: Config) -> list[Path]:
    """Pendrives montados agora, com ou sem a pasta do jogo."""
    user = getpass.getuser()
    roots = config.section("drive").get("roots") or [f"/run/media/{user}", f"/media/{user}"]
    found: list[Path] = []
    for root in map(Path, roots):
        try:
            found += sorted(m for m in root.iterdir() if m.is_dir())
        except OSError:
            continue
    return found


def find_child(parent: Path, name: str) -> Path | None:
    """Subpasta `name` de `parent` sem diferenciar maiúsculas ("PALHETA", "Library"...)."""
    try:
        return next(
            (d for d in parent.iterdir() if d.is_dir() and d.name.casefold() == name.casefold()), None
        )
    except OSError:  # desmontado, sem permissão...
        return None


def drive_dir(config: Config, mount: Path, create: bool = False) -> Path | None:
    name = config.section("drive").get("folder", DEFAULT_FOLDER)
    found = find_child(mount, name)
    if found is None and create:
        found = mount / name
        found.mkdir()
    return found


def library_dir(config: Config, mount: Path, create: bool = False) -> Path | None:
    """<pendrive>/palheta/library, se existir (ou criada, com `create`)."""
    root = drive_dir(config, mount, create)
    if root is None:
        return None
    found = find_child(root, LIBRARY)
    if found is None and create:
        found = root / LIBRARY
        found.mkdir()
    return found


def known_ids(config: Config) -> set[str]:
    """Ids que o backend já tem: data/work, a biblioteca e os MP3s de input.

    Os MP3s de input usam o cache do scanner quando o arquivo não mudou.
    """
    ids = ready_ids(config.paths.library)
    work = config.paths.work
    if work.exists():
        ids |= {d.name for d in work.iterdir() if d.is_dir()}
    cached: dict[str, dict[str, Any]] = read_json(work / SCAN_CACHE, {})
    for path in mp3s(config.paths.input) if config.paths.input.exists() else []:
        entry = cached.get(str(path), {})
        st = path.stat()
        same = entry.get("size") == st.st_size and entry.get("mtime") == st.st_mtime
        ids.add(entry["id"] if same else song_id(path))
    return ids


def find_new(
    config: Config, mount: Path, cache: HashCache, progress: Progress | None = None
) -> list[tuple[Path, str]]:
    """MP3s do pendrive para processar: [(caminho, id)] dos que o backend ainda não tem."""
    progress = progress or Progress()
    root = drive_dir(config, mount)
    if root is None:
        return []
    library = find_child(root, LIBRARY)
    skip = known_ids(config) | ready_ids(library)
    files = [p for p in mp3s(root) if library is None or not p.is_relative_to(library)]
    progress.total = len(files)

    new, seen = [], set()
    for path in files:
        sid = cache.id(path)
        progress.step()
        if sid not in skip and sid not in seen:  # o mesmo MP3 em duas pastas conta uma vez
            seen.add(sid)
            new.append((path, sid))
    cache.save(root)
    return new


@dataclass
class CopyResult:
    copied: list[Path] = field(default_factory=list)
    errors: list[str] = field(default_factory=list)


def copy_new(
    config: Config, mount: Path, songs: list[tuple[Path, str]], progress: Progress | None = None
) -> CopyResult:
    """Copia os MP3s de `find_new` para data/input/pendrive/, mantendo subpastas.

    Um arquivo com erro não interrompe os outros; pendrive removido vira erro em cada um.
    """
    progress = progress or Progress()
    root = drive_dir(config, mount) or mount
    dest_root = config.paths.input / DEST
    dest_root.mkdir(parents=True, exist_ok=True)
    progress.copying, progress.done, progress.total = True, 0, len(songs)
    progress.bytes_done, progress.bytes_total = 0, sum(size(p) for p, _ in songs)
    check_space(dest_root, progress.bytes_total)

    result = CopyResult()
    for path, _ in songs:
        dest = free_name(dest_root / path.relative_to(root))
        try:
            copy_atomic(path, dest)
            result.copied.append(dest)
        except OSError as e:
            result.errors.append(f"{path.name}: {e}")
        progress.step(bytes=size(path))
    return result


def process_new(config: Config, mount: Path, progress: Progress | None = None) -> CopyResult:
    """ "Processar músicas": acha os MP3s novos e os copia para input (o worker faz o resto)."""
    progress = progress or Progress()
    new = find_new(config, mount, hash_cache(config), progress)
    return copy_new(config, mount, new, progress)
