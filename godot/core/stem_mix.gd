## Volume do stem do jogador: abaixa quando ele erra e volta quando ele acerta.
##
## Em dB, com transição suave (`speed` dB por segundo) para não estalar.
class_name StemMix
extends RefCounted

const NORMAL_DB := 0.0
const MISSED_DB := -18.0  ## baixo o bastante para notar, sem sumir com o instrumento
const SPEED_DB_PER_S := 60.0

var volume_db := NORMAL_DB
var _target := NORMAL_DB


func on_hit() -> void:
	_target = NORMAL_DB


func on_miss() -> void:
	_target = MISSED_DB


func update(delta: float) -> float:
	volume_db = move_toward(volume_db, _target, SPEED_DB_PER_S * delta)
	return volume_db
