from __future__ import annotations

from pathlib import Path
from typing import Any

from pbq.charts.chart_file import write_chart
from pbq.charts.difficulty import drum_track, pitched_track
from pbq.charts.model import DIFFICULTIES, Chart, Note, track_name
from pbq.charts.pitched import Event
from pbq.charts.tempo import time_signatures
from pbq.fsutil import read_json, tmp_path
from pbq.manifest import Song
from pbq.stages.base import Progress, Stage, no_progress
from pbq.stages.drums_chart import CHART_DIR, load_tempo_map

CHART = "notes.chart"
# Instrumento → papel do áudio no [Song] do .chart.
STREAMS = {"strings": "GuitarStream", "bass": "BassStream", "drums": "DrumStream"}
# Nomes dos áudios na biblioteca, no padrão do Clone Hero (ADR 0007).
STREAM_FILES = {
    "MusicStream": "song.ogg",
    "GuitarStream": "guitar.ogg",
    "BassStream": "bass.ogg",
    "DrumStream": "drums.ogg",
}


def load_part(song: Song, instrument: str) -> dict[str, Any]:
    empty: dict[str, Any] = {"present": False, "notes": [], "events": []}
    data: dict[str, Any] = read_json(song.path(CHART_DIR, f"{instrument}.json"), empty)
    return data


class ChartFile(Stage):
    """Monta o notes.chart: mapa de tempo, compassos e as 4 dificuldades de cada instrumento presente.

    As dificuldades saem do Muito difícil por redução (pbq/charts/difficulty.py).

    Entrada: beatmap.json, charts/{drums,strings,bass}.json
    Saída:   notes.chart (formato do Clone Hero)
    """

    name = "chart"
    label = "montando as dificuldades"
    summary = "notes.chart (Clone Hero): mapa de tempo, compassos e as 4 dificuldades"
    version = 6  # 6: Fácil de Cordas e baixo em todas as batidas (ADR 0020)
    requires = ("beats", "drums_chart", "pitched_chart")

    def outputs(self, song: Song) -> list[Path]:
        return [song.path(CHART)]

    def run(self, song: Song, progress: Progress = no_progress) -> None:
        tempo_map, beatmap = load_tempo_map(song)
        signatures = time_signatures(
            beatmap["beats"], beatmap["downbeats"], tempo_map.resolution, tempo_map.lead_beats
        )
        chart = Chart(
            name=song.meta.get("title") or Path(song.source).stem,
            artist=song.meta.get("artist") or "",
            tempos=tempo_map.tempos,
            time_signatures=signatures,
            resolution=tempo_map.resolution,
            streams={"MusicStream": STREAM_FILES["MusicStream"]},
        )
        for instrument, stream in STREAMS.items():
            part = load_part(song, instrument)
            if not part["present"]:
                continue
            chart.streams[stream] = STREAM_FILES[stream]
            for difficulty in DIFFICULTIES:
                if instrument == "drums":
                    notes = drum_track([Note(*n) for n in part["notes"]], difficulty, tempo_map.resolution)
                else:
                    evts = [Event(t, tuple(p), length) for t, p, length in part["events"]]
                    notes = pitched_track(evts, difficulty, tempo_map.resolution)
                chart.tracks[track_name(instrument, difficulty)] = notes
        out = song.path(CHART)
        tmp = tmp_path(out)
        tmp.write_bytes(write_chart(chart).encode("utf-8"))
        tmp.replace(out)
