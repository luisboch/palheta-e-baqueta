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
var whammy := 0.0  ## alavanca agora (0-1), vinda de Whammy na cena
var sustain: PlayNote  ## sustentada sendo segurada agora (null se nenhuma)
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


## Solta os trastes que o jogo acha apertados mas o controle já soltou (`pressed` = os que estão
## apertados de verdade). Um evento de soltar perdido (pausa, troca de foco, gatilho analógico)
## deixaria o traste preso, e como a nota simples vale pelo traste mais agudo, travaria as
## próximas notas. Devolve os trastes soltos.
func sync_frets(pressed: PackedInt32Array) -> PackedInt32Array:
	var released := PackedInt32Array()
	for lane in held.duplicate():
		if lane not in pressed:
			release_fret(lane)
			released.append(lane)
	return released


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


## A cada frame: notas perdidas (já pontuadas como erro), a sustentada que o jogador soltou
## antes do fim (`dropped`, null se nenhuma), o volume do stem (dB) e o whammy que vale para o
## som (`bend`: só enquanto segura uma sustentada).
func update(now: float, delta: float) -> Dictionary:
	var missed := judge.update(now)
	for note in missed:
		scoring.on_miss()
		mix.on_miss()
	var dropped := _hold(now)
	return {
		"missed": missed,
		"dropped": dropped,
		"volume_db": mix.update(delta),
		"bend": whammy if sustain else 0.0,
	}


## Segura a sustentada até `now`: pontua as batidas desde o último quadro e acaba no fim dela
## ou quando os trastes deixam de bater (aí devolve a nota, que foi solta).
func _hold(now: float) -> PlayNote:
	if sustain == null:
		return null
	var note := sustain
	if not Judge.frets_match(note.lanes, held):
		_end_sustain()
		return note
	var until := clampf(now, note.held_until, note.end_time)
	var beats := (tempo.tick(until) - tempo.tick(note.held_until)) / tempo.resolution
	scoring.on_sustain(beats, whammy)
	note.held_until = until
	if until >= note.end_time:
		_end_sustain()
	return null


func _end_sustain() -> void:
	sustain.holding = false
	sustain = null


func finished(now: float) -> bool:
	return now > duration + Judge.WINDOWS["ok"] and judge.remaining() == 0


func _score(result: Dictionary) -> void:
	if result.get("grade") == Judge.OVERSTRUM:
		scoring.on_overstrum()
		mix.on_miss()
	elif result.has("note"):
		scoring.on_hit(result["grade"])
		mix.on_hit()
		var note: PlayNote = result["note"]
		if note.is_sustain():
			if sustain:
				_end_sustain()  # a nova começa antes do fim da outra: fica a nova
			# Os pontos contam do tempo da nota, mesmo se o ataque veio um pouco antes ou depois.
			sustain = note
			note.holding = true
