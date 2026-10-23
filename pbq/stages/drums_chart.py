from __future__ import annotations

from collections.abc import Callable
from pathlib import Path
from typing import Any

from pbq import audio
from pbq.charts.drums import drum_notes
from pbq.charts.tempo import TempoMap
from pbq.config import Config
from pbq.fsutil import read_json, write_json
from pbq.manifest import Song
from pbq.models import DrumTranscriber
from pbq.stages.base import Progress, Stage, no_progress
from pbq.stages.beats import BEATMAP
from pbq.stages.separate import STEM_DIR

CHART_DIR = "charts"
HITS = "drums_hits.json"  # ataques brutos (s) por peça, antes da grade: para conferir à mão


def _adtof(opts: dict[str, Any]) -> DrumTranscriber:
    from pbq.models.adtof import AdtofTranscriber

    return AdtofTranscriber(models_dir=Path(str(opts["models_dir"])), device=str(opts.get("device", "cpu")))


TRANSCRIBERS: dict[str, Callable[[dict[str, Any]], DrumTranscriber]] = {"adtof": _adtof}


def load_tempo_map(song: Song) -> tuple[TempoMap, dict[str, Any]]:
    beatmap = read_json(song.path(BEATMAP), None)
    if not beatmap:
        raise FileNotFoundError(f"{BEATMAP} ausente ou inválido")
    return TempoMap.from_beats(beatmap["beats"]), beatmap


class DrumsChart(Stage):
    """Transcreve o stem de bateria e põe cada ataque na grade: o chart Muito difícil (Expert).

    Bateria ausente (presence) dá chart vazio, sem rodar o modelo.

    Entrada: stems/drums.flac, beatmap.json, song.meta["instruments"]
    Saída:   charts/drums.json {present, notes: [[tick, lane, duração]]}, drums_hits.json
    Config:  transcriber (adtof), device
    """

    name = "drums_chart"
    label = "escrevendo a bateria"
    summary = "chart de bateria Muito difícil (ADTOF), na grade de batidas"
    requires = ("separate", "beats", "presence")

    def __init__(self, config: Config, transcriber: DrumTranscriber | None = None):
        super().__init__(config)
        self._transcriber = transcriber

    def outputs(self, song: Song) -> list[Path]:
        return [song.path(CHART_DIR, "drums.json")]

    def transcriber(self) -> DrumTranscriber:
        if self._transcriber is None:
            name = str(self.opts.get("transcriber", "adtof"))
            if name not in TRANSCRIBERS:
                raise ValueError(f"transcriber inválido: {name!r} (use {', '.join(TRANSCRIBERS)})")
            opts = {"models_dir": str(self.config.paths.state / "models"), **self.opts}
            self._transcriber = TRANSCRIBERS[name](opts)
        return self._transcriber

    def run(self, song: Song, progress: Progress = no_progress) -> None:
        tempo_map, _ = load_tempo_map(song)
        out = song.path(CHART_DIR, "drums.json")
        if not song.meta.get("instruments", {}).get("drums", False):
            write_json(out, {"present": False, "notes": []})
            return
        transcriber = self.transcriber()
        stem = song.path(STEM_DIR, "drums.flac")
        signal = audio.mono(audio.decode(stem, transcriber.sample_rate, channels=1))
        progress(0.1)
        hits = transcriber.transcribe(signal)
        progress(0.9)
        write_json(
            song.path(HITS), {piece: [round(float(t), 3) for t in times] for piece, times in hits.items()}
        )
        notes = drum_notes(hits, tempo_map)
        write_json(out, {"present": True, "notes": [[n.tick, n.lane, n.length] for n in notes]})
