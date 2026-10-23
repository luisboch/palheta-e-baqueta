"""Trechos da documentação (e arquivos) gerados a partir do código do backend.

Cada gerador devolve o texto que deve estar entre `<!-- gen:NOME -->` e `<!-- /gen:NOME -->`
(ou o conteúdo inteiro de um arquivo gerado). tools/docs_check.py confere e regenera.
"""

from __future__ import annotations

import argparse
import json
from collections.abc import Callable
from pathlib import Path

from pbq import cli
from pbq.events import EVENT_TYPES
from pbq.library import FORMAT_VERSION, INDEX_FIELDS
from pbq.protocol import MESSAGE_TYPES
from pbq.stages import STAGES
from pbq.stages.presence import INSTRUMENTS


def gen_stages(root: Path) -> str:
    rows = ["| # | Etapa | Versão | Requer | Obrigatória | O que faz |", "|---|---|---|---|---|---|"]
    for i, stage in enumerate(STAGES, 1):
        requires = ", ".join(f"`{r}`" for r in stage.requires) or "—"
        rows.append(
            f"| {i} | `{stage.name}` | {stage.version} | {requires} | "
            f"{'sim' if stage.required else 'não'} | {stage.summary} |"
        )
    return "\n".join(rows) + "\n"


def _types_table(types: dict[str, tuple[tuple[str, ...], str]]) -> str:
    rows = ["| Tipo | Campos | Quando |", "|---|---|---|"]
    for name, (fields, description) in types.items():
        rows.append(f"| `{name}` | {', '.join(f'`{f}`' for f in fields)} | {description} |")
    return "\n".join(rows) + "\n"


def gen_events(root: Path) -> str:
    return _types_table({k: (v.fields, v.description) for k, v in EVENT_TYPES.items()})


def gen_messages(root: Path) -> str:
    return _types_table({k: (v.fields, v.description) for k, v in MESSAGE_TYPES.items()})


def _subcommands(parser: argparse.ArgumentParser) -> list[tuple[str, argparse.ArgumentParser, str]]:
    found = []
    for action in parser._actions:
        if isinstance(action, argparse._SubParsersAction):
            helps = {a.dest: a.help or "" for a in action._choices_actions}
            found += [(name, sub, helps.get(name, "")) for name, sub in action.choices.items()]
    return found


def gen_cli(root: Path) -> str:
    rows = ["| Comando | O que faz |", "|---|---|"]

    def walk(parser: argparse.ArgumentParser, prefix: str) -> None:
        for name, sub, text in _subcommands(parser):
            nested = _subcommands(sub)
            if nested:
                walk(sub, f"{prefix} {name}")
                continue
            options = [
                a.option_strings[0] + (f" {a.metavar or a.dest.upper()}" if a.nargs != 0 else "")
                for a in sub._actions
                if a.option_strings and a.dest != "help"
            ]
            usage = " ".join([f"{prefix} {name}", *(f"[{o}]" for o in options)])
            rows.append(f"| `{usage}` | {text} |")

    walk(cli.build_parser(), "pbq")
    return "\n".join(rows) + "\n"


def gen_instruments(root: Path) -> str:
    rows = ["| Id | Stem tocado |", "|---|---|"]
    rows += [f"| `{name}` | `stems/{stem}.flac` |" for name, stem in INSTRUMENTS.items()]
    return "\n".join(rows) + "\n"


def gen_format_version(root: Path) -> str:
    return f"Versão atual do formato: **{FORMAT_VERSION}**.\n"


def gen_index_example(root: Path) -> str:
    example = {"version": FORMAT_VERSION, "songs": [dict.fromkeys(INDEX_FIELDS, "…")]}
    return "```json\n" + json.dumps(example, indent=2, ensure_ascii=False) + "\n```\n"


