from __future__ import annotations

from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any

import numpy as np

from pbq import audio, dsp
from pbq.audio import Audio
from pbq.fsutil import write_json
from pbq.manifest import Song
from pbq.stages.base import Progress, Stage, no_progress
from pbq.stages.guitar_split import ACOUSTIC, ELECTRIC
from pbq.stages.separate import STEM_DIR, STEMS

REPORT = "presence.json"
ANALYSIS_RATE = 22050  # sobra para energia e ataques; metade do trabalho de 44,1 kHz
FRAME, HOP = 0.1, 0.05  # s: quadros de energia
LOUD_RANGE_DB = 40.0  # quadros da mixagem mais de 40 dB abaixo do pico são silêncio (intro, fim)

# Instrumento jogável → stem que ele toca. Guitarra e violão vêm da guitar_split.
INSTRUMENTS = {"drums": "drums", "bass": "bass", "guitar": ELECTRIC, "acoustic": ACOUSTIC}


@dataclass(frozen=True)
class Thresholds:
    # Stem "audível" num quadro: no máximo `relative_db` abaixo da mixagem e acima de `floor_db`.
    # Vazamento do Demucs costuma ficar 25-35 dB abaixo da mixagem.
    relative_db: float = -18.0
    floor_db: float = -50.0
    min_active: float = 0.15  # fração mínima da música (sem silêncio) com o instrumento audível
    min_onsets: float = 30.0  # ataques por minuto: o mínimo para um chart que valha jogar
    # Subida mínima (dB médios por banda) de um ataque. Guitarra distorcida é comprimida: em Anna
    # Júlia, 3 dB achava 12 ataques/min numa palhetada de ~216/min; 1 dB achava 141.
    onset_delta: float = 1.0

    @classmethod
    def from_opts(cls, opts: dict[str, Any]) -> Thresholds:
        return cls(**{k: float(v) for k, v in opts.items() if k in cls.__dataclass_fields__})


@dataclass(frozen=True)
class Measure:
    present: bool
    reason: str | None  # por que não: quiet (pouco audível) ou few_onsets
    active: float  # fração ativa
    onsets_per_min: float
    level_db: float  # RMS do stem em relação à mixagem


def measure(stem: Audio, mix: Audio, rate: int, t: Thresholds) -> Measure:
    """Decide se um stem (mono) tem um instrumento tocando de verdade, em relação à mixagem (mono)."""
    frame, hop = int(FRAME * rate), int(HOP * rate)
    stem_db = dsp.to_db(dsp.frame_rms(stem, frame, hop))
    mix_db = dsp.to_db(dsp.frame_rms(mix, frame, hop))
    n = min(len(stem_db), len(mix_db))
    stem_db, mix_db = stem_db[:n], mix_db[:n]
    loud = mix_db > mix_db.max() - LOUD_RANGE_DB
    audible = (stem_db >= mix_db + t.relative_db) & (stem_db >= t.floor_db) & loud
    active = float(audible.sum() / max(loud.sum(), 1))

    # Ataques só onde o stem é audível: o vazamento de outros instrumentos não conta.
    times = dsp.onsets(stem, rate, delta=t.onset_delta)
    frames = np.minimum((times / HOP).astype(int), n - 1) if len(times) else np.array([], dtype=int)
    hits = int(audible[frames].sum()) if len(frames) else 0
    minutes = max(len(stem) / rate / 60, 1e-9)
    onsets_per_min = hits / minutes

    level = float(
        dsp.to_db(np.sqrt(np.mean(stem.astype(np.float64) ** 2)))
        - dsp.to_db(np.sqrt(np.mean(mix.astype(np.float64) ** 2)))
    )

    reason = None
    if active < t.min_active:
        reason = "quiet"
    elif onsets_per_min < t.min_onsets:
        reason = "few_onsets"
    return Measure(reason is None, reason, round(active, 3), round(onsets_per_min, 1), round(level, 1))


class Presence(Stage):
    """Decide quais instrumentos tocam na música: os ausentes não podem ser escolhidos no jogo.

    Violão incerto já chega silencioso da guitar_split (voltou para a guitarra), e cai em "quiet".

    Entrada: stems/*.flac (separate), stems/{electric,acoustic}.flac (guitar_split)
    Saída:   presence.json (medidas e motivo por instrumento); song.meta["instruments"]
    Config:  relative_db, floor_db, min_active, min_onsets
    """

    name = "presence"
    summary = "quais instrumentos tocam (energia e ataques); ausentes ficam bloqueados"
    requires = ("separate", "guitar_split")

    def outputs(self, song: Song) -> list[Path]:
        return [song.path(REPORT)]

    def run(self, song: Song, progress: Progress = no_progress) -> None:
        t = Thresholds.from_opts(self.opts)
        stems = song.path(STEM_DIR)
        mix = sum(audio.mono(audio.decode(stems / f"{s}.flac", ANALYSIS_RATE)) for s in STEMS)
        assert isinstance(mix, np.ndarray)
        progress(0.3)

        results: dict[str, Measure] = {}
        for i, (instrument, stem_name) in enumerate(INSTRUMENTS.items(), 1):
            stem = audio.mono(audio.decode(stems / f"{stem_name}.flac", ANALYSIS_RATE))
            results[instrument] = measure(stem, mix, ANALYSIS_RATE, t)
            progress(0.3 + 0.7 * i / len(INSTRUMENTS))

        write_json(
            song.path(REPORT),
            {"thresholds": asdict(t), "instruments": {k: asdict(v) for k, v in results.items()}},
        )
        song.meta["instruments"] = {k: v.present for k, v in results.items()}
