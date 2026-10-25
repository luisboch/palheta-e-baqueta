## Refletor do cenário (modelo spotlight.glb): a cabeça varre de um lado para o outro e a luz,
## com o feixe visível, tem a cor que a estação pedir. Varredura 0: refletor parado.
class_name Lamp
extends Node3D

@export var sweep_degrees := 25.0  ## para cada lado
@export var sweep_seconds := 4.0  ## ida e volta
@export var phase := 0.0  ## 0 a 1: refletores vizinhos fora de compasso
@export var tilt_degrees := 0.0  ## inclinação parada, para a frente (+) ou para trás (-)
@export var color := Comic.CREAM:
	set = set_color
@export var on := true:
	set = set_on

var _time := 0.0

@onready var _head: Node3D = $Model/Head
@onready var _light: SpotLight3D = $Model/Head/Light
@onready var _beam: GeometryInstance3D = $Model/Head/Beam


func _ready() -> void:
	set_color(color)
	set_on(on)
	_process(0.0)


func _process(delta: float) -> void:
	_time += delta
	var swing := sin((_time / sweep_seconds + phase) * TAU) if sweep_degrees > 0.0 else 0.0
	_head.rotation_degrees = Vector3(
		tilt_degrees + swing * sweep_degrees * 0.3, 0, swing * sweep_degrees
	)


func set_color(value: Color) -> void:
	color = value
	if is_node_ready():
		_light.light_color = value
		_beam.set_instance_shader_parameter("beam_color", value)


func set_on(value: bool) -> void:
	on = value
	if is_node_ready():
		_light.visible = value
		_beam.visible = value
