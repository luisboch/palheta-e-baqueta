from __future__ import annotations

from collections.abc import Callable
from pathlib import Path
from typing import Any

from pbq.charts.pitched import BASS, STRINGS, PitchedOptions, RawNote, events
from pbq.config import Config
from pbq.fsutil import write_json
from pbq.manifest import Song
from pbq.models import PitchTranscriber
from pbq.stages.base import Progress, Stage, no_progress
from pbq.stages.drums_chart import CHART_DIR, load_tempo_map
from pbq.stages.separate import STEM_DIR

# Instrumento → (stem, ajustes da transcrição).
PARTS: dict[str, tuple[str, PitchedOptions]] = {"strings": ("guitar", STRINGS), "bass": ("bass", BASS)}


def _basic_pitch(opts: dict[str, Any]) -> PitchTranscriber:
    from pbq.models.basic_pitch import BasicPitchTranscriber

    return BasicPitchTranscriber()


TRANSCRIBERS: dict[str, Callable[[dict[str, Any]], PitchTranscriber]] = {"basic_pitch": _basic_pitch}


class PitchedChart(Stage):
    """Transcreve Cordas e baixo e põe cada ataque (nota ou acorde) na grade.

    Guarda as alturas, não os trastes: cada dificuldade calcula os seus (stages/chart.py).
    Instrumento ausente (presence) dá parte vazia, sem rodar o modelo.

    Entrada: stems/{guitar,bass}.flac, beatmap.json, song.meta["instruments"]
    Saída:   charts/{strings,bass}.json {present, events: [[tick, [alturas], duração]]},
             charts/{strings,bass}_notes.json (notas brutas do transcritor, para conferir)
    Config:  transcriber (basic_pitch)
    """

    name = "pitched_chart"
    label = "escrevendo Cordas e baixo"
    summary = "Cordas e baixo Muito difícil (basic-pitch), na grade de batidas"
    requires = ("separate", "beats", "presence")

    def __init__(self, config: Config, transcriber: PitchTranscriber | None = None):
        super().__init__(config)
        self._transcriber = transcriber

    def outputs(self, song: Song) -> list[Path]:
        return [song.path(CHART_DIR, f"{part}.json") for part in PARTS]

    def transcriber(self) -> PitchTranscriber:
        if self._transcriber is None:
            name = str(self.opts.get("transcriber", "basic_pitch"))
            if name not in TRANSCRIBERS:
                raise ValueError(f"transcriber inválido: {name!r} (use {', '.join(TRANSCRIBERS)})")
            self._transcriber = TRANSCRIBERS[name](self.opts)
        return self._transcriber

    def run(self, song: Song, progress: Progress = no_progress) -> None:
        tempo_map, _ = load_tempo_map(song)
        present = song.meta.get("instruments", {})
        for i, (part, (stem, opts)) in enumerate(PARTS.items()):
            out = song.path(CHART_DIR, f"{part}.json")
            if not present.get(part, False):
                write_json(out, {"present": False, "events": []})
                continue
            raw = self.transcriber().transcribe(song.path(STEM_DIR, f"{stem}.flac"))
            write_json(
                song.path(CHART_DIR, f"{part}_notes.json"),
                [[round(s, 3), round(e, 3), p, round(a, 3)] for s, e, p, a in raw],
            )
            evts = events((RawNote(*n) for n in raw), tempo_map, opts)
            write_json(out, {"present": True, "events": [[e.tick, list(e.pitches), e.length] for e in evts]})
            progress((i + 1) / len(PARTS))
