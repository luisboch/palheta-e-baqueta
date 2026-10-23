## O que o jogador pode escolher numa música: instrumentos presentes e dificuldades com notas.
##
## Instrumento ausente (song.json "instruments" falso, etapa presence do backend) não aparece
## como opção jogável, mesmo que o chart tenha algo (ADR 0009).
class_name InstrumentRules
extends RefCounted

const DIFFICULTIES := ["Easy", "Medium", "Hard", "Expert"]
## Sem escolha (ou escolha indisponível): Cordas no Difícil, o ponto de partida dos testes de jogo.
const DEFAULT_INSTRUMENT := "strings"
const DEFAULT_DIFFICULTY := "Hard"
const TRACK_SUFFIX := {"strings": "Single", "bass": "DoubleBass", "drums": "Drums"}


static func track_name(instrument: String, difficulty: String) -> String:
	return difficulty + TRACK_SUFFIX[instrument]


## {instrumento: [dificuldades com notas]} só dos instrumentos presentes, na ordem do contrato.
static func available(song: Dictionary, chart: Dictionary) -> Dictionary:
	var present: Dictionary = song.get("instruments", {})
	var tracks: Dictionary = chart.get("tracks", {})
	var out := {}
	for instrument: String in BackendProtocol.INSTRUMENTS:
		if not present.get(instrument, false):
			continue
		var levels: Array[String] = []
		for difficulty: String in DIFFICULTIES:
			if not tracks.get(track_name(instrument, difficulty), []).is_empty():
				levels.append(difficulty)
		if not levels.is_empty():
			out[instrument] = levels
	return out


static func is_selectable(
	song: Dictionary, chart: Dictionary, instrument: String, difficulty: String
) -> bool:
	return difficulty in available(song, chart).get(instrument, [])


## [instrumento, dificuldade] jogáveis a partir do pedido, que pode estar vazio ou indisponível:
## Cordas (senão o primeiro instrumento jogável) no Difícil (senão a mais alta que ele tem).
## [] se nada é jogável. `available`: o retorno de available().
static func choose(available: Dictionary, instrument: String, difficulty: String) -> Array:
	if available.is_empty():
		return []
	if not available.has(instrument):
		instrument = (
			DEFAULT_INSTRUMENT if available.has(DEFAULT_INSTRUMENT) else available.keys()[0]
		)
	var levels: Array = available[instrument]
	if difficulty not in levels:
		difficulty = DEFAULT_DIFFICULTY if DEFAULT_DIFFICULTY in levels else levels[-1]
	return [instrument, difficulty]
