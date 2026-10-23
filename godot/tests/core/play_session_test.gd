extends GdUnitTestSuite

const SAMPLE := "res://tests/fixtures/pipeline_sample.chart"


func _session(instrument: String, difficulty: String) -> PlaySession:
	var chart := ChartParser.parse(FileAccess.get_file_as_string(SAMPLE))
	return PlaySession.new(chart, instrument, difficulty)


func test_perfect_run_of_the_sample_song() -> void:
	var s := _session("strings", "Expert")
	for note in s.notes:
		s.held = note.lanes.duplicate()
		assert_str(s.strum(note.time)["grade"]).is_equal("perfect")
	s.update(s.duration + 1.0, 0.016)
	assert_bool(s.finished(s.duration + 1.0)).is_true()
	assert_int(s.scoring.hits).is_equal(s.notes.size())
	assert_int(s.scoring.misses).is_equal(0)
	assert_float(s.mix.volume_db).is_equal(StemMix.NORMAL_DB)


func test_missing_everything_ducks_the_stem() -> void:
	var s := _session("drums", "Easy")
	var events := s.update(s.duration + 1.0, 1.0)
	assert_int(events["missed"].size()).is_equal(s.notes.size())
	assert_int(s.scoring.misses).is_equal(s.notes.size())
	assert_float(events["volume_db"]).is_equal(StemMix.MISSED_DB)


func test_drums_pads_and_frets_bookkeeping() -> void:
	var s := _session("drums", "Expert")
	var first := s.notes[0]
	assert_str(s.pad(first.time, first.lanes[0])["grade"]).is_equal("perfect")
	assert_dict(s.pad(first.time, 3)).is_empty()
	s.press_fret(2)
	s.press_fret(2)
	s.press_fret(4)
	s.release_fret(2)
	s.release_fret(1)
	assert_array(s.held).is_equal(PackedInt32Array([4]))
	assert_str(s.strum(-5.0)["grade"]).is_equal(Judge.OVERSTRUM)
	assert_int(s.scoring.overstrums).is_equal(1)
	assert_dict(s.tap(-5.0)).is_empty()
	assert_int(s.scoring.overstrums).is_equal(1)  # traste sem nota não pune
	assert_bool(s.finished(0.0)).is_false()


func test_song_loader_and_input_profile() -> void:
	var dir := create_temp_dir("song")
	var bad := SongLoader.load_dir(dir)
	assert_bool(bad["ok"]).is_false()
	assert_str(bad["error"]).contains("sem song.json")
	var song := FileAccess.open(dir.path_join("song.json"), FileAccess.WRITE)
	song.store_string('{"version": 1, "files": {"chart": "notes.chart", "song": "song.ogg"}}')
	song.close()
	assert_str(SongLoader.load_dir(dir)["error"]).contains("sem chart")
	var chart := FileAccess.open(dir.path_join("notes.chart"), FileAccess.WRITE)
	chart.store_string(FileAccess.get_file_as_string(SAMPLE))
	chart.close()
	var loaded := SongLoader.load_dir(dir)
	assert_bool(loaded["ok"]).is_true()
	assert_str(loaded["chart"]["name"]).is_equal("Exemplo do pipeline")
	assert_str(SongLoader.file_path(loaded, "song")).is_equal("")  # o ogg não existe
	assert_str(SongLoader.file_path(loaded, "chart")).ends_with("notes.chart")
	assert_str(SongLoader.file_path(loaded, "cover")).is_equal("")
	assert_dict(loaded["beatmap"]).is_empty()

	var newer := FileAccess.open(dir.path_join("song.json"), FileAccess.WRITE)
	newer.store_string('{"version": 99}')
	newer.close()
	assert_str(SongLoader.load_dir(dir)["error"]).contains("versão mais nova")
	var broken := FileAccess.open(dir.path_join("song.json"), FileAccess.WRITE)
	broken.store_string("{quebrado")
	broken.close()
	assert_str(SongLoader.load_dir(dir)["error"]).contains("inválido")

	InputProfile.apply()
	assert_bool(InputMap.has_action("fret_0")).is_true()
	assert_bool(InputMap.has_action("kick")).is_true()
	var joy := InputProfile.event_for(["joy", JOY_BUTTON_A])
	assert_bool(joy is InputEventJoypadButton).is_true()
