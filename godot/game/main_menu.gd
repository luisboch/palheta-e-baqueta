## Menu principal: Jogar, Pendrive e Sair, com o andamento do processamento embaixo.
##
## Abrir o menu inicia o worker (ADR 0003: o pendrive só é lido quando o jogador pede, mas o
## que já está em data/input é processado sozinho).
extends Control

const QUEUE_REFRESH := 0.5  ## s entre leituras do queue.json

var _since_refresh := QUEUE_REFRESH

@onready var _background: Background = $Background
@onready var _play: Button = %Play
@onready var _drive: Button = %Drive
@onready var _quit: Button = %Quit
@onready var _status: Label = %Status


func _ready() -> void:
	App.start_worker()
	_play.pressed.connect(App.goto.bind(App.SONG_SELECT))
	_drive.pressed.connect(App.goto.bind(App.DRIVE))
	_quit.pressed.connect(get_tree().quit)
	_play.grab_focus()
	_status.text = ""


func _process(delta: float) -> void:
	_background.update_idle(delta)
	_since_refresh += delta
	if _since_refresh >= QUEUE_REFRESH:
		_since_refresh = 0.0
		_status.text = QueueStatus.text(QueueStatus.read(App.data_dir.path_join("queue.json")))
