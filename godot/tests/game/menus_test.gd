extends GdUnitTestSuite

const SAMPLE := "res://tests/fixtures/pipeline_sample.chart"
const SongSelectScene := preload("res://game/song_select.tscn")
const DriveScene := preload("res://game/drive.tscn")
const MainMenuScene := preload("res://game/main_menu.tscn")

var _saved_library: String
var _saved_data: String


func before_test() -> void:
	_saved_library = App.library_dir
	_saved_data = App.data_dir
	App.data_dir = create_temp_dir("dados_%d" % Time.get_ticks_usec())  # um por teste
	App.library_dir = App.data_dir.path_join("library")
	App.selection = {}


func after_test() -> void:
	App.library_dir = _saved_library
	App.data_dir = _saved_data
	App.selection = {}


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


## Biblioteca com duas músicas: "b" só Cordas, "a" com Cordas e bateria.
func _library() -> void:
	var index := {"version": 1, "songs": []}
	var entries := [
		["a", "Alfa", {"strings": true, "drums": true}], ["b", "Beta", {"strings": true}]
	]
	for entry: Array in entries:
		var song := {
			"version": 1,
			"id": entry[0],
			"title": entry[1],
			"artist": "Banda",
			"bpm": 120.0,
			"duration": 65,
			"instruments": entry[2],
			"files": {"chart": "notes.chart"}
		}
		_write(App.library_dir.path_join(entry[0]).path_join("song.json"), JSON.stringify(song))
		_write(
			App.library_dir.path_join(entry[0]).path_join("notes.chart"),
			FileAccess.get_file_as_string(SAMPLE)
		)
		index["songs"].append(song)
	_write(App.library_dir.path_join("index.json"), JSON.stringify(index))


func _scene(packed: PackedScene) -> Node:
	var scene := packed.instantiate()
	add_child(scene)
	auto_free(scene)
	return scene


func test_song_select_blocks_absent_instruments() -> void:
	_library()
	var scene := _scene(SongSelectScene)
	assert_int(scene.songs.size()).is_equal(2)
	assert_str(scene.current["id"]).is_equal("a")  # a primeira da lista
	assert_bool(scene.get_node("%Bass").disabled).is_true()  # o chart tem baixo; a música não
	assert_bool(scene.get_node("%Drums").disabled).is_false()
	assert_str(scene.get_node("%Absent").text).is_equal("Baixo não toca nesta música")
	assert_str(scene.instrument).is_equal("strings")
	assert_str(scene.difficulty).is_equal("Hard")
	scene.get_node("%Drums").pressed.emit()
	scene.get_node("%Easy").pressed.emit()
	assert_array([scene.instrument, scene.difficulty]).is_equal(["drums", "Easy"])
	scene.select(scene.songs[1])  # "b": sem bateria, a escolha cai para Cordas
	assert_str(scene.instrument).is_equal("strings")
	assert_bool(scene.get_node("%Drums").disabled).is_true()
	scene.play()
	assert_str(App.last_scene).is_equal(App.PLAY)
	assert_dict(App.selection).contains_key_value("id", "b")
	assert_dict(App.selection).contains_key_value("difficulty", "Easy")


func test_song_select_keeps_choice_and_edits_without_backend() -> void:
	_library()
	App.selection = {"id": "b", "instrument": "strings", "difficulty": "Expert"}
	var scene := _scene(SongSelectScene)
	assert_str(scene.current["id"]).is_equal("b")
	assert_str(scene.difficulty).is_equal("Expert")
	scene.open_edit()
	assert_bool(scene.get_node("%EditPanel").visible).is_true()
	assert_str(scene.get_node("%TitleEdit").text).is_equal("Beta")
	scene.save_edit()  # nos testes o backend fica desligado
	assert_str(scene.get_node("%EditError").text).contains("Backend")
	scene.close_edit()
	assert_bool(scene.get_node("%EditPanel").visible).is_false()
	var names: Array[String] = ["Baixo", "Bateria"]
	assert_str(scene.absent_text(names)).is_equal("Baixo e Bateria não tocam nesta música")


