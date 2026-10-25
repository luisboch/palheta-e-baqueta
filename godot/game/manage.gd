## Gerenciar músicas: o pendrive (trazer MP3s, importar, salvar a biblioteca; ADR 0003) e a
## biblioteca, onde se corrige o nome de uma música. Fica na estação "Manage" do cenário.
##
## O botão "Example" da biblioteca é o modelo de cada linha: mude o visual dele no editor.
extends Control

const INDEX_REFRESH := 1.0  ## s entre conferências do index.json (músicas importadas)

var world: Shell  ## a casca (null fora dela)
var songs: Array[Dictionary] = []
var current := {}  ## a música sendo editada
var _template: Button
var _index_time := -1
var _since_refresh := 0.0
var _edit_job: BackendJob

@onready var _drive: Control = %Drive
@onready var _list: VBoxContainer = %SongList
@onready var _empty: Label = %Empty
@onready var _edit_panel: PanelContainer = %EditPanel
@onready var _title_edit: LineEdit = %TitleEdit
@onready var _artist_edit: LineEdit = %ArtistEdit
@onready var _edit_error: Label = %EditError


func _ready() -> void:
	_template = _list.get_child(0)
	_list.remove_child(_template)
	%Back.pressed.connect(back)
	%Save.pressed.connect(save_edit)
	%Cancel.pressed.connect(close_edit)
	reload()
	%Back.grab_focus()


func _exit_tree() -> void:
	_template.free()  # fora da árvore desde o _ready: não é liberado sozinho


func _process(delta: float) -> void:
	_since_refresh += delta
	if _since_refresh >= INDEX_REFRESH:
		_since_refresh = 0.0
		if FileAccess.get_modified_time(_index_path()) != _index_time:
			reload()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _edit_panel.visible:
		close_edit()
	elif not _drive.busy():
		back()
	get_viewport().set_input_as_handled()


func _index_path() -> String:
	return App.library_dir.path_join("index.json")


## Relê o índice e refaz a lista da biblioteca.
func reload() -> void:
	_index_time = FileAccess.get_modified_time(_index_path())
	var text := (
		FileAccess.get_file_as_string(_index_path())
		if FileAccess.file_exists(_index_path())
		else ""
	)
	songs = SongCatalog.parse(text)
	for child in _list.get_children():
		child.free()  # já: a lista nova entra no mesmo quadro
	for entry in songs:
		var row: Button = _template.duplicate()
		row.text = SongCatalog.label(entry)
		row.pressed.connect(open_edit.bind(entry))
		_list.add_child(row)
	_empty.visible = songs.is_empty()


func open_edit(entry: Dictionary) -> void:
	current = entry
	_title_edit.text = str(entry.get("title", ""))
	var artist: Variant = entry.get("artist")
	_artist_edit.text = str(artist) if artist else ""
	_edit_error.text = ""
	_edit_panel.visible = true
	_title_edit.grab_focus()


func close_edit() -> void:
	_edit_panel.visible = false
	for i in songs.size():
		if songs[i]["id"] == current.get("id") and i < _list.get_child_count():
			_list.get_child(i).grab_focus()
			return
	%Back.grab_focus()


## Grava pelo backend (`pbq edit`): ele reescreve song.json, chart, song.ini e o índice, e guarda
## a correção para reprocessamentos.
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
		reload()
		close_edit()
	else:
		_edit_error.text = str(result[1].get("message", "Não foi possível salvar"))


func back() -> void:
	App.go(App.flow.back(MenuFlow.MANAGE))
