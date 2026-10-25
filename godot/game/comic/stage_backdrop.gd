## O palco (stage.glb) com a capa da música no telão, refletores e globo espelhado. Fica na
## estação de músicas dos menus e atrás da pista na partida, onde segue a música: refletores
## varrendo no compasso e mais fortes na batida, globo girando com os médios, telão piscando de
## leve no começo de cada compasso.
class_name StageBackdrop
extends Node3D

const COVER_SHADER := preload("res://game/comic/cover_screen.gdshader")
const FLASH_TIME := 0.35  ## s do clarão no telão ao trocar a capa
const COLOR_TIME := 0.4  ## s da troca de cor das luzes
const BAR_FLASH := 0.2  ## clarão do telão no começo do compasso, na partida
const BAR_FLASH_SPAN := 0.12  ## parte do compasso que o clarão dura
const BALL_SPIN := 30.0  ## graus/s do globo parado
const BALL_SPIN_MID := 120.0  ## graus/s a mais com os médios no máximo

var _material := ShaderMaterial.new()
var _color := CoverColor.FALLBACK

@onready var _screen: MeshInstance3D = $Stage/Screen
@onready var _lamps: Array[Node] = $Lamps.get_children()
@onready var _ball: Node3D = $MirrorBall


func _ready() -> void:
	_material.shader = COVER_SHADER
	_screen.material_override = _material
	Comic.toonify(self)


## Capa (null: sem capa) e cor das luzes; o telão dá um clarão.
func show_cover(texture: Texture2D, color: Color) -> void:
	_material.set_shader_parameter("cover", texture)
	_material.set_shader_parameter("has_cover", texture != null)
	_material.set_shader_parameter("tint", color)
	var flash := create_tween()
	flash.tween_method(_set_flash, 1.0, 0.0, FLASH_TIME)
	var lights := create_tween()
	lights.tween_method(_set_lamps.bind(_color, color), 0.0, 1.0, COLOR_TIME)
	_color = color


## Um quadro da partida: `levels` são graves, médios e agudos (SpectrumBands), de 0 a 1.
func update(now: float, grid: BeatGrid, levels: PackedFloat32Array) -> void:
	# Uma varredura de ida e volta a cada 2 compassos; vizinhos em sentidos opostos.
	var swing := sin(PI * (grid.bar_at(now) + grid.bar_phase(now)))
	var pulse := grid.pulse(now)
	for i in _lamps.size():
		(_lamps[i] as Lamp).drive(swing if i % 2 == 0 else -swing, pulse)
	_ball.set("degrees_per_second", Vector3.UP * (BALL_SPIN + BALL_SPIN_MID * levels[1]))
	var bar := grid.bar_phase(now)
	_set_flash(BAR_FLASH * maxf(1.0 - bar / BAR_FLASH_SPAN, 0.0) if bar >= 0.0 else 0.0)


func _set_flash(value: float) -> void:
	_material.set_shader_parameter("flash", value)


func _set_lamps(t: float, from: Color, to: Color) -> void:
	for lamp: Lamp in _lamps:
		lamp.color = from.lerp(to, t)
