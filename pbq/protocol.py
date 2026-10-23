"""Mensagens que os comandos `pbq` chamados pelo jogo escrevem no stdout: uma linha JSON cada.

O jogo lê com OS.execute_with_pipe (godot/core/backend_message.gd). Logs vão para o stderr,
nunca para o stdout. MESSAGE_TYPES é o contrato: `write` recusa o que estiver fora dele, e a
tabela de docs/backend-protocol.md é gerada daqui.
"""

from __future__ import annotations

import json
import sys
from typing import IO, Any, NamedTuple


class MessageType(NamedTuple):
    fields: tuple[str, ...]
    description: str


MESSAGE_TYPES: dict[str, MessageType] = {
    "version": MessageType(("name", "version", "config"), "resposta de `pbq version`"),
    "drives": MessageType(("drives",), "pendrives montados: [{path, name, has_folder}]"),
    "progress": MessageType(
        ("phase", "done", "total", "fraction"), "andamento; phase = reading (lendo/analisando) ou copying"
    ),
    "done": MessageType(("count", "errors"), "fim com sucesso: quantas músicas, erros por arquivo"),
    "error": MessageType(("message",), "falhou (sem espaço, pendrive removido...); saída ≠ 0"),
}


def write(type: str, out: IO[str] | None = None, **data: Any) -> None:
    spec = MESSAGE_TYPES.get(type)
    if spec is None or set(data) != set(spec.fields):
        raise ValueError(f"mensagem fora do contrato: {type} {sorted(data)}")
    stream = out or sys.stdout
    stream.write(json.dumps({"type": type, **data}, ensure_ascii=False) + "\n")
    stream.flush()  # o jogo mostra o andamento linha a linha
