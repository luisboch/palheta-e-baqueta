## Autoload "App": o que as telas compartilham. Caminhos de data/, o backend (worker e comandos
## pbq), a música escolhida e a troca de tela.
extends Node

## A casca dos menus (ADR 0022): o cenário 3D em que as telas abrem. A partida é outra cena.
const SHELL := "res://game/shell.tscn"
const MAIN_MENU := "res://game/main_menu.tscn"
const MODE_SELECT := "res://game/mode_select.tscn"
const SONG_SELECT := "res://game/song_select.tscn"
const INSTRUMENT_SELECT := "res://game/instrument_select.tscn"
const MANAGE := "res://game/manage.tscn"
const PLAY := "res://game/play.tscn"
## O repositório fica um nível acima do projeto Godot (godot/): data/ e .venv/ estão lá.
const REPO_FROM_PROJECT := ".."
## Instalado pelo .deb (ADR 0018), o jogo exportado não tem repositório: o lançador põe o backend,
## data/ e .venv/ numa pasta do usuário e a passa nesta variável.
const HOME_ENV := "PALHETA_HOME"
const PBQ := ".venv/bin/pbq"  ## instalado por scripts/setup.sh
const ENV := "/usr/bin/env"  ## `env -C <repo>`: roda o pbq na raiz do repositório
const WORKER_LOCK := ".worker.lock"
## Quadro mais longo que isso (s) vai para o game.log: o jogo "engasga" e queremos saber onde.
const HITCH_LOG := 0.25
const STATS_EVERY := 60.0  ## s entre os registros de memória no game.log
## Nome de tela do MenuFlow → cena.
const SCENES := {
	MenuFlow.MAIN: MAIN_MENU,
	MenuFlow.MODE: MODE_SELECT,
	MenuFlow.SONGS: SONG_SELECT,
	MenuFlow.INSTRUMENTS: INSTRUMENT_SELECT,
	MenuFlow.MANAGE: MANAGE,
	MenuFlow.PLAY: PLAY,
}

## Falso nos testes (GdUnit4, pela linha de comando ou pelo editor): nada de worker nem comandos
## contra a data/ real (AGENTS.md), nem troca de cena (trocaria a cena do executor de testes).
var live := not _under_tests()
## A última tela pedida a goto() (os testes conferem a navegação por aqui).
var last_scene := ""
## A partida escolhida no menu: {dir, instrument, difficulty}. Vazio: play.tscn rodando sozinha
## (F6 no editor ou linha de comando).
var selection := {}
## O caminho dos menus: 1 ou 2 jogadores, o modo e o que vem depois de cada tela.
var flow := MenuFlow.new()
## A casca aberta (null na partida, nos testes e com uma tela rodando sozinha no editor).
var shell: Shell
## Tela que a casca abre ao carregar (voltando da partida); "" é o menu principal.
var pending_screen := ""
var repo := home_dir()
var data_dir := repo.path_join("data")
var library_dir := data_dir.path_join("library")
var _worker_pid := -1
var _since_stats := 0.0
var _triggers_down := {}  ## "device:eixo" → gatilho além da zona morta (só para o log)


## Onde ficam data/ e o backend: $PALHETA_HOME, senão a raiz do repositório.
static func home_dir() -> String:
	var home := OS.get_environment(HOME_ENV)
	if home != "":
		return home
	return ProjectSettings.globalize_path("res://").path_join(REPO_FROM_PROJECT).simplify_path()


static func _under_tests() -> bool:
	for arg in OS.get_cmdline_args():
		if "gdUnit4" in arg or "GdUnit" in arg:
			return true
	return false


## Os menus já precisam do controle (A confirma, B volta), antes de qualquer partida.
func _ready() -> void:
	InputProfile.apply()


## Diagnóstico de lentidão que aparece só depois de um tempo de jogo: registra no game.log os
## quadros longos e, a cada minuto, a memória (vídeo inclusive), os nós e o FPS.
func _process(delta: float) -> void:
	if not live:
		return
	var scene := get_tree().current_scene
	if delta > HITCH_LOG:
		print("travada: %.0f ms em %s" % [delta * 1000.0, scene.name if scene else "?"])
	_since_stats += delta
	if _since_stats < STATS_EVERY:
		return
	_since_stats = 0.0
	print(
		(
			"stats: %d fps, nós %d, órfãos %d, mem %.0f MB, vídeo %.0f MB, tela %s"
			% [
				Performance.get_monitor(Performance.TIME_FPS),
				Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
				Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
				Performance.get_monitor(Performance.MEMORY_STATIC) / 1e6,
				Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1e6,
				scene.name if scene else "?",
			]
		)
	)


