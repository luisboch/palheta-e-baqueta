## Pontos, sequência e multiplicador.
##
## Multiplicador: 1× e sobe 1 a cada 10 acertos seguidos, até 4×. Erro ou palhetada errada zera
## a sequência (e o multiplicador). Pontos por acerto conforme a precisão, vezes o multiplicador.
## Nota sustentada: depois do ataque, pontos por batida segurada (vezes o multiplicador), com
## bônus para o whammy (ADR 0021). Soltar antes do fim não é erro: só para de somar.
class_name Scoring
extends RefCounted

const POINTS := {"perfect": 100, "good": 75, "ok": 50}
const STREAK_PER_STEP := 10
const MAX_MULTIPLIER := 4
const SUSTAIN_POINTS_PER_BEAT := 25.0  ## como no gênero: segurar 4 batidas vale 1 nota perfeita
const WHAMMY_BONUS := 0.5  ## whammy no máximo: +50% nos pontos da sustentação

var score := 0
var streak := 0
var best_streak := 0
var hits := 0
var misses := 0
var overstrums := 0
var grades := {"perfect": 0, "good": 0, "ok": 0}
var sustain_score := 0  ## parte de `score` que veio de segurar notas
var _sustain_carry := 0.0  ## fração de ponto ainda não somada (o quadro rende menos de 1 ponto)


func multiplier() -> int:
	return mini(1 + streak / STREAK_PER_STEP, MAX_MULTIPLIER)


func on_hit(grade: String) -> void:
	streak += 1
	best_streak = maxi(best_streak, streak)
	hits += 1
	grades[grade] += 1
	score += POINTS[grade] * multiplier()


## Segurou `beats` batidas de uma sustentada, com o whammy em `whammy` (0-1).
func on_sustain(beats: float, whammy: float) -> void:
	_sustain_carry += (
		beats
		* SUSTAIN_POINTS_PER_BEAT
		* (1.0 + WHAMMY_BONUS * clampf(whammy, 0.0, 1.0))
		* multiplier()
	)
	var points := int(_sustain_carry)
	_sustain_carry -= points
	score += points
	sustain_score += points


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
