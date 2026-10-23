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


def make_band(
    path: Path, seconds: float = 12.0, bpm: float = 120.0, rate: int = 44100, with_guitar: bool = True
) -> Path:
    """ "Banda" sintética em MP3: bumbo, caixa e chimbal; baixo em semínimas; guitarra distorcida.

    Não soa como música, mas tem o que o pipeline real precisa achar: ataques de bateria, um
    baixo grave e (se pedido) um timbre de guitarra com distorção.
    """
    import numpy as np

    from pbq import audio

    n = int(seconds * rate)
    beat = 60 / bpm
    out = np.zeros(n)
    rng = np.random.default_rng(0)

    def hit(start: float, length: float, sound):
        i, k = int(start * rate), int(length * rate)
        seg = sound(np.arange(min(k, n - i)) / rate)
        out[i : i + len(seg)] += seg

    for b in range(int(seconds / beat)):
        start = b * beat
        if b % 2 == 0:  # bumbo: seno descendo de 120 para 50 Hz
            hit(
                start,
                0.25,
                lambda x: 0.8 * np.sin(2 * np.pi * (50 + 70 * np.exp(-x * 30)) * x) * np.exp(-x * 12),
            )
        else:  # caixa: ruído com decaimento
            hit(start, 0.2, lambda x: 0.4 * rng.standard_normal(len(x)) * np.exp(-x * 20))
        for half in (0, beat / 2):  # chimbal: ruído agudo curto
            hit(
                start + half,
                0.05,
                lambda x: 0.15 * np.diff(rng.standard_normal(len(x) + 1)) * np.exp(-x * 80),
            )
        root = [55.0, 55.0, 73.4, 82.4][b % 4]
        hit(start, beat * 0.9, lambda x, f=root: 0.35 * np.sin(2 * np.pi * f * x) * np.exp(-x * 2))
        if with_guitar:  # acorde de quinta em dente de serra, com distorção (tanh)
            hit(
                start,
                beat * 0.9,
                lambda x, f=root * 4: (
                    0.25
                    * np.tanh(6 * sum(((x * f * r) % 1.0 - 0.5) for r in (1.0, 1.5, 2.0)))
                    * np.exp(-x * 1.5)
                ),
            )
    peak = np.abs(out).max()
    stereo = np.stack([out, out]).astype(np.float32) / peak * 0.9
    audio.write(path, stereo, rate, "-c:a", "libmp3lame", "-b:a", "192k")
    return path
