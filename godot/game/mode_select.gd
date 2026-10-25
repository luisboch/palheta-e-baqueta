## Modo de 2 jogadores (ADR 0017): Banda, tocando juntos com os pontos somados, ou Duelo, um
## contra o outro. O cenário levanta a palavra do modo em foco (ModeStation).
extends Control

var world: Shell  ## a casca (null fora dela)

@onready var _buttons := {"coop": %Coop, "versus": %Versus}


func _ready() -> void:
	for id: String in _buttons:
		var button: Button = _buttons[id]
		button.pressed.connect(choose.bind(id))
		button.focus_entered.connect(_show.bind(id))
	%Back.pressed.connect(back)
	_buttons[App.flow.mode_2p].grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		back()
		get_viewport().set_input_as_handled()


func choose(id: String) -> void:
	App.go(App.flow.choose_mode(id))


func back() -> void:
	App.go(App.flow.back(MenuFlow.MODE))


func _show(id: String) -> void:
	if world and world.station is ModeStation:
		(world.station as ModeStation).highlight(id)
