## Um comando `pbq` rodando sem travar a tela: lê o stdout (JSON-lines) numa thread e entrega
## cada mensagem do contrato como sinal, na thread principal.
##
## O comando roda na raiz do repositório (`env -C`): os caminhos do config.toml são relativos a
## ela, e o OS.execute_with_pipe do Godot não tem diretório de trabalho.
class_name BackendJob
extends RefCounted

signal message(data: Dictionary)
## `ok`: saiu com 0. `last`: a última mensagem (done, error...), ou {} se não houve nenhuma.
signal finished(ok: bool, last: Dictionary)

var running := false
var _thread: Thread
var _last := {}


## Roda `program args...` (o App monta o comando do pbq). Falso se não conseguiu iniciar.
func start(program: String, args: PackedStringArray) -> bool:
	var pipe := OS.execute_with_pipe(program, args)
	if pipe.is_empty():
		return false
	running = true
	_thread = Thread.new()
	_thread.start(_read.bind(pipe))
	return true


func _read(pipe: Dictionary) -> void:
	var stdio: FileAccess = pipe["stdio"]
	while true:
		var line := stdio.get_line()
		if line == "" and stdio.get_error() != OK:
			break  # fim do pipe: o processo terminou
		var data := BackendMessage.parse(line)
		if not data.is_empty():
			_emit_message.call_deferred(data)
	while OS.is_process_running(pipe["pid"]):
		OS.delay_msec(10)
	_finish.call_deferred(OS.get_process_exit_code(pipe["pid"]) == 0)


func _emit_message(data: Dictionary) -> void:
	_last = data
	message.emit(data)


func _finish(ok: bool) -> void:
	_thread.wait_to_finish()
	running = false
	finished.emit(ok, _last)
