## Estação dos instrumentos: guitarra (Cordas), baixo e bateria em pedestais. O instrumento de
## cada jogador sobe, gira mais rápido e ganha a luz da cor dele (P1 vermelho, P2 azul; os dois
## no mesmo, amarelo). Instrumento que não toca na música fica apagado e parado.
class_name InstrumentStation
extends Station

const PLAYER_COLORS: Array[Color] = [Comic.RED, Comic.BLUE]
const SHARED_COLOR := Comic.YELLOW
const LIFT := 0.45  ## m que o instrumento escolhido sobe
const SPIN_CHOSEN := 70.0  ## graus/s
const SPIN_IDLE := 15.0
const TIME := 0.3
const DIM := Color(0.45, 0.45, 0.5)  ## instrumento ausente

var _base := {}

@onready var _items := {"strings": $Guitar, "bass": $Bass, "drums": $Drums}
@onready var _lamps := {"strings": $LampStrings, "bass": $LampBass, "drums": $LampDrums}


func _ready() -> void:
	for id: String in _items:
		_base[id] = _items[id].position


## `picks`: o instrumento de cada jogador; `available`: o que toca na música.
func show_picks(picks: Array[String], available: Dictionary) -> void:
	for id: String in _items:
		var who: Array[int] = []
		for player in picks.size():
			if picks[player] == id:
				who.append(player)
		var item: Node3D = _items[id]
		var lamp: Lamp = _lamps[id]
		lamp.on = not who.is_empty()
		if not who.is_empty():
			lamp.color = PLAYER_COLORS[who[0]] if who.size() == 1 else SHARED_COLOR
		item.set(
			"degrees_per_second", Vector3.UP * (SPIN_CHOSEN if not who.is_empty() else SPIN_IDLE)
		)
		if not available.has(id):
			item.set("degrees_per_second", Vector3.ZERO)
		_set_dim(item, not available.has(id))
		var lift := LIFT if not who.is_empty() else 0.0
		var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(item, "position", _base[id] + Vector3.UP * lift, TIME)


## Ausente fica escuro (modulado), sem perder o material toon de cada peça.
func _set_dim(item: Node3D, dim: bool) -> void:
	for node: MeshInstance3D in item.find_children("*", "MeshInstance3D", true, false):
		node.set_instance_shader_parameter("dim", DIM if dim else Color.WHITE)
