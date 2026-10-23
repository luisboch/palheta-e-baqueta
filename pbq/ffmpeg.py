"""ffmpeg via subprocess, com o stderr na exceção (nada de shell=True)."""

from __future__ import annotations

import subprocess
from pathlib import Path

from pbq.fsutil import tmp_path


def ffmpeg(*args: str | Path) -> None:
    cmd = ["ffmpeg", "-nostdin", "-hide_banner", "-loglevel", "error", "-y", *map(str, args)]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"ffmpeg falhou: {result.stderr.strip()[-500:]}")


def ffmpeg_to(output: Path, *args: str | Path) -> None:
    """Como ffmpeg(), mas escreve num temporário e só renomeia no fim (sem arquivo pela metade).

    O temporário mantém a extensão: o ffmpeg escolhe o formato de saída por ela.
    """
    output.parent.mkdir(parents=True, exist_ok=True)
    tmp = tmp_path(output)
    try:
        ffmpeg(*args, tmp)
        tmp.replace(output)
    finally:
        tmp.unlink(missing_ok=True)
