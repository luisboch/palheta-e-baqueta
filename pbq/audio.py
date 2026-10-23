"""Áudio como numpy (float32, forma (canais, amostras)), lido e escrito pelo ffmpeg.

O ffmpeg já é dependência (ingest, package); assim o núcleo não precisa de libsndfile.
"""

from __future__ import annotations

import subprocess
from pathlib import Path

import numpy as np
import numpy.typing as npt

from pbq.fsutil import tmp_path

Audio = npt.NDArray[np.float32]


def decode(path: Path, sample_rate: int, channels: int = 2) -> Audio:
    """Decodifica qualquer formato que o ffmpeg entenda para (canais, amostras) na taxa pedida."""
    cmd = [
        "ffmpeg",
        "-nostdin",
        "-hide_banner",
        "-loglevel",
        "error",
        "-i",
        str(path),
        "-ac",
        str(channels),
        "-ar",
        str(sample_rate),
        "-f",
        "f32le",
        "-",
    ]
    result = subprocess.run(cmd, capture_output=True)
    if result.returncode != 0:
        raise RuntimeError(f"ffmpeg falhou: {result.stderr.decode(errors='replace').strip()[-500:]}")
    data = np.frombuffer(result.stdout, dtype=np.float32)
    return data.reshape(-1, channels).T.copy()


def write(path: Path, audio: Audio, sample_rate: int, *codec_args: str) -> None:
    """Grava (canais, amostras) no formato da extensão de `path`, com escrita atômica.

    `codec_args` vão para o ffmpeg (ex.: "-c:a", "libvorbis", "-q:a", "6"); padrão = o do formato.
    """
    path.parent.mkdir(parents=True, exist_ok=True)
    channels = audio.shape[0]
    tmp = tmp_path(path)
    pcm = np.ascontiguousarray(audio.T, dtype=np.float32).tobytes()
    cmd = [
        "ffmpeg",
        "-nostdin",
        "-hide_banner",
        "-loglevel",
        "error",
        "-y",
        "-f",
        "f32le",
        "-ar",
        str(sample_rate),
        "-ac",
        str(channels),
        "-i",
        "-",
        *codec_args,
        str(tmp),
    ]
    try:
        result = subprocess.run(cmd, input=pcm, capture_output=True)
        if result.returncode != 0:
            raise RuntimeError(f"ffmpeg falhou: {result.stderr.decode(errors='replace').strip()[-500:]}")
        tmp.replace(path)
    finally:
        tmp.unlink(missing_ok=True)


def mono(audio: Audio) -> Audio:
    return audio.mean(axis=0).astype(np.float32) if audio.ndim == 2 else audio


def sample_rate(path: Path) -> int:
    """Taxa de amostragem do primeiro stream de áudio (ffprobe)."""
    result = subprocess.run(
        [
            "ffprobe",
            "-v",
            "error",
            "-select_streams",
            "a:0",
            "-show_entries",
            "stream=sample_rate",
            "-of",
            "csv=p=0",
            str(path),
        ],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0 or not result.stdout.strip():
        raise RuntimeError(f"ffprobe falhou em {path.name}: {result.stderr.strip()[-300:]}")
    return int(result.stdout.strip())
