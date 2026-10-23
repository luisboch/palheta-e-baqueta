# GERADO por tools/generators.py a partir de pbq/events.py, pbq/protocol.py, pbq/library.py,
# pbq/stages/presence.py e do `label` das etapas.
# Não edite: rode `uv run python -m tools.docs_check --fix`.
## Contrato com o backend: tipos e campos de eventos (data/events.jsonl) e de mensagens do CLI.
class_name BackendProtocol
extends RefCounted

const FORMAT_VERSION := 1

## Instrumentos jogáveis (song.json "instruments": id → presente). Nomes na tela ficam no jogo.
const INSTRUMENTS: Array[String] = ["drums", "bass", "strings"]

const EVENTS := {
	"queued": ["id", "label"],
	"progress": ["id", "label", "stage", "fraction"],
	"ready": ["id", "label"],
	"failed": ["id", "label", "stage", "error"],
	"queue": ["pending"],
}

const MESSAGES := {
	"version": ["name", "version", "config"],
	"drives": ["drives"],
	"progress": ["phase", "done", "total", "fraction"],
	"done": ["count", "errors"],
	"error": ["message"],
}

## Etapa do pipeline (queue.json "stage") → o que a tela mostra.
const STAGE_LABELS := {
	"ingest": "lendo a música",
	"separate": "separando os instrumentos",
	"presence": "vendo quem toca",
	"beats": "achando as batidas",
	"drums_chart": "escrevendo a bateria",
	"pitched_chart": "escrevendo Cordas e baixo",
	"chart": "montando as dificuldades",
	"package": "guardando na biblioteca",
}


## A linha tem um tipo conhecido em `types` e todos os campos dele?
static func is_valid(data: Variant, types: Dictionary) -> bool:
	if not data is Dictionary or not types.has(data.get("type")):
		return false
	for field: String in types[data["type"]]:
		if not data.has(field):
			return false
	return true