## Registra no game.log o que o controle manda (botões e gatilhos, com o número do controle):
## um botão que "gruda" mostra se o jogo recebeu o soltar ou se o controle não o mandou.
func _input(event: InputEvent) -> void:
	if not live:
		return
	if event is InputEventJoypadButton:
		var button := event as InputEventJoypadButton
		print(
			(
				"controle %d: botão %d %s"
				% [button.device, button.button_index, "desceu" if button.pressed else "subiu"]
			)
		)
	elif event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if motion.axis != JOY_AXIS_TRIGGER_LEFT and motion.axis != JOY_AXIS_TRIGGER_RIGHT:
			return
		var key := "%d:%d" % [motion.device, motion.axis]
		var down := motion.axis_value > InputProfile.TRIGGER_DEADZONE
		if down != _triggers_down.has(key):
			print(
				(
					"controle %d: gatilho %d %s"
					% [motion.device, motion.axis, "desceu" if down else "subiu"]
				)
			)
			if down:
				_triggers_down[key] = true
			else:
				_triggers_down.erase(key)


## Vai para a tela (ou a partida). Entre telas, a casca só troca a tela e voa com a câmera; fora
## dela (vindo da partida), carrega a casca já na tela pedida.
func goto(scene: String) -> void:
	last_scene = scene
	if not live:
		return
	if shell != null:
		if scene == PLAY:
			shell.leave_to(scene)
		else:
			shell.show_screen(scene)
		return
	if scene != PLAY:
		pending_screen = scene
		scene = SHELL
	get_tree().change_scene_to_file.call_deferred(scene)


## Vai para a tela de nome `screen_name` (MenuFlow.MAIN, MenuFlow.SONGS…).
func go(screen_name: String) -> void:
	goto(SCENES.get(screen_name, MAIN_MENU))


## Inicia o worker uma vez por execução do jogo. Ele morre junto com o jogo
## (--die-with-parent) e, se outro já estiver rodando, sai sozinho (lock).
func start_worker() -> void:
	if not live or _worker_pid > 0 or not has_backend():
		return
	_worker_pid = OS.create_process(ENV, _pbq_args(["watch", "--die-with-parent"]))


## Pausa (true) ou retoma o worker: durante a partida a separação de stems disputaria a CPU
## com o áudio e o desenho. Vale também para um worker que não fomos nós que iniciamos.
func pause_worker(paused: bool) -> void:
	var pid := worker_pid()
	if not live or pid <= 0:
		return
	OS.execute("kill", ["-STOP" if paused else "-CONT", str(pid)])


## PID do worker rodando, ou -1. O lock guarda o PID mesmo depois que o worker sai: só vale se
## o processo ainda é um pbq (senão o SIGSTOP pararia outro programa que herdou o número).
func worker_pid() -> int:
	var path := data_dir.path_join(WORKER_LOCK)
	if not FileAccess.file_exists(path):
		return -1
	var text := FileAccess.get_file_as_string(path).strip_edges()
	if not text.is_valid_int():
		return -1
	var cmdline := FileAccess.get_file_as_string("/proc/%s/cmdline" % text)
	return int(text) if "pbq" in cmdline and "watch" in cmdline else -1


func has_backend() -> bool:
	return FileAccess.file_exists(repo.path_join(PBQ))


## Roda `pbq <args>` (comandos do menu: drive, edit). null se o backend não está instalado
## ou desligado (testes).
func run_pbq(args: Array[String]) -> BackendJob:
	if not live or not has_backend():
		return null
	var job := BackendJob.new()
	if not job.start(ENV, _pbq_args(args)):
		return null
	return job


func _pbq_args(args: Array[String]) -> PackedStringArray:
	return PackedStringArray(["-C", repo, repo.path_join(PBQ)] + args)
