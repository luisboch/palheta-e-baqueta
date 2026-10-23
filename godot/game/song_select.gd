## Escolha de música, modo (Solo, Banda, Duelo), instrumento e dificuldade de cada jogador.
## Instrumento que não toca na música fica desabilitado (ADR 0009); dificuldade sem notas também.
##
## A lista vem do data/library/index.json e se atualiza quando uma música fica pronta. O botão
## "Example" da cena é o modelo de cada linha: mude o visual dele no editor.
extends Control

const INDEX_REFRESH := 1.0  ## s entre conferências do index.json (músicas novas ficando prontas)
const MODES := ["solo", "coop", "versus"]  ## Solo, Banda e Duelo (ADR 0017)

var songs: Array[Dictionary] = []
var current := {}  ## a entrada do índice em foco
var loaded := {}  ## SongLoader.load_dir da música em foco
var available := {}  ## InstrumentRules.available
var mode := "solo"
var instrument := ""
var difficulty := ""
var instrument_2 := ""  ## do segundo jogador; "" até escolher (sugere outro instrumento)
var difficulty_2 := ""
var _template: Button
var _index_time := -1
var _since_refresh := 0.0
var _edit_job: BackendJob

@onready var _background: Background = $Background
@onready var _list: VBoxContainer = %SongList
@onready var _empty: Label = %Empty
@onready var _cover: TextureRect = %Cover
@onready var _title: Label = %SongTitle
@onready var _artist: Label = %Artist
@onready var _info: Label = %Info
@onready var _absent: Label = %Absent
@onready var _start: Button = %Start
@onready var _status: Label = %Status
@onready var _edit_panel: PanelContainer = %EditPanel
@onready var _title_edit: LineEdit = %TitleEdit
@onready var _artist_edit: LineEdit = %ArtistEdit
@onready var _edit_error: Label = %EditError
@onready var _mode_buttons := {"solo": %Solo, "coop": %Coop, "versus": %Versus}
## Botões de cada jogador: [P1, P2].
@onready var _instrument_buttons: Array[Dictionary] = [
	{"strings": %Strings, "bass": %Bass, "drums": %Drums},
	{"strings": %Strings2, "bass": %Bass2, "drums": %Drums2},
]
@onready var _difficulty_buttons: Array[Dictionary] = [
	{"Easy": %Easy, "Medium": %Medium, "Hard": %Hard, "Expert": %Expert},
	{"Easy": %Easy2, "Medium": %Medium2, "Hard": %Hard2, "Expert": %Expert2},
]


func _ready() -> void:
	_template = _list.get_child(0)
	_list.remove_child(_template)
	for id: String in _mode_buttons:
		_mode_buttons[id].pressed.connect(choose_mode.bind(id))
	for player in 2:
		for id: String in _instrument_buttons[player]:
			_instrument_buttons[player][id].pressed.connect(_choose_instrument.bind(player, id))
		for id: String in _difficulty_buttons[player]:
			_difficulty_buttons[player][id].pressed.connect(_choose_difficulty.bind(player, id))
	_start.pressed.connect(play)
	%Edit.pressed.connect(open_edit)
	%Back.pressed.connect(App.goto.bind(App.MAIN_MENU))
	%Save.pressed.connect(save_edit)
	%Cancel.pressed.connect(close_edit)
	_status.text = ""
	instrument = App.selection.get("instrument", "")
	difficulty = App.selection.get("difficulty", "")
	instrument_2 = App.selection.get("instrument_p2", "")
	difficulty_2 = App.selection.get("difficulty_p2", "")
	choose_mode(App.selection.get("mode", "solo"))
	reload(App.selection.get("id", ""))


func _exit_tree() -> void:
	_template.free()  # fora da árvore desde o _ready: não é liberado sozinho


func _process(delta: float) -> void:
	_background.update_idle(delta)
	_since_refresh += delta
	if _since_refresh < INDEX_REFRESH:
		return
	_since_refresh = 0.0
	_status.text = QueueStatus.text(QueueStatus.read(App.data_dir.path_join("queue.json")))
	if FileAccess.get_modified_time(_index_path()) != _index_time:
		reload(current.get("id", ""))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _edit_panel.visible:
			close_edit()
		else:
			App.goto(App.MAIN_MENU)
		get_viewport().set_input_as_handled()


func _index_path() -> String:
	return App.library_dir.path_join("index.json")


## Relê o índice e refaz a lista, mantendo o foco na música `keep_id` se ela existir.
func reload(keep_id: String) -> void:
	_index_time = FileAccess.get_modified_time(_index_path())
	var text := (
		FileAccess.get_file_as_string(_index_path())
		if FileAccess.file_exists(_index_path())
		else ""
	)
	songs = SongCatalog.parse(text)
	for child in _list.get_children():
		child.free()  # já: a lista nova entra no mesmo quadro
	var focus_row: Button = null
	var focus_entry := {}
	for entry in songs:
		var row: Button = _template.duplicate()
		row.text = SongCatalog.label(entry)
		row.focus_entered.connect(select.bind(entry))
		row.pressed.connect(_start.grab_focus)
		_list.add_child(row)
		if focus_row == null or entry["id"] == keep_id:
			focus_row = row
			focus_entry = entry
	_empty.visible = songs.is_empty()
	%Details.visible = not songs.is_empty()
	if focus_row:
		focus_row.grab_focus()
		select(focus_entry)


