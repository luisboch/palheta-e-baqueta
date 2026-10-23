#!/usr/bin/env python3
"""Gera os efeitos sonoros sintéticos do jogo: erro e nota perdida (miss).

Usa apenas a biblioteca padrão (wave, struct, math) para não depender de pacotes externos.
Arquivos gerados em godot/game/sfx/.
"""

import math
import random
import struct
import wave
from pathlib import Path

SAMPLE_RATE = 44100


def _write_wav(path: Path, samples: list[float]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)  # 16-bit
        f.setframerate(SAMPLE_RATE)
        frames = bytearray()
        for s in samples:
            # Clamp entre -1.0 e 1.0
            clamped = max(-1.0, min(1.0, s))
            val = int(clamped * 32767)
            frames.extend(struct.pack("<h", val))
        f.writeframes(frames)


def generate_error_sfx(path: Path) -> None:
    """Som evidente de erro (overstrum / palhetada errada).

    Onda composta grave (~120 Hz) com harmônicos ímpares (timbre áspero/abafado),
    transiente inicial percussivo e decaimento exponencial rápido (120 ms).
    """
    duration = 0.12
    n_samples = int(duration * SAMPLE_RATE)
    samples = []
    rng = random.Random(42)

    for i in range(n_samples):
        t = i / SAMPLE_RATE
        # Envelope: ataque imediato, decaimento exponencial rápido
        env = math.exp(-t * 30.0)

        # Transiente de palheta/impacto (primeiros 10 ms)
        click = (rng.uniform(-1.0, 1.0) * math.exp(-t * 300.0)) * 0.4

        # Corpo com harmônicos (120 Hz, 240 Hz, 360 Hz)
        f0 = 120.0
        tone = (
            0.6 * math.sin(2.0 * math.pi * f0 * t)
            + 0.3 * math.sin(2.0 * math.pi * (f0 * 2.0) * t)
            + 0.25 * math.sin(2.0 * math.pi * (f0 * 3.0) * t)
            + 0.15 * math.sin(2.0 * math.pi * (f0 * 5.0) * t)
        )

        # Leve saturação / distorção analógica para corpo e aspereza
        raw = tone * env + click
        distorted = math.tanh(raw * 1.6) * 0.8
        samples.append(distorted)

    _write_wav(path, samples)


def generate_miss_sfx(path: Path) -> None:
    """Som discreto de nota escapando (passou da linha sem ser tocada).

    Descida suave de frequência (pitch drop de 400 Hz para 160 Hz)
    com decaimento rápido (55 ms) e volume mais baixo que o erro.
    """
    duration = 0.055
    n_samples = int(duration * SAMPLE_RATE)
    samples = []

    for i in range(n_samples):
        t = i / SAMPLE_RATE
        # Envelope suave
        env = math.exp(-t * 70.0)

        # Queda de tom (pitch slide de 380 Hz descendo)
        freq = 380.0 - 220.0 * (t / duration)
        phase = 2.0 * math.pi * freq * t
        tone = math.sin(phase)

        # Volume moderado/baixo (-6 dB em relação ao erro)
        samples.append(tone * env * 0.35)

    _write_wav(path, samples)


def main() -> None:
    target_dir = Path(__file__).resolve().parent.parent / "godot" / "game" / "sfx"
    error_path = target_dir / "error.wav"
    miss_path = target_dir / "miss.wav"

    generate_error_sfx(error_path)
    generate_miss_sfx(miss_path)
    print(f"Gerado: {error_path} ({error_path.stat().st_size} bytes)")
    print(f"Gerado: {miss_path} ({miss_path.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
