## Julga cada palhetada (Cordas, baixo) ou batida de pad (bateria) contra as notas.
##
## Janelas (± s em volta da nota): perfect, good, ok. Fora da maior, não acertou.
## Cordas e baixo: a palhetada vale para a nota pendente mais antiga dentro da janela cujos
## trastes batem: acorde = exatamente os trastes do acorde; nota simples = o traste mais agudo
## pressionado (segurar os de baixo é permitido, como no gênero). Palhetada sem nota que bata é
## "overstrum": quebra a sequência, mas a nota continua lá até sair da janela.
## Bateria: cada pad acerta a nota pendente mais antiga daquela peça na janela; batida a mais não
## pune (bateristas enfeitam).
class_name Judge
extends RefCounted

const WINDOWS := {"perfect": 0.045, "good": 0.09, "ok": 0.135}
const OVERSTRUM := "overstrum"

var notes: Array[PlayNote]
var window: float
var _first := 0  ## índice da primeira nota ainda não resolvida (acelera a busca)


func _init(track_notes: Array[PlayNote]) -> void:
	notes = track_notes
	window = WINDOWS["ok"]


static func grade_for(error: float) -> String:
	for name: String in ["perfect", "good", "ok"]:
		if absf(error) <= WINDOWS[name]:
			return name
	return ""


## Notas que passaram da janela sem serem tocadas: viram MISSED (e são devolvidas).
func update(now: float) -> Array[PlayNote]:
	var missed: Array[PlayNote] = []
	var i := _first
	while i < notes.size() and notes[i].time + window < now:
		if notes[i].state == PlayNote.State.PENDING:
			notes[i].state = PlayNote.State.MISSED
			missed.append(notes[i])
		i += 1
	while _first < notes.size() and notes[_first].state != PlayNote.State.PENDING:
		_first += 1
	return missed


static func frets_match(note_lanes: PackedInt32Array, held: PackedInt32Array) -> bool:
	if held.is_empty():
		return false
	if note_lanes.size() > 1:
		var sorted_held := held.duplicate()
		sorted_held.sort()
		return sorted_held == note_lanes
	var top := held[0]
	for lane in held:
		top = maxi(top, lane)
	return top == note_lanes[0]


## Palhetada com os trastes `held` pressionados. Devolve {note, grade} ou {grade: "overstrum"}.
func strum(now: float, held: PackedInt32Array) -> Dictionary:
	for i in range(_first, notes.size()):
		var note := notes[i]
		if note.time - window > now:
			break
		if note.state != PlayNote.State.PENDING or note.time + window < now:
			continue
		if frets_match(note.lanes, held):
			return _hit(note, now)
	return {"grade": OVERSTRUM}


## Batida no pad `lane` (bateria). Devolve {note, grade} ou {} se não havia nota dela.
func hit_pad(now: float, lane: int) -> Dictionary:
	for i in range(_first, notes.size()):
		var note := notes[i]
		if note.time - window > now:
			break
		if (
			note.state == PlayNote.State.PENDING
			and note.lanes[0] == lane
			and absf(note.time - now) <= window
		):
			return _hit(note, now)
	return {}


func _hit(note: PlayNote, now: float) -> Dictionary:
	note.state = PlayNote.State.HIT
	note.grade = grade_for(now - note.time)
	return {"note": note, "grade": note.grade}


func remaining() -> int:
	var count := 0
	for i in range(_first, notes.size()):
		if notes[i].state == PlayNote.State.PENDING:
			count += 1
	return count
