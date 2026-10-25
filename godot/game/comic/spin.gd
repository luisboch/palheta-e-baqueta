## Enfeite do cenário: gira e flutua sem parar (emblema, instrumentos, globo, discos).
## Ajuste pelo inspetor do editor.
extends Node3D

@export var degrees_per_second := Vector3(0.0, 20.0, 0.0)
@export var bob_height := 0.0  ## m de sobe e desce; 0 desliga
@export var bob_seconds := 3.0  ## duração de um sobe e desce

var _time := 0.0
var _base_y := 0.0


func _ready() -> void:
	_base_y = position.y


func _process(delta: float) -> void:
	_time += delta
	rotation_degrees += degrees_per_second * delta
	if bob_height > 0.0:
		position.y = _base_y + sin(_time * TAU / bob_seconds) * bob_height