func test_song_select_modes_and_second_player() -> void:
	_library()
	var scene := _scene(SongSelectScene)  # foco em "a": Cordas e bateria
	assert_str(scene.mode).is_equal("solo")
	assert_bool(scene.get_node("%Player2").visible).is_false()
	scene.play()
	assert_str(App.selection["mode"]).is_equal("solo")
	assert_bool(App.selection.has("instrument_p2")).is_false()  # solo não leva o P2 à partida

	scene.get_node("%Coop").pressed.emit()
	assert_bool(scene.get_node("%Player2").visible).is_true()
	assert_str(scene.get_node("%InstrumentLabel").text).is_equal("Jogador 1")
	assert_str(scene.instrument_2).is_equal("drums")  # sugere o outro instrumento
	assert_bool(scene.get_node("%Bass2").disabled).is_true()
	scene.get_node("%Strings2").pressed.emit()
	scene.get_node("%Easy2").pressed.emit()
	scene.get_node("%Expert").pressed.emit()
	assert_array([scene.instrument, scene.difficulty]).is_equal(["strings", "Expert"])
	assert_array([scene.instrument_2, scene.difficulty_2]).is_equal(["strings", "Easy"])

	scene.get_node("%Versus").pressed.emit()
	scene.get_node("%Drums2").pressed.emit()
	scene.play()
	assert_dict(App.selection).contains_key_value("mode", "versus")
	assert_dict(App.selection).contains_key_value("instrument_p2", "drums")
	assert_dict(App.selection).contains_key_value("difficulty", "Expert")
	assert_str(App.last_scene).is_equal(App.PLAY)

	# Voltando à escolha, o modo e o P2 continuam lá.
	var again := _scene(SongSelectScene)
	assert_str(again.mode).is_equal("versus")
	assert_bool(again.get_node("%Versus").button_pressed).is_true()
	assert_str(again.instrument_2).is_equal("drums")


func test_song_select_empty_library() -> void:
	var scene := _scene(SongSelectScene)
	assert_bool(scene.get_node("%Empty").visible).is_true()
	assert_bool(scene.get_node("%Details").visible).is_false()
	scene.play()
	assert_dict(App.selection).is_empty()


func test_drive_screen_follows_messages() -> void:
	var scene := _scene(DriveScene)
	assert_str(scene.get_node("%Message").text).contains("Backend")  # desligado nos testes
	assert_bool(scene.get_node("%NoDrive").visible).is_true()
	scene.show_drives([{"path": "/run/media/deck/PEN", "name": "PEN", "has_folder": true}])
	assert_str(scene.mount).is_equal("/run/media/deck/PEN")
	assert_bool(scene.get_node("%Import").disabled).is_false()
	var progress := {"type": "progress", "phase": "copying", "done": 2, "total": 5, "fraction": 0.4}
	scene.on_message(progress, "process")
	assert_str(scene.get_node("%Message").text).is_equal("Copiando: 2 de 5")
	assert_float(scene.get_node("%Progress").value).is_equal_approx(0.4, 0.001)
	scene.on_message({"type": "done", "count": 3, "errors": ["x.mp3"]}, "process")
	assert_str(scene.get_node("%Message").text).starts_with("3 MP3s novos na fila")
	assert_str(scene.get_node("%Message").text).ends_with("1 arquivos com erro.")
	scene.on_message({"type": "error", "message": "pendrive removido"}, "import")
	assert_str(scene.get_node("%Message").text).contains("pendrive removido")
	scene.run("import")  # sem backend: só avisa
	scene.on_message({"type": "drives", "drives": []}, "")
	assert_str(scene.mount).is_equal("")


func test_main_menu_shows_the_queue() -> void:
	_write(
		App.data_dir.path_join("queue.json"),
		(
			'{"pending": [{"id": "x"}], "current": {"id": "x", "label": "Banda - Música",'
			+ ' "stage": "beats", "fraction": 0.5}}'
		)
	)
	var scene := _scene(MainMenuScene)
	scene._process(1.0)
	assert_str(scene.get_node("%Status").text).is_equal(
		"Preparando Banda - Música: achando as batidas 50%"
	)
