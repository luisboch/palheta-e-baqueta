"""Áudio sintético para testes: gerado na hora pelo ffmpeg, nunca música de verdade."""

import subprocess
from pathlib import Path

from mutagen.id3 import APIC, ID3, TALB, TIT2, TPE1, TXXX


def make_mp3(
    path: Path, seconds: float = 1.0, freq: int = 440, tags: dict[str, str] | None = None, cover: bool = False
) -> Path:
    """Senoide em MP3, com tags ID3 opcionais (title, artist, album, description)."""
    path.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [
            "ffmpeg",
            "-nostdin",
            "-loglevel",
            "error",
            "-y",
            "-f",
            "lavfi",
            "-i",
            f"sine=frequency={freq}:duration={seconds}",
            "-ac",
            "1",
            "-b:a",
            "64k",
            str(path),
        ],
        check=True,
    )
    tags = tags or {}
    id3 = ID3()
    frames = {"title": TIT2, "artist": TPE1, "album": TALB}
    for key, frame in frames.items():
        if key in tags:
            id3.add(frame(encoding=3, text=tags[key]))
    if "description" in tags:
        id3.add(TXXX(encoding=3, desc="description", text=tags["description"]))
    if cover:
        id3.add(APIC(encoding=3, mime="image/png", type=3, desc="capa", data=_png()))
    id3.save(path)
    return path


def _png() -> bytes:
    """PNG 8x8 gerado pelo ffmpeg (capa de teste)."""
    return subprocess.run(
        [
            "ffmpeg",
            "-nostdin",
            "-loglevel",
            "error",
            "-f",
            "lavfi",
            "-i",
            "color=c=red:s=8x8",
            "-frames:v",
            "1",
            "-f",
            "image2pipe",
            "-vcodec",
            "png",
            "-",
        ],
        capture_output=True,
        check=True,
    ).stdout
