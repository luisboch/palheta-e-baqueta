## Pendrive pelo menu (ADR 0003): escolher o pendrive e uma ação. Cada ação é um comando
## `pbq drive …` com andamento na barra (docs/backend-protocol.md).
##
## O botão "Example" da cena é o modelo de cada pendrive da lista.
extends Control

## Ação → [comando, o que dizer ao terminar (%d = quantas músicas)].
const ACTIONS := {
	"process": ["process", "%d MP3s novos na fila. Eles ficam prontos sozinhos."],
	"import": ["import", "%d músicas importadas."],
	"export": ["export", "%d músicas salvas no pendrive."],
}
const PHASES := {"reading": "Lendo o pendrive", "copying": "Copiando"}

var drives: Array = []  ## [{path, name, has_folder}]
var mount := ""  ## pendrive escolhido
var _template: Button
var _job: BackendJob

@onready var _background: Background = $Background
@onready var _list: VBoxContainer = %DriveList
@onready var _no_drive: Label = %NoDrive
@onready var _progress: ProgressBar = %Progress
@onready var _message: Label = %Message
@onready var _actions := {"process": %Process, "import": %Import, "export": %Export}


func _ready() -> void:
	_template = _list.get_child(0)
	_list.remove_child(_template)
	%Rescan.pressed.connect(scan)
	%Back.pressed.connect(App.goto.bind(App.MAIN_MENU))
	for action: String in _actions:
		_actions[action].pressed.connect(run.bind(action))
	scan()


func _exit_tree() -> void:
	_template.free()


func _process(delta: float) -> void:
	_background.update_idle(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _busy():
		App.goto(App.MAIN_MENU)
		get_viewport().set_input_as_handled()


func _busy() -> bool:
	return _job != null and _job.running


## Pergunta ao backend quais pendrives estão montados.
func scan() -> void:
	if _busy():
		return
	_set_message("Procurando pendrives…", 0.0)
	_start(["drive", "list"])


func run(action: String) -> void:
	if _busy() or mount == "":
		return
	_set_message("Começando…", 0.0)
	_start(["drive", ACTIONS[action][0], "--mount", mount], action)


func _start(args: Array[String], action := "") -> void:
	_job = App.run_pbq(args)
	if _job == null:
		show_drives([])
		_set_message("Backend não instalado (rode scripts/setup.sh)", 0.0)
		return
	_update_buttons()
	_job.message.connect(on_message.bind(action))
	_job.finished.connect(func(_ok: bool, _last: Dictionary) -> void: _update_buttons())


## Uma mensagem do `pbq drive …` (pbq/protocol.py).
func on_message(data: Dictionary, action: String) -> void:
	match data["type"]:
		"drives":
			show_drives(data["drives"])
		"progress":
			var text := (
				"%s: %d de %d"
				% [PHASES.get(data["phase"], data["phase"]), int(data["done"]), int(data["total"])]
			)
			_set_message(text, float(data["fraction"]))
		"done":
			var text: String = ACTIONS[action][1] % int(data["count"]) if action else ""
			if not data["errors"].is_empty():
				text += " %d arquivos com erro." % data["errors"].size()
			_set_message(text, 1.0)
		"error":
			_set_message("Não deu certo: %s" % data["message"], 0.0)


func show_drives(found: Array) -> void:
	drives = found
	for child in _list.get_children():
		child.free()  # já: a lista nova entra no mesmo quadro
	mount = ""
	for drive: Dictionary in drives:
		var row: Button = _template.duplicate()
		row.text = (
			"%s · %s"
			% [
				drive["name"],
				"pasta palheta/ encontrada" if drive["has_folder"] else "sem a pasta palheta/"
			]
		)
		row.pressed.connect(_choose.bind(drive["path"]))
		_list.add_child(row)
	_no_drive.visible = drives.is_empty()
	if not drives.is_empty():
		_list.get_child(0).button_pressed = true
		_choose(drives[0]["path"])
		_list.get_child(0).grab_focus()
	else:
		%Rescan.grab_focus()
	_set_message("", 0.0)
	_update_buttons()


func _choose(path: String) -> void:
	mount = path
	_update_buttons()


func _update_buttons() -> void:
	for action: String in _actions:
		_actions[action].disabled = mount == "" or _busy()
	%Rescan.disabled = _busy()
	%Back.disabled = _busy()


func _set_message(text: String, fraction: float) -> void:
	_message.text = text
	_progress.value = fraction
