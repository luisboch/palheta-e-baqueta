## A casca dos menus (ADR 0022): um cenário 3D só, com a câmera voando entre as estações, e as
## telas (cenas de Control, ADR 0016) abertas por cima. Trocar de tela não troca de cena: o
## cenário e o céu continuam onde estavam. A partida continua uma cena à parte.
##
## Uma tela que declara `var world` recebe esta casca, para mexer no cenário (a capa no telão,
## o instrumento em destaque). Fora da casca (testes, F6 no editor), `world` fica null.
##
## Para abrir direto numa tela (conferir uma estação, gravar quadros):
##   godot --path godot res://game/shell.tscn -- --screen res://game/song_select.tscn \
##         [--players 2] [--song <id>]
## Com PALHETA_HOME apontando para outra pasta, a biblioteca vem de lá (App.home_dir).
class_name Shell
extends Node3D

const FLY_TIME := 0.8  ## s de voo da câmera entre estações
const FLY_ARC := 2.5  ## m que a câmera sobe no meio do voo: um arco, não uma linha reta
const SCREEN_OUT := 0.18  ## s da tela velha saindo
const SCREEN_IN := 0.3  ## s da tela nova entrando
const SCREEN_IN_DELAY := 0.25  ## a tela nova espera a câmera sair do lugar
const SCREEN_SLIDE := 90.0  ## px que a tela velha anda para a esquerda ao sair
const SCREEN_START_SCALE := 0.92  ## a tela nova "estoura" deste tamanho para o normal
const LEAVE_TIME := 0.5  ## s do mergulho da câmera antes da partida
const LEAVE_DISTANCE := 6.0  ## m que a câmera avança no mergulho
const LEAVE_FOV := 25.0  ## graus a mais no mergulho: sensação de velocidade

## Tela → estação do cenário onde ela abre.
const STATIONS := {
	App.MAIN_MENU: "Main",
	App.MODE_SELECT: "Mode",
	App.SONG_SELECT: "Songs",
	App.INSTRUMENT_SELECT: "Instruments",
	App.MANAGE: "Manage",
}

var screen: Control  ## a tela aberta
var station: Station  ## onde a câmera está (ou para onde está indo)
var _fly: Tween

@onready var camera: Camera3D = $Camera3D
@onready var sky: ComicSky = $Sky
@onready var fx: FocusFx = $Fx/FocusFx
@onready var _stations: Node3D = $World/Stations
@onready var _holder: Control = %Screens
@onready var _fade: ColorRect = %Fade


func _ready() -> void:
	Comic.toonify($World)
	App.shell = self
	var first := App.pending_screen if App.pending_screen != "" else _arg("--screen", App.MAIN_MENU)
	if App.pending_screen == "" and _arg("--players", "") != "":
		App.flow.start(int(_arg("--players", "1")))
	if App.pending_screen == "" and _arg("--song", "") != "":
		App.selection["id"] = _arg("--song", "")
		App.selection["dir"] = App.library_dir.path_join(App.selection["id"])
	App.pending_screen = ""
	show_screen(first, true)


func _exit_tree() -> void:
	if App.shell == self:
		App.shell = null


static func _arg(name: String, default: String) -> String:
	var args := OS.get_cmdline_user_args()
	var at := args.find(name)
	return args[at + 1] if at >= 0 and at + 1 < args.size() else default


## Onomatopeia de quadrinho no meio da tela (ou em `at`).
func burst(text: String, at := Vector2(-1, -1), color := Comic.YELLOW) -> void:
	var where := at if at.x >= 0 else get_viewport().get_visible_rect().size / 2
	Burst.spawn($Fx, text, where, color)


## Abre a tela (caminho da cena) e leva a câmera até a estação dela.
func show_screen(path: String, instant := false) -> void:
	_close_current()
	_fly_to(_stations.get_node(STATIONS.get(path, "Main")), instant)
	screen = (load(path) as PackedScene).instantiate()
	if "world" in screen:
		screen.set("world", self)
	_holder.add_child(screen)
	if instant:
		return
	screen.pivot_offset = _holder.size / 2
	screen.modulate.a = 0.0
	screen.scale = Vector2.ONE * SCREEN_START_SCALE
	var tween := create_tween().set_parallel()
	tween.tween_property(screen, "modulate:a", 1.0, SCREEN_IN).set_delay(SCREEN_IN_DELAY)
	(
		tween
		. tween_property(screen, "scale", Vector2.ONE, SCREEN_IN)
		. set_delay(SCREEN_IN_DELAY)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)


## Mergulho da câmera e escurecer; depois troca para a cena (a partida).
func leave_to(scene: String) -> void:
	_close_current()
	if _fly:
		_fly.kill()
	var forward := -camera.global_basis.z
	var tween := create_tween().set_parallel()
	(
		tween
		. tween_property(
			camera, "global_position", camera.global_position + forward * LEAVE_DISTANCE, LEAVE_TIME
		)
		. set_trans(Tween.TRANS_EXPO)
		. set_ease(Tween.EASE_IN)
	)
	tween.tween_property(camera, "fov", camera.fov + LEAVE_FOV, LEAVE_TIME).set_ease(Tween.EASE_IN)
	tween.tween_property(_fade, "modulate:a", 1.0, LEAVE_TIME)
	tween.chain().tween_callback(get_tree().change_scene_to_file.bind(scene))


## A tela velha sai deslizando e some; desligada já, para não pegar mais nenhum botão.
func _close_current() -> void:
	if screen == null:
		return
	var old := screen
	screen = null
	old.process_mode = Node.PROCESS_MODE_DISABLED
	var tween := create_tween().set_parallel()
	tween.tween_property(old, "modulate:a", 0.0, SCREEN_OUT)
	tween.tween_property(old, "position:x", old.position.x - SCREEN_SLIDE, SCREEN_OUT)
	tween.chain().tween_callback(old.queue_free)


func _fly_to(target: Station, instant: bool) -> void:
	station = target
	sky.set_palette(target.sky_a, target.sky_b, target.sky_dots, instant)
	if _fly:
		_fly.kill()
	var to := target.view()
	if instant:
		camera.global_transform = to
		return
	_fly = create_tween()
	(
		_fly
		. tween_method(_fly_step.bind(camera.global_transform, to), 0.0, 1.0, FLY_TIME)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_IN_OUT)
	)


func _fly_step(t: float, from: Transform3D, to: Transform3D) -> void:
	var view := from.interpolate_with(to, t)
	view.origin += Vector3.UP * sin(PI * t) * FLY_ARC
	camera.global_transform = view
