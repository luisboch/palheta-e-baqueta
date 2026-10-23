## Uma nota a tocar: um acorde (Cordas e baixo) ou uma peça (bateria), já em segundos.
class_name PlayNote
extends RefCounted

enum State { PENDING, HIT, MISSED }

var tick: int
var time: float  ## s, a partir do início do áudio
var end_time: float  ## igual a `time` se não for sustentada
var lanes: PackedInt32Array  ## trastes do acorde (Cordas/baixo) ou a peça (bateria: 1 lane)
var cymbal := false  ## bateria: prato (desenha prato, não pad)
var state := State.PENDING
var grade := ""  ## perfect, good, ok (se acertou)


func _init(
	note_tick: int, note_time: float, note_lanes: PackedInt32Array, end: float = -1.0
) -> void:
	tick = note_tick
	time = note_time
	lanes = note_lanes
	end_time = end if end >= note_time else note_time


func is_sustain() -> bool:
	return end_time > time
