## Identidade do jogo e compatibilidade com o backend (`pbq version`).
##
## Classe pura (sem nós): a lógica do jogo fica em godot/core/, testável sem cena nem janela.
class_name AppInfo
extends RefCounted

const NAME := "Palheta & Baqueta"
## Versão maior do backend que este jogo entende; o `pbq version` responde em JSON.
const BACKEND_MAJOR := 0


## Lê a saída de `pbq version` e diz se o backend é compatível.
static func backend_compatible(version_json: String) -> bool:
	# JSON.new().parse e não JSON.parse_string: este registra ERROR no log com texto inválido.
	var json := JSON.new()
	if json.parse(version_json) != OK:
		return false
	var data: Variant = json.data
	if not data is Dictionary or data.get("name") != "pbq":
		return false
	var parts := str(data.get("version", "")).split(".")
	return parts.size() == 3 and parts[0].is_valid_int() and int(parts[0]) == BACKEND_MAJOR
