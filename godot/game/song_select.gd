## Escolha de música, instrumento e dificuldade. Instrumento que não toca na música fica
## desabilitado (ADR 0009); dificuldade sem notas também.
##
## A lista vem do data/library/index.json e se atualiza quando uma música fica pronta. O botão
## "Example" da cena é o modelo de cada linha: mude o visual dele no editor.
extends Control

const INDEX_REFRESH := 1.0  ## s entre conferências do index.json (músicas novas ficando prontas)

var songs: Array[Dictionary] = []
var current := {}  ## a entrada do índice em foco
var loaded := {}  ## SongLoader.load_dir da música em foco
var available := {}  ## InstrumentRules.available
var instrument := ""
var difficulty := ""
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
@onready var _instrument_buttons := {"strings": %Strings, "bass": %Bass, "drums": %Drums}
@onready
var _difficulty_buttons := {"Easy": %Easy, "Medium": %Medium, "Hard": %Hard, "Expert": %Expert}


func _ready() -> void:
	_template = _list.get_child(0)
	_list.remove_child(_template)
	for id: String in _instrument_buttons:
		_instrument_buttons[id].pressed.connect(_choose_instrument.bind(id))
	for id: String in _difficulty_buttons:
		_difficulty_buttons[id].pressed.connect(_choose_difficulty.bind(id))
	_start.pressed.connect(play)
	%Edit.pressed.connect(open_edit)
	%Back.pressed.connect(App.goto.bind(App.MAIN_MENU))
	%Save.pressed.connect(save_edit)
	%Cancel.pressed.connect(close_edit)
	_status.text = ""
	instrument = App.selection.get("instrument", "")
	difficulty = App.selection.get("difficulty", "")
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
	for id: String in _instrument_buttons:
		_instrument_buttons[id].disabled = not available.has(id)
		if not available.has(id):
			absent.append(SongCatalog.INSTRUMENT_NAMES[id])
	_absent.text = absent_text(absent)
	_start.disabled = available.is_empty()
	_apply_choice(instrument, difficulty)


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


func _choose_instrument(id: String) -> void:
	_apply_choice(id, difficulty)


func _choose_difficulty(id: String) -> void:
	_apply_choice(instrument, id)


## Ajusta o pedido ao que a música tem (InstrumentRules.choose) e marca os botões.
func _apply_choice(wanted_instrument: String, wanted_difficulty: String) -> void:
	var choice := InstrumentRules.choose(available, wanted_instrument, wanted_difficulty)
	if choice.is_empty():
		return
	instrument = choice[0]
	difficulty = choice[1]
	_instrument_buttons[instrument].button_pressed = true
	for id: String in _difficulty_buttons:
		_difficulty_buttons[id].disabled = id not in available[instrument]
	_difficulty_buttons[difficulty].button_pressed = true


func play() -> void:
	if available.is_empty():
		return
	App.selection = {
		"id": current["id"],
		"dir": App.library_dir.path_join(current["id"]),
		"instrument": instrument,
		"difficulty": difficulty,
	}
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
