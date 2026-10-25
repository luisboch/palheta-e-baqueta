## Instrumento e dificuldade de cada jogador (ADR 0022). Com 2 jogadores, cada um anda com o
## próprio cursor, no próprio controle (InputProfile: p1_menu_*, p2_menu_*), e dá o seu "PRONTO";
## a partida começa quando todos estão prontos. O cenário mostra a escolha de cada um
## (InstrumentStation). Instrumento que não toca na música fica desabilitado (ADR 0009).
##
## O painel "Player" da cena é o do jogador 1; o do jogador 2 é uma cópia dele.
extends Control

const START_DELAY := 0.8  ## s entre o último "PRONTO" e a partida: dá para ver o "VAMOS!"
const CURSOR_BORDER := 6  ## px da borda do cursor, na cor do jogador
## Nós dos botões dentro do painel de cada jogador.
const INSTRUMENT_ROW := "Box/Instruments"
const DIFFICULTY_ROW := "Box/Difficulties"
const INSTRUMENT_NODES := {"strings": "Strings", "bass": "Bass", "drums": "Drums"}

var world: Shell  ## a casca (null fora dela)
var picks: Array[PlayerPick] = []
var available := {}  ## InstrumentRules.available da música escolhida
var starting := false  ## todos prontos: a partida vai começar
var _panels: Array[Control] = []
var _cursors: Array[StyleBox] = []

@onready var _template: PanelContainer = %Player
@onready var _row: HBoxContainer = %Players


func _ready() -> void:
	var loaded := SongLoader.load_dir(App.selection.get("dir", ""))
	available = InstrumentRules.available(loaded["song"], loaded["chart"]) if loaded["ok"] else {}
	%SongName.text = SongCatalog.label(loaded["song"]) if loaded["ok"] else ""
	for player in App.flow.players:
		var panel: Control = _template if player == 0 else _template.duplicate()
		if player > 0:
			_row.add_child(panel)
		_panels.append(panel)
		panel.get_node("Box/Top/Name").text = "Jogador %d" % (player + 1)
		var color: Color = InstrumentStation.PLAYER_COLORS[player]
		panel.get_node("Box/Top/Name").add_theme_color_override("font_color", color)
		_cursors.append(_cursor_style(color))
		picks.append(_initial_pick(player))
		_wire(player)
	%Back.pressed.connect(back)
	_refresh()


## A escolha da vez anterior; sem ela, o jogador 2 começa num instrumento diferente do 1.
func _initial_pick(player: int) -> PlayerPick:
	var suffix := "" if player == 0 else "_p2"
	var instrument: String = App.selection.get("instrument" + suffix, "")
	if player == 1 and instrument == "":
		instrument = InstrumentRules.partner(available, picks[0].instrument)
	return PlayerPick.new(available, instrument, App.selection.get("difficulty" + suffix, ""))


## Botões só respondem ao mouse: teclado e controle andam pelo cursor de cada jogador.
func _wire(player: int) -> void:
	for id: String in INSTRUMENT_NODES:
		_button(player, INSTRUMENT_ROW, INSTRUMENT_NODES[id]).pressed.connect(
			_click.bind(player, id, "")
		)
	for id: String in InstrumentRules.DIFFICULTIES:
		_button(player, DIFFICULTY_ROW, id).pressed.connect(_click.bind(player, "", id))


func _button(player: int, row: String, node: String) -> Button:
	return _panels[player].get_node("%s/%s" % [row, node])


## O cursor: o destaque amarelo do tema com a borda grossa na cor do jogador.
func _cursor_style(color: Color) -> StyleBox:
	var style: StyleBoxFlat = _template.get_theme_stylebox("hover", "Button").duplicate()
	style.border_color = color
	style.set_border_width_all(CURSOR_BORDER)
	return style


func _unhandled_input(event: InputEvent) -> void:
	if starting:
		return
	for player in picks.size():
		if _handle(event, player):
			get_viewport().set_input_as_handled()
			return


