## O andamento do processamento (data/queue.json, escrito pelo worker) em texto para a tela.
class_name QueueStatus
extends RefCounted


## "" quando não há nada na fila. `queue`: {pending: [{id, label}], current: {...} | null}; a
## música atual também está em `pending`.
static func text(queue: Dictionary) -> String:
	var current: Variant = queue.get("current")
	var waiting: int = queue.get("pending", []).size()
	if not current is Dictionary:
		return "" if waiting == 0 else "%d na fila" % waiting
	var line := "Preparando %s" % current.get("label", "?")
	var stage: Variant = current.get("stage")
	if stage != null:
		line += (
			": %s %d%%"
			% [
				BackendProtocol.STAGE_LABELS.get(stage, str(stage)),
				roundi(float(current.get("fraction", 0.0)) * 100),
			]
		)
	var others := waiting - 1
	if others > 0:
		line += " · mais %d na fila" % others
	return line


## Lê o queue.json; {} se não existir ou estiver sendo escrito.
static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		return {}
	return json.data
