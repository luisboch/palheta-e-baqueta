"""Escrita atômica e utilitários de arquivo, usados por todo o backend.

Regra do projeto (do kraoke): nenhum caminho final fica pela metade. Grava-se em
".tmp.<nome>" na mesma pasta e renomeia-se no fim (`replace` é atômico no mesmo sistema de
arquivos). Quem varre pastas ignora ".tmp.*".
"""

from __future__ import annotations

import json
import os
import shutil
import threading
from pathlib import Path
from typing import Any

TMP_PREFIX = ".tmp."


def tmp_path(dest: Path) -> Path:
    """Temporário ao lado de `dest`, único por processo e thread.

    Worker e CLI do pendrive podem regravar o mesmo arquivo ao mesmo tempo (ex.: index.json).
    """
    return dest.with_name(f"{TMP_PREFIX}{os.getpid()}.{threading.get_ident()}.{dest.name}")


def write_json(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = tmp_path(path)
    tmp.write_text(json.dumps(data, indent=2, ensure_ascii=False))
    tmp.replace(path)


def read_json(path: Path, default: Any) -> Any:
    """Conteúdo do arquivo, ou `default` se ele não existir ou estiver corrompido."""
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError):
        return default


def copy_atomic(src: Path, dst: Path) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    tmp = tmp_path(dst)
    try:
        shutil.copyfile(src, tmp)
        tmp.replace(dst)
    except OSError:
        tmp.unlink(missing_ok=True)  # pendrive removido no meio, disco cheio...
        raise


class NotEnoughSpace(OSError):
    def __init__(self, missing: int):
        super().__init__(f"espaço insuficiente: faltam {missing / 1e6:.0f} MB")
        self.missing = missing


def check_space(target: Path, needed: int) -> None:
    free = shutil.disk_usage(target).free
    if needed > free:
        raise NotEnoughSpace(needed - free)


def size(path: Path) -> int:
    try:
        return path.stat().st_size
    except OSError:
        return 0


def mp3s(folder: Path) -> list[Path]:
    """MP3s de uma pasta e subpastas, sem ocultos nem cópias temporárias."""
    return [
        p
        for p in sorted(folder.rglob("*"))
        if p.suffix.lower() == ".mp3" and not p.name.startswith(".") and p.is_file()
    ]


def free_name(dest: Path) -> Path:
    """Nome que ainda não existe: "x.mp3", "x (2).mp3", ... (outra música com o mesmo nome)."""
    candidate, n = dest, 2
    while candidate.exists():
        candidate = dest.with_name(f"{dest.stem} ({n}){dest.suffix}")
        n += 1
    return candidate
