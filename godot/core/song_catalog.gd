## A lista de músicas do menu, a partir do data/library/index.json (docs/library-format.md).
class_name SongCatalog
extends RefCounted

const UNKNOWN_ARTIST := "Artista desconhecido"
## Nomes dos instrumentos na tela, na ordem do contrato (BackendProtocol.INSTRUMENTS).
const INSTRUMENT_NAMES := {"drums": "Bateria", "bass": "Baixo", "strings": "Cordas"}


## Entradas do índice ordenadas por artista e título (sem diferenciar maiúsculas). [] se o texto
## não for um índice válido.
static func parse(text: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		return out
	for entry: Variant in json.data.get("songs", []):
		if entry is Dictionary and entry.get("id"):
			out.append(entry)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _key(a) < _key(b))
	return out


static func _key(entry: Dictionary) -> String:
	return (artist(entry) + "\n" + str(entry.get("title", ""))).to_lower()


static func artist(entry: Dictionary) -> String:
	var name: Variant = entry.get("artist")
	return str(name) if name else UNKNOWN_ARTIST


## "Título — Artista", como a lista mostra.
static func label(entry: Dictionary) -> String:
	return "%s — %s" % [entry.get("title", "?"), artist(entry)]


## "Bateria · Cordas": os instrumentos que tocam; "" se nenhum.
static func instruments(entry: Dictionary) -> String:
	var present: Dictionary = entry.get("instruments", {})
	var names: Array[String] = []
	for id in BackendProtocol.INSTRUMENTS:
		if present.get(id, false):
			names.append(INSTRUMENT_NAMES[id])
	return " · ".join(names)


## "4:08" a partir de segundos.
static func duration(entry: Dictionary) -> String:
	var seconds := int(entry.get("duration", 0))
	return "%d:%02d" % [seconds / 60, seconds % 60]
