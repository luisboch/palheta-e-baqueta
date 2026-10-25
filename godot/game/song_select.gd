## Escolha de música: a lista à esquerda e, no cenário, o palco com a capa da música em foco no
## telão (StageStation). Escolher leva ao instrumento (MenuFlow). Música sem nenhum instrumento
## jogável não avança (ADR 0009).
##
## A lista vem do data/library/index.json e se atualiza quando uma música fica pronta. O botão
## "Example" da cena é o modelo de cada linha: mude o visual dele no editor.
extends Control

const INDEX_REFRESH := 1.0  ## s entre conferências do index.json (músicas novas ficando prontas)

var world: Shell  ## a casca (null fora dela)
var songs: Array[Dictionary] = []
var current := {}  ## a entrada do índice em foco
var loaded := {}  ## SongLoader.load_dir da música em foco
var available := {}  ## InstrumentRules.available
var _template: Button
var _index_time := -1
var _since_refresh := 0.0

@onready var _list: VBoxContainer = %SongList
@onready var _empty: Label = %Empty
@onready var _title: Label = %SongTitle
@onready var _artist: Label = %Artist
@onready var _info: Label = %Info
@onready var _absent: Label = %Absent
@onready var _status: Label = %Status


func _ready() -> void:
	_template = _list.get_child(0)
	_list.remove_child(_template)
	%Back.pressed.connect(back)
	_status.text = ""
	reload(App.selection.get("id", ""))


func _exit_tree() -> void:
	_template.free()  # fora da árvore desde o _ready: não é liberado sozinho


func _process(delta: float) -> void:
	_since_refresh += delta
	if _since_refresh < INDEX_REFRESH:
		return
	_since_refresh = 0.0
	_status.text = QueueStatus.text(QueueStatus.read(App.data_dir.path_join("queue.json")))
	if FileAccess.get_modified_time(_index_path()) != _index_time:
		reload(current.get("id", ""))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		back()
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
		row.pressed.connect(choose)
		_list.add_child(row)
		if focus_row == null or entry["id"] == keep_id:
			focus_row = row
			focus_entry = entry
	_empty.visible = songs.is_empty()
	%Card.visible = not songs.is_empty()
	if focus_row:
		focus_row.grab_focus()
		select(focus_entry)
	else:
		%Back.grab_focus()


## Mostra a música no cartão e a capa no telão.
func select(entry: Dictionary) -> void:
	current = entry
	loaded = SongLoader.load_dir(App.library_dir.path_join(entry["id"]))
	available = InstrumentRules.available(loaded["song"], loaded["chart"]) if loaded["ok"] else {}
	_title.text = str(entry.get("title", "?"))
	_artist.text = SongCatalog.artist(entry)
	var bpm: Variant = loaded["song"].get("bpm")
	_info.text = SongCatalog.duration(entry) + (" · %d BPM" % roundi(bpm) if bpm else "")
	var absent: Array[String] = []
	for id: String in PlayerPick.ORDER:
		if not available.has(id):
			absent.append(SongCatalog.INSTRUMENT_NAMES[id])
	_absent.text = absent_text(absent)
	if world and world.station is StageStation:
		var image := _load_cover()
		var texture := ImageTexture.create_from_image(image) if image else null
		(world.station as StageStation).show_cover(texture, CoverColor.dominant(image))


## "Baixo e Bateria não tocam nesta música"; "" se todos tocam.
static func absent_text(names: Array[String]) -> String:
	if names.is_empty():
		return ""
	if names.size() == PlayerPick.ORDER.size():
		return "Nenhum instrumento toca nesta música"
	var verb := "tocam" if names.size() > 1 else "toca"
	return "%s não %s nesta música" % [" e ".join(names), verb]


func _load_cover() -> Image:
	var path := SongLoader.file_path(loaded, "cover") if loaded["ok"] else ""
	return Image.load_from_file(path) if path != "" else null


## Segue para o instrumento com a música em foco.
func choose() -> void:
	if available.is_empty():
		return
	App.selection["id"] = current["id"]
	App.selection["dir"] = App.library_dir.path_join(current["id"])
	App.go(App.flow.next(MenuFlow.SONGS))


func back() -> void:
	App.go(App.flow.back(MenuFlow.SONGS))
