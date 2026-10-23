"""O chart em memória: notas em ticks, por trilha (nome de seção do .chart, ex.: "ExpertDrums")."""

from __future__ import annotations

from dataclasses import dataclass, field

from pbq.charts.tempo import RESOLUTION, Tempo, TimeSignature

DIFFICULTIES = ("Easy", "Medium", "Hard", "Expert")  # Fácil, Médio, Difícil, Muito difícil
# Instrumento do jogo → sufixo da trilha no .chart (ADR 0007).
TRACK_SUFFIX = {"strings": "Single", "bass": "DoubleBass", "drums": "Drums"}


@dataclass(frozen=True, order=True)
class Note:
    tick: int
    lane: int
    length: int = 0  # ticks de sustentação (0 = nota curta)


@dataclass
class Chart:
    name: str
    artist: str
    tempos: list[Tempo]
    time_signatures: list[TimeSignature]
    resolution: int = RESOLUTION
    tracks: dict[str, list[Note]] = field(default_factory=dict)
    # Arquivos de áudio por papel no .chart ([Song] MusicStream, GuitarStream...).
    streams: dict[str, str] = field(default_factory=dict)


def track_name(instrument: str, difficulty: str) -> str:
    return f"{difficulty}{TRACK_SUFFIX[instrument]}"