## Mostra a música e habilita só os instrumentos e dificuldades jogáveis.
func select(entry: Dictionary) -> void:
	current = entry
	loaded = SongLoader.load_dir(App.library_dir.path_join(entry["id"]))
	available = InstrumentRules.available(loaded["song"], loaded["chart"]) if loaded["ok"] else {}
	_title.text = str(entry.get("title", "?"))
	_artist.text = SongCatalog.artist(entry)
	var bpm: Variant = loaded["song"].get("bpm")
	_info.text = SongCatalog.duration(entry) + (" · %d BPM" % roundi(bpm) if bpm else "")
	_cover.texture = _load_cover()
	var absent: Array[String] = []
	for id: String in _instrument_buttons[0]:  # a ordem da tela
		for buttons in _instrument_buttons:
			buttons[id].disabled = not available.has(id)
		if not available.has(id):
			absent.append(SongCatalog.INSTRUMENT_NAMES[id])
	_absent.text = absent_text(absent)
	_start.disabled = available.is_empty()
	_apply_choice(0, instrument, difficulty)
	_apply_choice(1, instrument_2, difficulty_2)


## Solo, Banda ("coop") ou Duelo ("versus"); com 2 jogadores, mostra as escolhas do segundo.
func choose_mode(id: String) -> void:
	mode = id if id in MODES else "solo"
	_mode_buttons[mode].button_pressed = true
	var two := mode != "solo"
	%Player2.visible = two
	%InstrumentLabel.text = "Jogador 1" if two else "Instrumento e dificuldade"


## "Baixo e Bateria não tocam nesta música"; "" se todos tocam.
static func absent_text(names: Array[String]) -> String:
	if names.is_empty():
		return ""
	var verb := "tocam" if names.size() > 1 else "toca"
	return "%s não %s nesta música" % [" e ".join(names), verb]


func _load_cover() -> Texture2D:
	var path := SongLoader.file_path(loaded, "cover") if loaded["ok"] else ""
	var image := Image.load_from_file(path) if path != "" else null
	return ImageTexture.create_from_image(image) if image else null


func _choose_instrument(player: int, id: String) -> void:
	_apply_choice(player, id, difficulty if player == 0 else difficulty_2)


func _choose_difficulty(player: int, id: String) -> void:
	_apply_choice(player, instrument if player == 0 else instrument_2, id)


## Ajusta o pedido do jogador (0 ou 1) ao que a música tem (InstrumentRules.choose) e marca os
## botões. Sem pedido do segundo, ele começa num instrumento diferente do primeiro.
func _apply_choice(player: int, wanted_instrument: String, wanted_difficulty: String) -> void:
	if player == 1 and wanted_instrument == "":
		wanted_instrument = InstrumentRules.partner(available, instrument)
	var choice := InstrumentRules.choose(available, wanted_instrument, wanted_difficulty)
	if choice.is_empty():
		return
	if player == 0:
		instrument = choice[0]
		difficulty = choice[1]
	else:
		instrument_2 = choice[0]
		difficulty_2 = choice[1]
	_instrument_buttons[player][choice[0]].button_pressed = true
	for id: String in _difficulty_buttons[player]:
		_difficulty_buttons[player][id].disabled = id not in available[choice[0]]
	_difficulty_buttons[player][choice[1]].button_pressed = true


func play() -> void:
	if available.is_empty():
		return
	App.selection = {
		"id": current["id"],
		"dir": App.library_dir.path_join(current["id"]),
		"instrument": instrument,
		"difficulty": difficulty,
		"mode": mode,
	}
	if mode != "solo":
		App.selection["instrument_p2"] = instrument_2
		App.selection["difficulty_p2"] = difficulty_2
	App.goto(App.PLAY)


func open_edit() -> void:
	_title_edit.text = str(current.get("title", ""))
	var artist: Variant = current.get("artist")
	_artist_edit.text = str(artist) if artist else ""
	_edit_error.text = ""
	_edit_panel.visible = true
	_title_edit.grab_focus()


func close_edit() -> void:
	_edit_panel.visible = false
	%Edit.grab_focus()


## Grava pelo backend (`pbq edit`): ele reescreve song.json, chart, song.ini e o índice.
func save_edit() -> void:
	if _edit_job and _edit_job.running:
		return
	_edit_job = App.run_pbq(
		["edit", current["id"], "--title", _title_edit.text, "--artist", _artist_edit.text]
	)
	if _edit_job == null:
		_edit_error.text = "Backend não instalado (rode scripts/setup.sh)"
		return
	_edit_error.text = "Salvando…"
	var result: Array = await _edit_job.finished
	if result[0]:
		close_edit()
		reload(current["id"])
	else:
		_edit_error.text = str(result[1].get("message", "Não foi possível salvar"))
