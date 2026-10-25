extends GdUnitTestSuite

const SAMPLE := "res://tests/fixtures/pipeline_sample.chart"
const SongSelectScene := preload("res://game/song_select.tscn")
const ModeSelectScene := preload("res://game/mode_select.tscn")
const InstrumentSelectScene := preload("res://game/instrument_select.tscn")
const DriveScene := preload("res://game/drive.tscn")
const MainMenuScene := preload("res://game/main_menu.tscn")
const ShellScene := preload("res://game/shell.tscn")

var _saved_library: String
var _saved_data: String


func before_test() -> void:
	_saved_library = App.library_dir
	_saved_data = App.data_dir
	App.data_dir = create_temp_dir("dados_%d" % Time.get_ticks_usec())  # um por teste
	App.library_dir = App.data_dir.path_join("library")
	App.selection = {}
	App.flow = MenuFlow.new()
	App.last_scene = ""


func after_test() -> void:
	App.library_dir = _saved_library
	App.data_dir = _saved_data
	App.selection = {}
	App.flow = MenuFlow.new()


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


## Biblioteca com duas músicas: "b" só Cordas, "a" com Cordas e bateria (e capa vermelha).
func _library() -> void:
	var index := {"version": 1, "songs": []}
	var entries := [
		["a", "Alfa", {"strings": true, "drums": true}], ["b", "Beta", {"strings": true}]
	]
	for entry: Array in entries:
		var dir := App.library_dir.path_join(entry[0])
		var song := {
			"version": 1,
			"id": entry[0],
			"title": entry[1],
			"artist": "Banda",
			"bpm": 120.0,
			"duration": 65,
			"instruments": entry[2],
			"files": {"chart": "notes.chart", "cover": "cover.png"}
		}
		_write(dir.path_join("song.json"), JSON.stringify(song))
		_write(dir.path_join("notes.chart"), FileAccess.get_file_as_string(SAMPLE))
		if entry[0] == "a":
			var cover := Image.create(8, 8, false, Image.FORMAT_RGB8)
			cover.fill(Color(0.8, 0.1, 0.1))
			cover.save_png(dir.path_join("cover.png"))
		index["songs"].append(song)
	_write(App.library_dir.path_join("index.json"), JSON.stringify(index))


func _scene(packed: PackedScene) -> Node:
	var scene := packed.instantiate()
	add_child(scene)
	auto_free(scene)
	return scene


