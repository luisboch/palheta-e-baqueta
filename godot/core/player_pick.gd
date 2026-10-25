## A escolha de um jogador na tela de instrumento (ADR 0022): instrumento, dificuldade e o
## "PRONTO". Cada jogador tem o seu cursor de duas linhas, no próprio controle: esquerda/direita
## troca a escolha da linha, cima/baixo troca de linha. Pronto, a escolha fica travada até ele
## desistir.
class_name PlayerPick
extends RefCounted

const ROW_INSTRUMENT := 0
const ROW_DIFFICULTY := 1
## A ordem na tela (e nos pedestais do cenário).
const ORDER: Array[String] = ["strings", "bass", "drums"]

var available: Dictionary  ## InstrumentRules.available da música
var instrument := ""
var difficulty := ""
var row := ROW_INSTRUMENT
var is_ready := false


func _init(song_available: Dictionary, wanted_instrument := "", wanted_difficulty := "") -> void:
	available = song_available
	_apply(wanted_instrument, wanted_difficulty)


## Falso se a música não tem nada jogável.
func playable() -> bool:
	return instrument != ""


## Anda `step` na linha do cursor (sem dar a volta). true se a escolha mudou.
func move(step: int) -> bool:
	if is_ready or not playable():
		return false
	var before := [instrument, difficulty]
	if row == ROW_INSTRUMENT:
		var ids := ORDER.filter(func(id: String) -> bool: return available.has(id))
		var at := clampi(ids.find(instrument) + step, 0, ids.size() - 1)
		_apply(ids[at], difficulty)
	else:
		var levels: Array = available[instrument]
		difficulty = levels[clampi(levels.find(difficulty) + step, 0, levels.size() - 1)]
	return [instrument, difficulty] != before


func move_row(step: int) -> void:
	if not is_ready:
		row = clampi(row + step, ROW_INSTRUMENT, ROW_DIFFICULTY)


## Escolha direta (clique): também desfaz o pronto.
func pick(wanted_instrument: String, wanted_difficulty: String) -> void:
	is_ready = false
	_apply(wanted_instrument, wanted_difficulty)


## Marca ou desmarca o pronto; devolve o estado novo.
func toggle_ready() -> bool:
	is_ready = playable() and not is_ready
	return is_ready


## Ajusta o pedido ao que a música tem (InstrumentRules.choose); mantém a dificuldade se der.
func _apply(wanted_instrument: String, wanted_difficulty: String) -> void:
	var choice := InstrumentRules.choose(available, wanted_instrument, wanted_difficulty)
	instrument = choice[0] if not choice.is_empty() else ""
	difficulty = choice[1] if not choice.is_empty() else ""
