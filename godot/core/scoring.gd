## Pontos, sequência e multiplicador.
##
## Multiplicador: 1× e sobe 1 a cada 10 acertos seguidos, até 4×. Erro ou palhetada errada zera
## a sequência (e o multiplicador). Pontos por acerto conforme a precisão, vezes o multiplicador.
class_name Scoring
extends RefCounted

const POINTS := {"perfect": 100, "good": 75, "ok": 50}
const STREAK_PER_STEP := 10
const MAX_MULTIPLIER := 4

var score := 0
var streak := 0
var best_streak := 0
var hits := 0
var misses := 0
var overstrums := 0
var grades := {"perfect": 0, "good": 0, "ok": 0}


func multiplier() -> int:
	return mini(1 + streak / STREAK_PER_STEP, MAX_MULTIPLIER)


func on_hit(grade: String) -> void:
	streak += 1
	best_streak = maxi(best_streak, streak)
	hits += 1
	grades[grade] += 1
	score += POINTS[grade] * multiplier()


func on_miss() -> void:
	misses += 1
	streak = 0


func on_overstrum() -> void:
	overstrums += 1
	streak = 0


## Fração de notas acertadas (0-1); sem notas tocadas ainda, 1.
func accuracy() -> float:
	var total := hits + misses
	return float(hits) / total if total else 1.0