func _press(scene: Node, action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	scene._unhandled_input(event)


func test_main_menu_starts_with_one_or_two_players() -> void:
	var scene := _scene(MainMenuScene)
	scene.start(1)
	assert_str(App.last_scene).is_equal(App.SONG_SELECT)
	assert_str(App.flow.mode).is_equal("solo")
	scene.start(2)
	assert_str(App.last_scene).is_equal(App.MODE_SELECT)
	scene.get_node("%Manage").pressed.emit()
	assert_str(App.last_scene).is_equal(App.DRIVE)


func test_mode_select_chooses_and_goes_back() -> void:
	App.flow.start(2)
	var scene := _scene(ModeSelectScene)
	assert_object(scene.get_viewport().gui_get_focus_owner()).is_equal(scene.get_node("%Coop"))
	scene.get_node("%Versus").pressed.emit()
	assert_str(App.flow.mode).is_equal("versus")
	assert_str(App.last_scene).is_equal(App.SONG_SELECT)
	_press(scene, "ui_cancel")
	assert_str(App.last_scene).is_equal(App.MAIN_MENU)


func test_song_select_shows_the_song_and_moves_on() -> void:
	_library()
	App.flow.start(1)
	var scene := _scene(SongSelectScene)
	assert_int(scene.songs.size()).is_equal(2)
	assert_str(scene.current["id"]).is_equal("a")  # a primeira da lista
	assert_str(scene.get_node("%Absent").text).is_equal("Baixo não toca nesta música")
	assert_str(scene.get_node("%Info").text).is_equal("1:05 · 120 BPM")
	scene.select(scene.songs[1])
	scene.choose()
	assert_str(App.last_scene).is_equal(App.INSTRUMENT_SELECT)
	assert_dict(App.selection).contains_key_value("id", "b")
	_press(scene, "ui_cancel")
	assert_str(App.last_scene).is_equal(App.MAIN_MENU)
	var names: Array[String] = ["Baixo", "Bateria"]
	assert_str(scene.absent_text(names)).is_equal("Baixo e Bateria não tocam nesta música")
	names.append("Cordas")
	assert_str(scene.absent_text(names)).is_equal("Nenhum instrumento toca nesta música")


func test_song_select_keeps_the_song_and_handles_an_empty_library() -> void:
	_library()
	App.selection = {"id": "b"}
	var scene := _scene(SongSelectScene)
	assert_str(scene.current["id"]).is_equal("b")
	DirAccess.remove_absolute(App.library_dir.path_join("index.json"))
	scene.reload("")
	assert_bool(scene.get_node("%Empty").visible).is_true()
	assert_bool(scene.get_node("%Card").visible).is_false()
	scene.available = {}
	scene.choose()  # nada jogável: fica
	assert_str(App.last_scene).is_not_equal(App.INSTRUMENT_SELECT)


func test_instrument_select_one_player() -> void:
	_library()
	App.flow.start(1)
	App.selection = {"id": "a", "dir": App.library_dir.path_join("a")}
	var scene := _scene(InstrumentSelectScene)
	assert_int(scene.picks.size()).is_equal(1)
	assert_str(scene.picks[0].instrument).is_equal("strings")
	var bass: Button = scene.get_node("%Player/Box/Instruments/Bass")
	assert_bool(bass.disabled).is_true()  # o chart tem baixo; a música não
	_press(scene, "p2_menu_right")  # sozinho, qualquer lado vale
	assert_str(scene.picks[0].instrument).is_equal("drums")
	_press(scene, "p1_menu_down")
	assert_int(scene.picks[0].row).is_equal(PlayerPick.ROW_DIFFICULTY)
	_press(scene, "p1_menu_up")
	scene.get_node("%Player/Box/Instruments/Strings").pressed.emit()  # clique
	scene.get_node("%Player/Box/Difficulties/Easy").pressed.emit()
	assert_array([scene.picks[0].instrument, scene.picks[0].difficulty]).is_equal(
		["strings", "Easy"]
	)
	_press(scene, "p1_menu_accept")
	assert_bool(scene.starting).is_true()
	assert_str(App.last_scene).is_equal(App.PLAY)
	assert_dict(App.selection).contains_key_value("instrument", "strings")
	assert_dict(App.selection).contains_key_value("difficulty", "Easy")
	assert_dict(App.selection).contains_key_value("mode", "solo")
	assert_bool(App.selection.has("instrument_p2")).is_false()


func test_instrument_select_two_players_ready_each() -> void:
	_library()
	App.flow.start(2)
	App.flow.choose_mode("versus")
	App.selection = {"id": "a", "dir": App.library_dir.path_join("a")}
	var scene := _scene(InstrumentSelectScene)
	assert_int(scene.picks.size()).is_equal(2)
	assert_str(scene.picks[1].instrument).is_equal("drums")  # sugere o outro instrumento
	assert_int(scene.get_node("%Players").get_child_count()).is_equal(2)
	_press(scene, "p1_menu_accept")
	assert_bool(scene.picks[0].is_ready).is_true()
	assert_bool(scene.starting).is_false()  # falta o jogador 2
	_press(scene, "p1_menu_back")  # pronto: desfaz, não sai
	assert_bool(scene.picks[0].is_ready).is_false()
	assert_str(App.last_scene).is_equal("")
	_press(scene, "p2_menu_left")
	assert_str(scene.picks[1].instrument).is_equal("strings")
	_press(scene, "p1_menu_accept")
	_press(scene, "p2_menu_accept")
	assert_bool(scene.starting).is_true()
	assert_dict(App.selection).contains_key_value("mode", "versus")
	assert_dict(App.selection).contains_key_value("instrument_p2", "strings")
	_press(scene, "p2_menu_back")  # começando: ignora


func test_instrument_select_back_without_ready() -> void:
	_library()
	App.flow.start(1)
	App.selection = {"id": "b", "dir": App.library_dir.path_join("b")}
	var scene := _scene(InstrumentSelectScene)
	_press(scene, "p1_menu_back")
	assert_str(App.last_scene).is_equal(App.SONG_SELECT)


func test_shell_flies_between_stations() -> void:
	_library()
	App.flow.start(2)
	App.selection = {"id": "a", "dir": App.library_dir.path_join("a")}
	var shell: Shell = _scene(ShellScene)
	assert_object(App.shell).is_same(shell)
	assert_str(shell.station.name).is_equal("Main")
	shell.show_screen(App.MODE_SELECT)
	assert_object(shell.station).is_instanceof(ModeStation)
	assert_object(shell.screen.get("world")).is_same(shell)
	shell.show_screen(App.SONG_SELECT)
	assert_object(shell.station).is_instanceof(StageStation)
	shell.show_screen(App.INSTRUMENT_SELECT)
	assert_object(shell.station).is_instanceof(InstrumentStation)
	assert_int(shell.screen.get("picks").size()).is_equal(2)
	_press(shell.screen, "p1_menu_right")  # o cursor pisca com as linhas de ação
	shell.burst("Pronto!")
	await await_millis(1200)  # voo, telas velhas saindo, onomatopeia sumindo
	assert_vector(shell.camera.global_position).is_equal_approx(
		shell.station.view().origin, Vector3.ONE * 0.01
	)
	assert_int(shell.get_node("%Screens").get_child_count()).is_equal(1)
	shell.queue_free()
	await await_idle_frame()
	assert_object(App.shell).is_null()


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
