extends GdUnitTestSuite

const SAMPLE := "res://tests/fixtures/pipeline_sample.chart"
const PlayScene := preload("res://game/play.tscn")


func _song_dir(instruments: String) -> String:
	var dir := create_temp_dir("play_song")
	var song := FileAccess.open(dir.path_join("song.json"), FileAccess.WRITE)
	song.store_string(
		(
			(
				'{"version": 1, "title": "Exemplo", "artist": null, "instruments": %s,'
				+ ' "files": {"chart": "notes.chart", "song": "song.ogg"}}'
			)
			% instruments
		)
	)
	song.close()
	var chart := FileAccess.open(dir.path_join("notes.chart"), FileAccess.WRITE)
	chart.store_string(FileAccess.get_file_as_string(SAMPLE))
	chart.close()
	return dir


func _play(dir: String, instrument: String, difficulty: String) -> Node:
	var scene: Node = PlayScene.instantiate()
	scene.auto_start = false
	add_child(scene)
	auto_free(scene)
	scene.start(dir, instrument, difficulty, true)
	return scene


func _run_to_end(scene: Node) -> void:
	# Sem áudio, o relógio anda com o frame: 2 s de contagem + ~6 s de música.
	for i in 600:
		scene._process(1.0 / 60.0)
		if scene._done:
			return


func test_autoplay_plays_the_whole_song_without_audio() -> void:
	var scene := _play(_song_dir('{"strings": true, "drums": true}'), "strings", "Expert")
	assert_str(scene.session.instrument).is_equal("strings")
	_run_to_end(scene)
	assert_bool(scene._done).is_true()
	var scoring: Scoring = scene.session.scoring
	assert_int(scoring.hits).is_equal(scene.session.notes.size())
	assert_int(scoring.misses).is_equal(0)


func test_drums_and_defaults() -> void:
	var scene := _play(_song_dir('{"strings": false, "drums": true}'), "strings", "Impossível")
	assert_str(scene.session.instrument).is_equal("drums")  # Cordas ausente: cai na bateria
	assert_str(scene.session.difficulty).is_equal("Hard")
	_run_to_end(scene)
	assert_int(scene.session.scoring.misses).is_equal(0)


func test_errors_are_shown() -> void:
	var missing := _play(create_temp_dir("vazia"), "", "")
	assert_object(missing.session).is_null()
	var nothing := _play(_song_dir('{"strings": false, "drums": false}'), "", "")
	assert_object(nothing.session).is_null()


func test_input_reaches_the_session() -> void:
	var scene := _play(_song_dir('{"strings": true}'), "strings", "Expert")
	var fret := InputEventAction.new()
	fret.action = "fret_0"
	fret.pressed = true
	scene._unhandled_input(fret)
	assert_array(scene.session.held).is_equal(PackedInt32Array([0]))
	var strum := InputEventAction.new()
	strum.action = "strum_down"
	strum.pressed = true
	scene._unhandled_input(strum)
	assert_int(scene.session.scoring.overstrums).is_equal(0)  # sem palhetada (ADR 0015)
	fret.pressed = false
	scene._unhandled_input(fret)
	assert_array(scene.session.held).is_empty()


func test_fret_press_plays_the_note() -> void:
	var scene := _play(_song_dir('{"strings": true}'), "strings", "Expert")
	scene._autoplay = false
	var note: PlayNote = scene.session.notes[0]
	while scene._lead > 0.0 or scene.session.clock.now() < note.time - 0.02:
		scene._process(1.0 / 60.0)
	for lane in note.lanes:
		var fret := InputEventAction.new()
		fret.action = InputProfile.FRETS[lane]
		fret.pressed = true
		scene._unhandled_input(fret)
	assert_int(note.state).is_equal(PlayNote.State.HIT)
	assert_int(scene.session.scoring.hits).is_equal(1)


func test_default_song_has_the_most_instruments() -> void:
	var library := create_temp_dir("biblioteca")
	for entry: Array in [["a", '{"strings": true}'], ["b", '{"strings": true, "drums": true}']]:
		DirAccess.make_dir_absolute(library.path_join(entry[0]))
		var song := FileAccess.open(
			library.path_join(entry[0]).path_join("song.json"), FileAccess.WRITE
		)
		song.store_string('{"instruments": %s}' % entry[1])
		song.close()
	DirAccess.make_dir_absolute(library.path_join("incompleta"))
	var play: GDScript = load("res://game/play.gd")
	assert_str(play.default_song(library)).is_equal(library.path_join("b"))
	assert_str(play.default_song(library.path_join("nada"))).is_equal("")
