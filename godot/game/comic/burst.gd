## Onomatopeia de quadrinho ("PRONTO!", "VAMOS!"): um balão de explosão com o texto, que estoura,
## fica um instante e some. Só nos momentos que contam, para não virar ruído.
class_name Burst
extends Node2D

const FONT := preload("res://game/fonts/Bangers-Regular.ttf")
const FONT_SIZE := 64
const OUTLINE := 12  ## px do contorno do texto
const SPIKES := 13  ## pontas do balão
const INNER := 0.72  ## raio dos vales, relativo às pontas
const BORDER := 6.0
const POP_TIME := 0.14
const HOLD_TIME := 0.45
const FADE_TIME := 0.2
const TILT := 0.12  ## rad: o balão nasce um pouco torto

var text := ""
var fill := Comic.YELLOW
var _radius := 100.0


static func spawn(parent: Node, words: String, at: Vector2, color := Comic.YELLOW) -> Burst:
	var burst := Burst.new()
	burst.text = words
	burst.fill = color
	burst.position = at
	parent.add_child(burst)
	return burst


func _ready() -> void:
	var size := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	_radius = maxf(size.x * 0.7, 90.0)
	rotation = randf_range(-TILT, TILT)
	scale = Vector2.ZERO
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)
	tween.tween_interval(HOLD_TIME)
	tween.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(queue_free)


func _draw() -> void:
	var points := PackedVector2Array()
	for i in SPIKES * 2:
		# Pontas de tamanhos alternados: o balão não fica um sol certinho.
		var r := _radius * (1.0 if i % 2 == 0 else INNER) * (1.0 + 0.08 * sin(i * 2.3))
		points.append(Vector2.from_angle(TAU * i / (SPIKES * 2)) * r * Vector2(1.25, 0.8))
	draw_colored_polygon(points, fill)
	points.append(points[0])
	draw_polyline(points, Comic.INK, BORDER)
	var size := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	var at := Vector2(-size.x / 2, FONT_SIZE * 0.35)
	draw_string_outline(
		FONT, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, OUTLINE, Comic.INK
	)
	draw_string(FONT, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Comic.RED)
