extends GdUnitTestSuite

const INDEX := """{"version": 1, "songs": [
	{"id": "b", "title": "Pais e Filhos", "artist": "Legião Urbana", "duration": 308.4,
"instruments": {"drums": true, "bass": true, "strings": true}},
	{"id": "a", "title": "More Than Words", "artist": "extreme", "duration": 255.5,
"instruments": {"drums": false, "bass": false, "strings": true}},
	{"id": "c", "title": "Sem Artista", "artist": null, "duration": 5, "instruments": {}},
	{"title": "sem id"}
]}"""


func test_parses_and_sorts_by_artist() -> void:
	var songs := SongCatalog.parse(INDEX)
	assert_array(songs.map(func(s: Dictionary) -> String: return s["id"])).is_equal(["c", "a", "b"])
	assert_str(SongCatalog.label(songs[0])).is_equal("Sem Artista — Artista desconhecido")
	assert_str(SongCatalog.label(songs[1])).is_equal("More Than Words — extreme")
	assert_str(SongCatalog.instruments(songs[2])).is_equal("Bateria · Baixo · Cordas")
	assert_str(SongCatalog.instruments(songs[0])).is_equal("")
	assert_str(SongCatalog.duration(songs[2])).is_equal("5:08")
	assert_array(SongCatalog.parse("{quebrado")).is_empty()


func test_queue_text() -> void:
	assert_str(QueueStatus.text({})).is_equal("")
	assert_str(QueueStatus.text({"pending": [{}, {}], "current": null})).is_equal("2 na fila")
	var queue := {
		"pending": [{"id": "x"}, {"id": "y"}, {"id": "z"}],
		"current": {"id": "x", "label": "Banda - Música", "stage": "separate", "fraction": 0.456},
	}
	assert_str(QueueStatus.text(queue)).is_equal(
		"Preparando Banda - Música: separando os instrumentos 46% · mais 2 na fila"
	)
	queue["current"]["stage"] = null
	queue["pending"] = [{"id": "x"}]
	assert_str(QueueStatus.text(queue)).is_equal("Preparando Banda - Música")


func test_queue_read() -> void:
	var dir := create_temp_dir("fila")
	assert_dict(QueueStatus.read(dir.path_join("queue.json"))).is_empty()
	var file := FileAccess.open(dir.path_join("queue.json"), FileAccess.WRITE)
	file.store_string('{"pending": [], "current": null}')
	file.close()
	assert_dict(QueueStatus.read(dir.path_join("queue.json"))).contains_keys(["pending"])
