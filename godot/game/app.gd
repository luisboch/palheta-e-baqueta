## Autoload "App": o que as telas compartilham. Caminhos de data/, o backend (worker e comandos
## pbq), a música escolhida e a troca de tela.
extends Node

const MAIN_MENU := "res://game/main_menu.tscn"
const SONG_SELECT := "res://game/song_select.tscn"
const DRIVE := "res://game/drive.tscn"
const PLAY := "res://game/play.tscn"
## O repositório fica um nível acima do projeto Godot (godot/): data/ e .venv/ estão lá.
const REPO_FROM_PROJECT := ".."
## Instalado pelo .deb (ADR 0018), o jogo exportado não tem repositório: o lançador põe o backend,
## data/ e .venv/ numa pasta do usuário e a passa nesta variável.
const HOME_ENV := "PALHETA_HOME"
const PBQ := ".venv/bin/pbq"  ## instalado por scripts/setup.sh
const ENV := "/usr/bin/env"  ## `env -C <repo>`: roda o pbq na raiz do repositório
const WORKER_LOCK := ".worker.lock"

## Falso nos testes (GdUnit4, pela linha de comando ou pelo editor): nada de worker nem comandos
## contra a data/ real (AGENTS.md), nem troca de cena (trocaria a cena do executor de testes).
var live := not _under_tests()
## A última tela pedida a goto() (os testes conferem a navegação por aqui).
var last_scene := ""
## A partida escolhida no menu: {dir, instrument, difficulty}. Vazio: play.tscn rodando sozinha
## (F6 no editor ou linha de comando).
var selection := {}
var repo := home_dir()
var data_dir := repo.path_join("data")
var library_dir := data_dir.path_join("library")
var _worker_pid := -1


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


func goto(scene: String) -> void:
	last_scene = scene
	if live:
		get_tree().change_scene_to_file.call_deferred(scene)


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
