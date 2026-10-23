from __future__ import annotations

from pathlib import Path

from pbq.charts.chart_file import write_chart
from pbq.charts.model import Chart, Note, track_name
from pbq.charts.tempo import time_signatures
from pbq.fsutil import read_json, tmp_path
from pbq.manifest import Song
from pbq.stages.base import Progress, Stage, no_progress
from pbq.stages.drums_chart import CHART_DIR, load_tempo_map

CHART = "notes.chart"
# Instrumento → (arquivo de notas em charts/, papel do áudio no [Song] do .chart). Cordas e baixo
# entram na fase 5; por enquanto só a bateria tem chart.
PARTS = {"drums": "DrumStream"}
# Nomes dos áudios na biblioteca, no padrão do Clone Hero (ADR 0007).
STREAM_FILES = {
    "MusicStream": "song.ogg",
    "DrumStream": "drums.ogg",
    "GuitarStream": "guitar.ogg",
    "BassStream": "bass.ogg",
}


class ChartFile(Stage):
    """Monta o notes.chart: mapa de tempo, compassos e as trilhas de cada instrumento presente.

    Entrada: beatmap.json, charts/<instrumento>.json
    Saída:   notes.chart (formato do Clone Hero)
    """

    name = "chart"
    summary = "notes.chart (Clone Hero): mapa de tempo, compassos e trilhas"
    requires = ("beats", "drums_chart")

    def outputs(self, song: Song) -> list[Path]:
        return [song.path(CHART)]

    def run(self, song: Song, progress: Progress = no_progress) -> None:
        tempo_map, beatmap = load_tempo_map(song)
        chart = Chart(
            name=song.meta.get("title") or Path(song.source).stem,
            artist=song.meta.get("artist") or "",
            tempos=tempo_map.tempos,
            time_signatures=time_signatures(
                beatmap["beats"], beatmap["downbeats"], tempo_map.resolution, tempo_map.lead_beats
            ),
            resolution=tempo_map.resolution,
            streams={"MusicStream": STREAM_FILES["MusicStream"]},
        )
        for instrument, stream in PARTS.items():
            part = read_json(song.path(CHART_DIR, f"{instrument}.json"), {"present": False, "notes": []})
            if not part["present"]:
                continue
            chart.tracks[track_name(instrument, "Expert")] = [Note(*n) for n in part["notes"]]
            chart.streams[stream] = STREAM_FILES[stream]
        out = song.path(CHART)
        tmp = tmp_path(out)
        tmp.write_bytes(write_chart(chart).encode("utf-8"))
        tmp.replace(out)