func _handle(event: InputEvent, player: int) -> bool:
	var pick := picks[player]
	if _pressed(event, player, "accept"):
		toggle_ready(player)
	elif _pressed(event, player, "back"):
		if pick.is_ready:
			toggle_ready(player)
		else:
			back()
	elif _pressed(event, player, "left") or _pressed(event, player, "right"):
		if pick.move(1 if _pressed(event, player, "right") else -1):
			_refresh()
			_flash(player)
	elif _pressed(event, player, "up") or _pressed(event, player, "down"):
		pick.move_row(1 if _pressed(event, player, "down") else -1)
		_refresh()
		_flash(player)
	else:
		return false
	return true


## Sozinho, o jogador usa qualquer controle e as teclas dos dois lados.
func _pressed(event: InputEvent, player: int, what: String) -> bool:
	if event.is_action_pressed(InputProfile.menu_action(player, what)):
		return true
	return picks.size() == 1 and event.is_action_pressed(InputProfile.menu_action(1, what))


func _click(player: int, instrument: String, difficulty: String) -> void:
	var pick := picks[player]
	pick.pick(
		instrument if instrument != "" else pick.instrument,
		difficulty if difficulty != "" else pick.difficulty
	)
	pick.row = PlayerPick.ROW_INSTRUMENT if instrument != "" else PlayerPick.ROW_DIFFICULTY
	_refresh()


## Marca ou desmarca o pronto do jogador; com todos prontos, a partida começa.
func toggle_ready(player: int) -> void:
	var now_ready := picks[player].toggle_ready()
	_refresh()
	if picks.all(func(p: PlayerPick) -> bool: return p.is_ready):
		start()
	elif now_ready and world:
		world.burst("Pronto!", _panels[player].get_global_rect().get_center() + Vector2(0, -150))


func start() -> void:
	starting = true
	if world:
		world.burst("Vamos!")
		await get_tree().create_timer(START_DELAY).timeout
	play()


## Guarda a escolha (lembrada na próxima vez) e vai para a partida.
func play() -> void:
	App.selection["instrument"] = picks[0].instrument
	App.selection["difficulty"] = picks[0].difficulty
	App.selection["mode"] = App.flow.mode
	if picks.size() > 1:
		App.selection["instrument_p2"] = picks[1].instrument
		App.selection["difficulty_p2"] = picks[1].difficulty
	App.go(App.flow.next(MenuFlow.INSTRUMENTS))


func back() -> void:
	App.go(App.flow.back(MenuFlow.INSTRUMENTS))


func _flash(player: int) -> void:
	if world:
		var pick := picks[player]
		var button := (
			_button(player, INSTRUMENT_ROW, INSTRUMENT_NODES[pick.instrument])
			if pick.row == PlayerPick.ROW_INSTRUMENT
			else _button(player, DIFFICULTY_ROW, pick.difficulty)
		)
		world.fx.flash(button, InstrumentStation.PLAYER_COLORS[player])


## Botões, cursores e o "PRONTO" de cada painel, e as escolhas no cenário.
func _refresh() -> void:
	for player in picks.size():
		var pick := picks[player]
		for id: String in INSTRUMENT_NODES:
			var on_cursor := pick.row == PlayerPick.ROW_INSTRUMENT and id == pick.instrument
			_paint(
				_button(player, INSTRUMENT_ROW, INSTRUMENT_NODES[id]),
				not available.has(id),
				id == pick.instrument,
				on_cursor and not pick.is_ready,
				player
			)
		var levels: Array = available.get(pick.instrument, [])
		for id: String in InstrumentRules.DIFFICULTIES:
			var on_cursor := pick.row == PlayerPick.ROW_DIFFICULTY and id == pick.difficulty
			_paint(
				_button(player, DIFFICULTY_ROW, id),
				id not in levels,
				id == pick.difficulty,
				on_cursor and not pick.is_ready,
				player
			)
		_panels[player].get_node("Box/Top/Ready").visible = pick.is_ready
	if world and world.station is InstrumentStation:
		var chosen: Array[String] = []
		for pick in picks:
			chosen.append(pick.instrument)
		(world.station as InstrumentStation).show_picks(chosen, available)


func _paint(button: Button, disabled: bool, chosen: bool, cursor: bool, player: int) -> void:
	button.disabled = disabled
	button.set_pressed_no_signal(chosen)
	if cursor:
		button.add_theme_stylebox_override("pressed", _cursors[player])
		button.add_theme_color_override("font_pressed_color", Comic.INK)
	else:
		button.remove_theme_stylebox_override("pressed")
		button.remove_theme_color_override("font_pressed_color")
