## Medidor de energia de HQ: o multiplicador como um arco de 3 segmentos que enchem com a
## sequência (cada um vale um passo, ADR 0014), o "×N" grande no meio e a sequência embaixo.
## Cheio (4×), o arco fica amarelo e pulsa na batida.
class_name PowerMeter
extends Control

## Chegou ao multiplicador máximo (para a onomatopeia).
signal maxed

const FONT := preload("res://game/fonts/Bangers-Regular.ttf")
const STEPS := Scoring.MAX_MULTIPLIER - 1  ## segmentos: de 1× até 4×
const RADIUS := 62.0
const WIDTH := 20.0
const BORDER := 5.0  ## contorno de tinta em volta do arco
const GAP := 0.1  ## rad entre segmentos
const START := PI * 0.75  ## o arco começa embaixo à esquerda…
const SWEEP := PI * 1.5  ## …e dá três quartos de volta
const POINTS := 24  ## pontos por segmento desenhado
const LEVEL_COLORS: Array[Color] = [Comic.CYAN, Comic.PURPLE, Comic.YELLOW]
const MULTIPLIER_SIZE := 54
const STREAK_SIZE := 22
const PULSE_GROW := 4.0  ## px a mais no arco cheio, na batida

var multiplier := 1
var progress := 0.0  ## 0 a 1: quanto do segmento atual a sequência já encheu
var streak := 0
var pulse := 0.0  ## a batida (0 a 1), para o arco cheio pulsar


## O placar do jogador; `beat_pulse`: a batida (0 a 1).
func show_score(scoring: Scoring, beat_pulse := 0.0) -> void:
	var before := multiplier
	multiplier = scoring.multiplier()
	streak = scoring.streak
	progress = (
		1.0
		if multiplier >= Scoring.MAX_MULTIPLIER
		else float(streak % Scoring.STREAK_PER_STEP) / Scoring.STREAK_PER_STEP
	)
	pulse = beat_pulse
	if multiplier == Scoring.MAX_MULTIPLIER and before < multiplier:
		maxed.emit()
	queue_redraw()


func _draw() -> void:
	var center := size / 2
	var full := multiplier >= Scoring.MAX_MULTIPLIER
	var grow := PULSE_GROW * pulse if full else 0.0
	for i in STEPS:
		var a0 := START + SWEEP * i / STEPS + GAP / 2
		var a1 := START + SWEEP * (i + 1) / STEPS - GAP / 2
		draw_arc(center, RADIUS, a0, a1, POINTS, Comic.INK, WIDTH + BORDER * 2)
		draw_arc(center, RADIUS, a0, a1, POINTS, Comic.CREAM.darkened(0.35), WIDTH)
		var fill := 1.0 if i < multiplier - 1 else (progress if i == multiplier - 1 else 0.0)
		if full:
			fill = 1.0
		if fill > 0.0:
			var color := LEVEL_COLORS[STEPS - 1] if full else LEVEL_COLORS[i]
			draw_arc(center, RADIUS, a0, a0 + (a1 - a0) * fill, POINTS, color, WIDTH + grow)
	_text("×%d" % multiplier, center + Vector2(0, MULTIPLIER_SIZE * 0.32), MULTIPLIER_SIZE)
	_text("%d seguidas" % streak, center + Vector2(0, RADIUS + STREAK_SIZE), STREAK_SIZE)


func _text(text: String, at: Vector2, font_size: int) -> void:
	var width := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var pos := at - Vector2(width / 2, 0)
	draw_string_outline(
		FONT, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, font_size / 5, Comic.INK
	)
	draw_string(FONT, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Comic.CREAM)