def gen_sample_chart(root: Path) -> str:
    """godot/tests/fixtures/pipeline_sample.chart: um chart feito pelas funções reais do pipeline.

    O parser do jogo (godot/core/chart_parser.gd) é testado contra ele: se o formato que o
    backend escreve mudar, o arquivo muda e os testes do Godot mostram o efeito.
    """
    from pbq.charts.chart_file import write_chart
    from pbq.charts.difficulty import drum_track, pitched_track
    from pbq.charts.drums import drum_notes
    from pbq.charts.model import DIFFICULTIES, Chart, track_name
    from pbq.charts.pitched import STRINGS, RawNote, events
    from pbq.charts.tempo import TempoMap, time_signatures

    # 8 batidas a 120 BPM a partir de 0,5 s, depois 4 a 150 BPM; tempos fortes a cada 4.
    beats = [0.5 + 0.5 * i for i in range(8)] + [4.5 + 0.4 * i for i in range(4)]
    downbeats = beats[::4]
    tempo_map = TempoMap.from_beats(beats)
    signatures = time_signatures(beats, downbeats, tempo_map.resolution, tempo_map.lead_beats)
    hits = {
        "kick": beats[::2],
        "snare": beats[1::2],
        "hihat": beats,
        "tom": [beats[-1]],
        "cymbal": [beats[0]],
    }
    melody = [RawNote(b, b + 0.3, 52 + 2 * i, 0.8) for i, b in enumerate(beats[:6])]
    melody += [RawNote(beats[6], beats[6] + 1.2, 55, 0.8), RawNote(beats[6] + 0.01, beats[6] + 1.2, 59, 0.8)]
    evts = events(melody, tempo_map, STRINGS)
    expert_drums = drum_notes(hits, tempo_map)
    chart = Chart(
        name="Exemplo do pipeline",
        artist="Palheta & Baqueta",
        tempos=tempo_map.tempos,
        time_signatures=signatures,
        resolution=tempo_map.resolution,
        streams={"MusicStream": "song.ogg", "GuitarStream": "guitar.ogg", "DrumStream": "drums.ogg"},
    )
    for difficulty in DIFFICULTIES:
        chart.tracks[track_name("strings", difficulty)] = pitched_track(
            evts, difficulty, tempo_map.resolution, signatures
        )
        chart.tracks[track_name("drums", difficulty)] = drum_track(
            expert_drums, difficulty, tempo_map.resolution
        )
    return write_chart(chart)


def _gd_dict(types: dict[str, tuple[str, ...]]) -> str:
    lines = [
        f'\t"{name}": [{", ".join(f"{chr(34)}{f}{chr(34)}" for f in fields)}],'
        for name, fields in types.items()
    ]
    return "{\n" + "\n".join(lines) + "\n}"


def gen_gd_protocol(root: Path) -> str:
    """godot/core/backend_protocol.gd: os mesmos tipos e campos do Python, para o jogo validar."""
    events = _gd_dict({k: v.fields for k, v in EVENT_TYPES.items()})
    messages = _gd_dict({k: v.fields for k, v in MESSAGE_TYPES.items()})
    instruments = ", ".join(f'"{name}"' for name in INSTRUMENTS)
    return f"""# GERADO por tools/generators.py a partir de pbq/events.py, pbq/protocol.py, pbq/library.py e
# pbq/stages/presence.py.
# Não edite: rode `uv run python -m tools.docs_check --fix`.
## Contrato com o backend: tipos e campos de eventos (data/events.jsonl) e de mensagens do CLI.
class_name BackendProtocol
extends RefCounted

const FORMAT_VERSION := {FORMAT_VERSION}

## Instrumentos jogáveis (song.json "instruments": id → presente). Nomes na tela ficam no jogo.
const INSTRUMENTS: Array[String] = [{instruments}]

const EVENTS := {events}

const MESSAGES := {messages}


## A linha tem um tipo conhecido em `types` e todos os campos dele?
static func is_valid(data: Variant, types: Dictionary) -> bool:
\tif not data is Dictionary or not types.has(data.get("type")):
\t\treturn false
\tfor field: String in types[data["type"]]:
\t\tif not data.has(field):
\t\t\treturn false
\treturn true
"""


Generator = Callable[[Path], str]

DOC_GENERATORS: dict[str, Generator] = {
    "stages": gen_stages,
    "events": gen_events,
    "messages": gen_messages,
    "cli": gen_cli,
    "format-version": gen_format_version,
    "instruments": gen_instruments,
    "index-example": gen_index_example,
}

# Arquivos inteiros gerados (caminho relativo à raiz do repositório).
FILE_GENERATORS: dict[Path, Generator] = {
    Path("godot/core/backend_protocol.gd"): gen_gd_protocol,
    Path("godot/tests/fixtures/pipeline_sample.chart"): gen_sample_chart,
}
