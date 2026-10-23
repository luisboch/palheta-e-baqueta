## Uma linha JSON do stdout de um comando `pbq` (pbq/protocol.py).
class_name BackendMessage
extends RefCounted


## Dicionário da mensagem, ou vazio se a linha não for uma mensagem do contrato.
static func parse(line: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(line.strip_edges()) != OK:
		return {}
	if not BackendProtocol.is_valid(json.data, BackendProtocol.MESSAGES):
		return {}
	return json.data


## Junta pedaços lidos de um pipe em linhas completas (o resto fica para a próxima leitura).
class LineBuffer:
	extends RefCounted

	var _pending := ""

	func feed(text: String) -> PackedStringArray:
		var parts := (_pending + text).split("\n")
		_pending = parts[parts.size() - 1]
		parts.remove_at(parts.size() - 1)
		return parts
