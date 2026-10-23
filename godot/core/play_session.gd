## Uma partida de um jogador: liga juiz, pontuação, volume do stem e o relógio.
##
## A cena repassa a entrada e o tempo, e recebe os eventos para desenhar. Nada aqui toca em nós
## ou áudio: dá para jogar uma música inteira num teste.
class_name PlaySession
extends RefCounted

var instrument: String
var difficulty: String
var drums: bool
var tempo: TempoMap
var notes: Array[PlayNote]
var judge: Judge
var scoring := Scoring.new()
var mix := StemMix.new()
var clock := SongClock.new()
var held := PackedInt32Array()  ## trastes pressionados agora
var duration: float  ## s: até a última nota (com sustentação)


func _init(chart: Dictionary, chosen_instrument: String, chosen_difficulty: String) -> void:
	instrument = chosen_instrument
	difficulty = chosen_difficulty
	drums = instrument == "drums"
	tempo = TempoMap.new(chart.get("tempos", []), chart.get("resolution", 192))
	var track := InstrumentRules.track_name(instrument, difficulty)
	notes = NoteTrack.build(chart, track, tempo, drums)
	judge = Judge.new(notes)
	duration = 0.0
	for note in notes:
		duration = maxf(duration, note.end_time)


func press_fret(lane: int) -> void:
	if lane not in held:
		held.append(lane)


func release_fret(lane: int) -> void:
	var i := held.find(lane)
	if i >= 0:
		held.remove_at(i)


## Palhetada agora (s). Devolve o resultado do juiz ({note, grade} ou overstrum).
func strum(now: float) -> Dictionary:
	var result := judge.strum(now, held)
	_score(result)
	return result


## Traste apertado agora, no modo sem palhetada (ADR 0015). {} se não tocou nota.
func tap(now: float) -> Dictionary:
	var result := judge.tap(now, held)
	if not result.is_empty():
		_score(result)
	return result


## Batida no pad `lane` (bateria). {} se não havia nota.
func pad(now: float, lane: int) -> Dictionary:
	var result := judge.hit_pad(now, lane)
	if not result.is_empty():
		_score(result)
	return result


## A cada frame: notas perdidas (já pontuadas como erro) e o volume do stem (dB).
func update(now: float, delta: float) -> Dictionary:
	var missed := judge.update(now)
	for note in missed:
		scoring.on_miss()
		mix.on_miss()
	return {"missed": missed, "volume_db": mix.update(delta)}


func finished(now: float) -> bool:
	return now > duration + Judge.WINDOWS["ok"] and judge.remaining() == 0


func _score(result: Dictionary) -> void:
	if result.get("grade") == Judge.OVERSTRUM:
		scoring.on_overstrum()
		mix.on_miss()
	elif result.has("note"):
		scoring.on_hit(result["grade"])
		mix.on_hit()
