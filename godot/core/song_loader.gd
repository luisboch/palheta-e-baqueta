## Lê uma pasta da biblioteca (data/library/<id>/, contrato em docs/library-format.md).
class_name SongLoader
extends RefCounted


## {ok, error, dir, song (song.json), chart (ChartParser), beatmap}. `ok` falso explica em
## `error`. O beatmap é opcional (o fundo usa o mapa de tempo sem ele): {} se faltar.
static func load_dir(dir: String) -> Dictionary:
	var result := {"ok": false, "error": "", "dir": dir, "song": {}, "chart": {}, "beatmap": {}}
	var song_path := dir.path_join("song.json")
	if not FileAccess.file_exists(song_path):
		result["error"] = "música incompleta (sem song.json): " + dir
		return result
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(song_path)) != OK or not json.data is Dictionary:
		result["error"] = "song.json inválido: " + song_path
		return result
	var song: Dictionary = json.data
	if int(song.get("version", 0)) > BackendProtocol.FORMAT_VERSION:
		result["error"] = "música de uma versão mais nova do Palheta & Baqueta"
		return result
	var chart_name: String = song.get("files", {}).get("chart", "notes.chart")
	var chart_path := dir.path_join(chart_name)
	if not FileAccess.file_exists(chart_path):
		result["error"] = "sem chart: " + chart_path
		return result
	result["song"] = song
	result["chart"] = ChartParser.parse(FileAccess.get_file_as_string(chart_path))
	var beatmap := JSON.new()
	var beatmap_path := file_path(result, "beatmap")
	if (
		beatmap_path != ""
		and beatmap.parse(FileAccess.get_file_as_string(beatmap_path)) == OK
		and beatmap.data is Dictionary
	):
		result["beatmap"] = beatmap.data
	result["ok"] = true
	return result


## Caminho absoluto de um arquivo da música (`files.<papel>` do song.json), ou "" se não houver.
static func file_path(loaded: Dictionary, role: String) -> String:
	var name: Variant = loaded["song"].get("files", {}).get(role)
	if name == null or str(name) == "":
		return ""
	var path: String = loaded["dir"].path_join(str(name))
	return path if FileAccess.file_exists(path) else ""
