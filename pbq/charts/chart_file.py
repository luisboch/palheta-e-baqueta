"""O formato .chart do Clone Hero (texto): escrever e ler.

    [Song]        metadados: Resolution, Name, Artist, MusicStream...
    [SyncTrack]   "tick = TS n" (compasso) e "tick = B milésimos_de_BPM"
    [Events]      eventos globais (vazio por enquanto)
    [ExpertDrums] "tick = N lane duração", uma linha por nota (66/67/68 = marcas de prato)

A leitura existe para testes de ida e volta e para conferir charts gerados; o jogo tem o seu
parser em GDScript (fase 6), testado contra arquivos produzidos aqui.
"""

from __future__ import annotations

import re

from pbq.charts.model import Chart, Note
from pbq.charts.tempo import Tempo, TimeSignature

CHARTER = "Palheta & Baqueta"
SECTION = re.compile(r"^\[(\w+)\]\s*$")
LINE = re.compile(r"^\s*(\S+)\s*=\s*(.*?)\s*$")


def _quote(text: str) -> str:
    return '"' + text.replace('"', "'").replace("\n", " ") + '"'


def write_chart(chart: Chart) -> str:
    song = [
        ("Name", _quote(chart.name)),
        ("Artist", _quote(chart.artist)),
        ("Charter", _quote(CHARTER)),
        ("Offset", "0"),
        ("Resolution", str(chart.resolution)),
        ("Player2", "bass"),
        ("Difficulty", "0"),
        ("MediaType", _quote("cd")),
    ]
    song += [(key, _quote(value)) for key, value in sorted(chart.streams.items())]
    sync: list[tuple[int, int, str]] = [(ts.tick, 0, f"TS {ts.beats}") for ts in chart.time_signatures]
    sync += [(t.tick, 1, f"B {t.milli_bpm}") for t in chart.tempos]
    out = [
        "[Song]",
        "{",
        *(f"  {k} = {v}" for k, v in song),
        "}",
        "[SyncTrack]",
        "{",
        *(f"  {tick} = {text}" for tick, _, text in sorted(sync)),
        "}",
        "[Events]",
        "{",
        "}",
    ]
    for name, notes in chart.tracks.items():
        out += [f"[{name}]", "{", *(f"  {n.tick} = N {n.lane} {n.length}" for n in sorted(notes)), "}"]
    return "\r\n".join(out) + "\r\n"  # CRLF: o que o Moonscraper e o Clone Hero escrevem


def parse_chart(text: str) -> Chart:
    sections: dict[str, list[tuple[str, str]]] = {}
    current: list[tuple[str, str]] | None = None
    for raw in text.splitlines():
        line = raw.strip().lstrip("﻿")
        if m := SECTION.match(line):
            current = sections.setdefault(m.group(1), [])
        elif current is not None and (m := LINE.match(line)):
            current.append((m.group(1), m.group(2)))
    song = {k: v.strip('"') for k, v in sections.get("Song", [])}
    chart = Chart(
        name=song.get("Name", ""),
        artist=song.get("Artist", ""),
        tempos=[],
        time_signatures=[],
        resolution=int(song.get("Resolution", 192)),
        streams={k: v for k, v in song.items() if k.endswith("Stream")},
    )
    for tick, value in sections.get("SyncTrack", []):
        kind, *args = value.split()
        if kind == "B":
            chart.tempos.append(Tempo(int(tick), int(args[0])))
        elif kind == "TS":
            chart.time_signatures.append(TimeSignature(int(tick), int(args[0])))
    for name, entries in sections.items():
        if name in ("Song", "SyncTrack", "Events"):
            continue
        notes = []
        for tick, value in entries:
            kind, *args = value.split()
            if kind == "N":
                notes.append(Note(int(tick), int(args[0]), int(args[1]) if len(args) > 1 else 0))
        chart.tracks[name] = notes
    return chart
