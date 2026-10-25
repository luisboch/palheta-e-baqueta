## Menu principal: 1 Jogador, 2 Jogadores, Gerenciar músicas e Sair, com o andamento do
## processamento embaixo. O emblema gira no cenário ao lado (Shell, estação "Main").
##
## Abrir o menu inicia o worker (ADR 0003: o pendrive só é lido quando o jogador pede, mas o
## que já está em data/input é processado sozinho).
extends Control

const QUEUE_REFRESH := 0.5  ## s entre leituras do queue.json

var _since_refresh := QUEUE_REFRESH

@onready var _one: Button = %OnePlayer
@onready var _two: Button = %TwoPlayers
@onready var _manage: Button = %Manage
@onready var _quit: Button = %Quit
@onready var _status: Label = %Status


func _ready() -> void:
	App.start_worker()
	_one.pressed.connect(start.bind(1))
	_two.pressed.connect(start.bind(2))
	_manage.pressed.connect(App.go.bind(MenuFlow.MANAGE))
	_quit.pressed.connect(get_tree().quit)
	(_two if App.flow.players == 2 else _one).grab_focus()  # volta onde estava
	_status.text = ""


func _process(delta: float) -> void:
	_since_refresh += delta
	if _since_refresh >= QUEUE_REFRESH:
		_since_refresh = 0.0
		_status.text = QueueStatus.text(QueueStatus.read(App.data_dir.path_join("queue.json")))


## Começa o caminho até a partida com 1 ou 2 jogadores.
func start(players: int) -> void:
	App.go(App.flow.start(players))
