## Estação do palco (escolha de música): a capa da música no telão e os refletores na cor de
## destaque dela (CoverColor). Ao trocar de música, o telão dá um clarão.
class_name StageStation
extends Station

const COVER_SHADER := preload("res://game/comic/cover_screen.gdshader")
const FLASH_TIME := 0.35  ## s do clarão no telão
const COLOR_TIME := 0.4  ## s da troca de cor das luzes

var _material := ShaderMaterial.new()
var _color := CoverColor.FALLBACK

@onready var _screen: MeshInstance3D = $Stage/Screen
@onready var _lamps: Array[Node] = $Lamps.get_children()


func _ready() -> void:
	_material.shader = COVER_SHADER
	_screen.material_override = _material


## Capa (null: sem capa) e cor das luzes.
func show_cover(texture: Texture2D, color: Color) -> void:
	_material.set_shader_parameter("cover", texture)
	_material.set_shader_parameter("has_cover", texture != null)
	_material.set_shader_parameter("tint", color)
	var flash := create_tween()
	flash.tween_method(_set_flash, 1.0, 0.0, FLASH_TIME)
	var lights := create_tween()
	lights.tween_method(_set_lamps.bind(_color, color), 0.0, 1.0, COLOR_TIME)
	_color = color


func _set_flash(value: float) -> void:
	_material.set_shader_parameter("flash", value)


func _set_lamps(t: float, from: Color, to: Color) -> void:
	for lamp: Lamp in _lamps:
		lamp.color = from.lerp(to, t)
