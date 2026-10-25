## Estação do modo de 2 jogadores: "BANDA" e "DUELO" em letras 3D; o modo em foco sobe e cresce,
## o outro encolhe.
class_name ModeStation
extends Station

const LIFT := 0.4  ## m que o modo em foco sobe
const GROW := 1.15
const SHRINK := 0.85
const TIME := 0.3

var _base := {}

@onready var _items := {"coop": $Coop/Word, "versus": $Versus/Word}


func _ready() -> void:
	for id: String in _items:
		_base[id] = _items[id].position


func highlight(id: String) -> void:
	for key: String in _items:
		var node: Node3D = _items[key]
		var on := key == id
		var tween := create_tween().set_parallel().set_trans(Tween.TRANS_BACK)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(node, "scale", Vector3.ONE * (GROW if on else SHRINK), TIME)
		tween.tween_property(
			node, "position", _base[key] + Vector3.UP * (LIFT if on else 0.0), TIME
		)
