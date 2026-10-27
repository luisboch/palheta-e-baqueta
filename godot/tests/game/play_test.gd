extends GdUnitTestSuite

const SAMPLE := "res://tests/fixtures/pipeline_sample.chart"
const PlayScene := preload("res://game/play.tscn")


func _song_dir(instruments: String, beatmap := "") -> String:
	var dir := create_temp_dir("play_song")
	if beatmap != "":
		var beats := FileAccess.open(dir.path_join("beatmap.json"), FileAccess.WRITE)
		beats.store_string(beatmap)
		beats.close()
	var song := FileAccess.open(dir.path_join("song.json"), FileAccess.WRITE)
	(
		song
		. store_string(
			(
				(
					'{"version": 1, "title": "Exemplo", "artist": null, "instruments": %s,'
					+ ' "files": {"chart": "notes.chart", "song": "song.ogg", "beatmap": "beatmap.json"}}'
				)
				% instruments
			)
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
	var beatmap := '{"beats": [0.5, 1.0, 1.5, 2.0, 2.5], "downbeats": [0.5, 2.5]}'
	var scene := _play(_song_dir('{"strings": true, "drums": true}', beatmap), "strings", "Expert")
	assert_array(scene._grid.beats).is_equal(PackedFloat64Array([0.5, 1.0, 1.5, 2.0, 2.5]))
	assert_str(scene.session.instrument).is_equal("strings")
	_run_to_end(scene)
	assert_bool(scene._done).is_true()
	var scoring: Scoring = scene.session.scoring
	assert_int(scoring.hits).is_equal(scene.session.notes.size())
	assert_int(scoring.misses).is_equal(0)


func test_sustain_is_held_on_the_line_and_dims_when_released() -> void:
	var scene := _play(_song_dir('{"strings": true}'), "strings", "Expert")
	var s: PlaySession = scene.session
	var road: Highway = scene.highway
	for i in 600:
		scene._process(1.0 / 60.0)
		if s.sustain and s.clock.now() > s.sustain.time + 0.1:
			break
	var note := s.sustain
	assert_object(note).is_not_null()
	var hold: ImmediateMesh = road._hold.mesh
	assert_int(hold.get_surface_count()).is_equal(1)  # a cauda segurada, acesa na linha
	assert_bool(road._views[note].visible).is_false()
	assert_int(s.scoring.sustain_score).is_greater(0)
	scene._autoplay = false
	s.held = PackedInt32Array()  # soltou os trastes
	scene._process(1.0 / 60.0)
	assert_bool(note.dropped()).is_true()
	assert_int(hold.get_surface_count()).is_equal(0)
	var view: Node3D = road._views[note]
	assert_bool(view.visible).is_true()
	for child: MeshInstance3D in view.get_children():
		if child.name.begins_with("Tail"):
			var mat: StandardMaterial3D = child.material_override
			assert_object(mat.albedo_color).is_equal(Highway.MISS_COLOR)
		else:
			assert_bool(child.visible).is_false()


func test_drums_and_defaults() -> void:
	var scene := _play(_song_dir('{"strings": false, "drums": true}'), "strings", "Impossível")
	assert_str(scene.session.instrument).is_equal("drums")  # Cordas ausente: cai na bateria
	assert_str(scene.session.difficulty).is_equal("Hard")
	assert_bool(scene._grid.beats.is_empty()).is_false()  # sem beatmap: batidas do mapa de tempo
	_run_to_end(scene)
	assert_int(scene.session.scoring.misses).is_equal(0)


func test_errors_are_shown() -> void:
	var missing := _play(create_temp_dir("vazia"), "", "")
	assert_object(missing.session).is_null()
	var nothing := _play(_song_dir('{"strings": false, "drums": false}'), "", "")
	assert_object(nothing.session).is_null()


func test_input_reaches_the_session() -> void:
	var scene := _play(_song_dir('{"strings": true}'), "strings", "Expert")
	var road: Highway = scene.highway
	scene._read_input(scene.session, road, PackedInt32Array([0]), -5.0)
	assert_array(scene.session.held).is_equal(PackedInt32Array([0]))
	assert_int(scene.session.scoring.overstrums).is_equal(1)  # traste sem nota é erro (ADR 0024)
	var strum := InputEventAction.new()
	strum.action = "strum_down"
	strum.pressed = true
	scene._unhandled_input(strum)
	assert_int(scene.session.scoring.overstrums).is_equal(1)  # a palhetada é ignorada (ADR 0015)
	scene._read_input(scene.session, road, PackedInt32Array(), -5.0)
	assert_array(scene.session.held).is_empty()


func test_fret_press_plays_the_note() -> void:
	var scene := _play(_song_dir('{"strings": true}'), "strings", "Expert")
	scene._autoplay = false
	var note: PlayNote = scene.session.notes[0]
	while scene._lead > 0.0 or scene.session.clock.now() < note.time - 0.02:
		scene._process(1.0 / 60.0)
	scene._read_input(scene.session, scene.highway, note.lanes, scene.session.clock.now())
	assert_int(note.state).is_equal(PlayNote.State.HIT)
	assert_int(scene.session.scoring.hits).is_equal(1)  # o acorde conta uma vez


func test_a_higher_fret_still_held_does_not_block_the_next_note() -> void:
	var scene := _play(_song_dir('{"strings": true}'), "strings", "Expert")
	var note: PlayNote = scene.session.notes[0]
	var higher := (note.lanes[note.lanes.size() - 1] + 1) % 5
	if higher < note.lanes[0]:
		higher = 4  # qualquer traste mais agudo que a nota
	var down := note.lanes.duplicate()
	down.append(higher)  # o dedo ainda no outro traste, o caso do R2 nos logs
	scene._read_input(scene.session, scene.highway, down, note.time)
	assert_int(note.state).is_equal(PlayNote.State.HIT)


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


func test_results_and_leaving_go_back_to_the_menu() -> void:
	var dir := _song_dir('{"strings": true}')
	App.selection = {"id": "x", "dir": dir, "instrument": "strings", "difficulty": "Easy"}
	var scene: Node = PlayScene.instantiate()  # auto_start: vem do menu (App.selection)
	add_child(scene)
	auto_free(scene)
	assert_str(scene.session.difficulty).is_equal("Easy")
	scene._autoplay = true
	_run_to_end(scene)
	assert_bool(scene.get_node("%Results").visible).is_true()
	scene.get_node("%Again").pressed.emit()
	assert_str(App.last_scene).is_equal(App.PLAY)
	scene.get_node("%Choose").pressed.emit()
	assert_str(App.last_scene).is_equal(App.SONG_SELECT)
	App.selection = {}


func test_pause_stops_the_clock_and_resumes() -> void:
	var scene := _play(_song_dir('{"strings": true}'), "strings", "Expert")
	for i in 30:
		scene._process(1.0 / 60.0)
	scene._read_input(scene.session, scene.highway, PackedInt32Array([2]), 0.0)
	var esc := InputEventAction.new()
	esc.action = InputProfile.PAUSE
	esc.pressed = true
	scene._unhandled_input(esc)
	assert_bool(scene.paused).is_true()
	assert_bool(scene.get_node("%Pause").visible).is_true()
	assert_array(scene.session.held).is_empty()  # os trastes valem o que está apertado de verdade
	var lead: float = scene._lead
	scene._process(0.5)
	assert_float(scene._lead).is_equal(lead)  # parado
	scene.get_node("%Resume").pressed.emit()
	assert_bool(scene.paused).is_false()
	assert_bool(scene.get_node("%Pause").visible).is_false()
	scene._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)  # botão Steam
	assert_bool(scene.paused).is_true()
	scene._unhandled_input(esc)
	assert_bool(scene.paused).is_false()
	App.selection = {"dir": "x"}
	scene.get_node("%QuitSong").pressed.emit()
	assert_str(App.last_scene).is_equal(App.SONG_SELECT)
	scene.get_node("%Restart").pressed.emit()
	assert_str(App.last_scene).is_equal(App.PLAY)
	App.selection = {}


func test_two_player_mode_spawns_two_highways_and_runs_both() -> void:
	var dir := _song_dir('{"strings": true, "drums": true}')
	var scene: Node = PlayScene.instantiate()
	scene.auto_start = false
	add_child(scene)
	auto_free(scene)

	scene.start(dir, "strings", "Hard", true, "coop", "drums", "Medium")
	assert_that(scene.session_2).is_not_null()
	assert_str(scene.session.instrument).is_equal("strings")
	assert_str(scene.session_2.instrument).is_equal("drums")
	assert_that(scene.highway_2).is_not_null()
	assert_float(scene.highway.position.x).is_less(0.0)
	assert_float(scene.highway_2.position.x).is_greater(0.0)
	# Tela dividida: cada câmera na sua metade, no centro da própria pista.
	assert_that(scene.split).is_not_null()
	assert_that(scene.camera.get_viewport()).is_not_equal(scene.get_viewport())
	assert_that(scene.camera_2.get_viewport()).is_not_equal(scene.camera.get_viewport())
	assert_float(scene.camera.global_position.x).is_equal(scene.highway.position.x)
	assert_float(scene.camera_2.global_position.x).is_equal(scene.highway_2.position.x)

	# Banda: placar único no centro, sequência de cada um sobre a própria pista.
	var band: Label = scene.get_node("%Band")
	assert_bool(band.visible).is_true()
	assert_bool(scene.get_node("%Duel").visible).is_false()
	assert_bool(scene.get_node("Hud/Score").visible).is_false()

	_run_to_end(scene)
	assert_bool(scene._done).is_true()
	assert_int(scene.session.scoring.hits).is_greater(0)
	assert_int(scene.session_2.scoring.hits).is_greater(0)
	assert_bool(band.visible).is_false()  # o resultado ocupa o lugar dele
	var total: int = scene.session.scoring.score + scene.session_2.scoring.score
	assert_str(band.text).contains("%d pontos" % total)
	assert_bool(scene.highway.combo.visible).is_true()
	assert_bool(scene.highway_2.combo.visible).is_true()
	assert_str(scene.highway.combo.text).starts_with("P1 · Cordas")
	assert_str(scene.highway_2.combo.text).starts_with("P2 · Bateria")
	assert_str(scene.highway_2.combo.text).contains("%d seguidas" % scene.session_2.scoring.streak)
	# Resultado: estrelas (autoplay acerta tudo) e a parte de cada um.
	assert_bool(scene.get_node("%Results").visible).is_true()
	assert_str(scene.get_node("%Stars").text).is_equal("★★★★★")
	assert_str(scene.get_node("%Points").text).is_equal("%d pontos" % total)
	assert_str(scene.get_node("%Accuracy").text).starts_with("P1 · Cordas")
	assert_str(scene.get_node("%Detail").text).starts_with("P2 · Bateria")
	assert_str(scene.get_node("%Detail").text).contains("acerto 100%")


func test_versus_mode_shows_leader_and_winner() -> void:
	var dir := _song_dir('{"strings": true, "bass": true}')
	var scene: Node = PlayScene.instantiate()
	scene.auto_start = false
	add_child(scene)
	auto_free(scene)

	scene.start(dir, "strings", "Hard", true, "versus", "bass", "Hard")
	assert_str(scene.get_node("Hud/Title").text).contains("Duelo")
	assert_bool(scene.get_node("%Duel").visible).is_true()
	assert_bool(scene.get_node("%Band").visible).is_false()
	_run_to_end(scene)
	assert_bool(scene.get_node("%Results").visible).is_true()
	assert_bool(scene.get_node("%Stars").visible).is_false()
	assert_str(scene.get_node("%Detail").text).starts_with("Notas:")

	var p1: Scoring = scene.session.scoring
	var p2: Scoring = scene.session_2.scoring
	p1.score = 500
	p2.score = 300
	scene.hud.update_score(p1, p2)
	assert_str(scene.get_node("%DuelP1").text).is_equal("P1  500")
	assert_str(scene.get_node("%DuelP2").text).is_equal("300  P2")
	assert_str(scene.get_node("%Lead").text).starts_with("◄")
	scene.hud.show_results(p1, p2)
	assert_str(scene.get_node("%Header").text).is_equal("P1 VENCEU!")
	p2.score = 900
	scene.hud.update_score(p1, p2)
	assert_str(scene.get_node("%Lead").text).ends_with("►")
	scene.hud.show_results(p1, p2)
	assert_str(scene.get_node("%Header").text).is_equal("P2 VENCEU!")
	p1.score = 900
	scene.hud.show_results(p1, p2)
	assert_str(scene.get_node("%Header").text).is_equal("EMPATE!")


func test_two_player_mode_routes_inputs_to_correct_player() -> void:
	var dir := _song_dir('{"strings": true, "bass": true}')
	var scene: Node = PlayScene.instantiate()
	scene.auto_start = false
	add_child(scene)
	auto_free(scene)

	scene.start(dir, "strings", "Hard", false, "versus", "bass", "Hard")
	assert_that(scene.session_2).is_not_null()

	scene._read_input(scene.session, scene.highway, PackedInt32Array([0]), -5.0)
	assert_array(scene.session.held).is_equal(PackedInt32Array([0]))
	assert_array(scene.session_2.held).is_empty()

	scene._read_input(scene.session_2, scene.highway_2, PackedInt32Array([2]), -5.0)
	assert_array(scene.session.held).is_equal(PackedInt32Array([0]))
	assert_array(scene.session_2.held).is_equal(PackedInt32Array([2]))

	scene._read_input(scene.session, scene.highway, PackedInt32Array(), -5.0)
	scene._read_input(scene.session_2, scene.highway_2, PackedInt32Array(), -5.0)
	assert_array(scene.session.held).is_empty()
	assert_array(scene.session_2.held).is_empty()


func test_drum_pads_hit_once_per_press() -> void:
	var scene := _play(_song_dir('{"strings": false, "drums": true}'), "drums", "Expert")
	scene._autoplay = false
	var note: PlayNote = scene.session.notes[0]
	scene._read_input(scene.session, scene.highway, note.lanes, note.time)
	assert_int(note.state).is_equal(PlayNote.State.HIT)
	var hits: int = scene.session.scoring.hits
	scene._read_input(scene.session, scene.highway, note.lanes, note.time + 0.01)  # segurando
	assert_int(scene.session.scoring.hits).is_equal(hits)
	scene._read_input(scene.session, scene.highway, PackedInt32Array(), note.time + 0.02)
	assert_array(scene.session.held).is_empty()


func test_comic_effects_follow_the_player() -> void:
	var scene := _play(_song_dir('{"strings": true}'), "strings", "Expert")
	var road: Highway = scene.highway
	road.set_fret(2, true)
	road.set_fret(2, false)
	road._pop(2)  # onda de choque e faíscas
	assert_bool(road._rings[2].get_node("Wave").visible).is_true()
	road.set_power(4, 1.0)  # 4×: bordas amarelas, pulsando
	assert_object(road._rail_material.emission).is_equal(Comic.YELLOW)
	assert_float(road._rail_material.emission_energy_multiplier).is_greater(Highway.RAIL_GLOW[3])
	road.on_miss(scene.session.notes[0])  # a pista treme
	assert_float(road._miss).is_equal(Highway.MISS_TIME)
	var scoring := Scoring.new()
	scoring.streak = Scoring.STREAK_PER_STEP * (Scoring.MAX_MULTIPLIER - 1)
	var bursts: int = scene.hud.get_child_count()
	scene.hud.update_score(scoring, null, 0.5)  # chegou ao 4×: "Energia máxima!"
	assert_int(scene.hud.get_child_count()).is_equal(bursts + 1)
	scene.hud.update_score(scoring, null, 0.5)  # continua no 4×: não repete
	assert_int(scene.hud.get_child_count()).is_equal(bursts + 1)
	var meter: PowerMeter = scene.get_node("%Meter")
	assert_float(meter.progress).is_equal(1.0)
	for i in 30:  # balanço da câmera, palco e refletores no ritmo
		scene._process(1.0 / 60.0)
	assert_vector(scene.camera.position).is_not_equal(scene._camera_rest[0])
