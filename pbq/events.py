"""Eventos do worker para o jogo: data/events.jsonl, uma linha JSON por evento.

O jogo lê a partir do fim do arquivo ao abrir (godot/core/event_reader.gd), então eventos
servem para notificar o que acontece com ele aberto. O estado atual da fila (para quem acabou
de abrir) fica em data/queue.json (pbq/worker.py).

EVENT_TYPES é o contrato: `emit` recusa tipo ou campos fora dele, e a tabela de
docs/backend-protocol.md é gerada daqui.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any, NamedTuple

from pbq.manifest import now

MAX_SIZE = 1 << 20  # acima disso o worker recomeça o arquivo ao iniciar


class EventType(NamedTuple):
    fields: tuple[str, ...]
    description: str


EVENT_TYPES: dict[str, EventType] = {
    "queued": EventType(("id", "label"), "música nova encontrada em data/input"),
    "progress": EventType(
        ("id", "label", "stage", "fraction"),
        "andamento da música em processamento (no máximo ~1 por segundo)",
    ),
    "ready": EventType(("id", "label"), "música pronta na biblioteca"),
    "failed": EventType(("id", "label", "stage", "error"), "etapa obrigatória falhou"),
    "queue": EventType(("pending",), "músicas na fila, contando a atual"),
}


def emit(path: Path, type: str, **data: Any) -> None:
    """Acrescenta um evento ao arquivo, numa única escrita (linhas não se misturam)."""
    spec = EVENT_TYPES.get(type)
    if spec is None or set(data) != set(spec.fields):
        raise ValueError(f"evento fora do contrato: {type} {sorted(data)}")
    event = {"type": type, "at": now(), **data}
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as f:
        f.write(json.dumps(event, ensure_ascii=False) + "\n")


def rotate(path: Path) -> None:
    """Esvazia o arquivo se ele passou de MAX_SIZE. O leitor do jogo lida com isso."""
    if path.exists() and path.stat().st_size > MAX_SIZE:
        path.write_text("")
