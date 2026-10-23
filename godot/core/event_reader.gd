## Acompanha data/events.jsonl a partir do fim, como um `tail -f` sem bloquear.
##
## Igual ao EventReader do kraoke: começa do fim (só notifica o que acontece com o jogo aberto),
## guarda a linha incompleta para a próxima leitura e recomeça se o arquivo for esvaziado
## (o worker faz rotate ao iniciar). Linhas fora do contrato (BackendProtocol) são ignoradas.
class_name EventReader
extends RefCounted

var path: String
var _pos := 0
var _partial := PackedByteArray()


func _init(events_path: String) -> void:
	path = events_path
	_pos = _length()


## Eventos novos desde a última chamada.
func poll() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var size := _length()
	if size < _pos:  # esvaziado ou recriado
		_pos = 0
		_partial = PackedByteArray()
	if size == _pos:
		return events
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return events
	file.seek(_pos)
	var chunk := file.get_buffer(size - _pos)
	_pos += chunk.size()
	var data := _partial + chunk
	var start := 0
	for i in data.size():
		if data[i] == 10:  # "\n"
			var event := _parse(data.slice(start, i).get_string_from_utf8())
			if not event.is_empty():
				events.append(event)
			start = i + 1
	_partial = data.slice(start)
	return events


func _length() -> int:
	if not FileAccess.file_exists(path):
		return 0
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_length() if file else 0


static func _parse(line: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(line) != OK or not BackendProtocol.is_valid(json.data, BackendProtocol.EVENTS):
		return {}
	return json.data
