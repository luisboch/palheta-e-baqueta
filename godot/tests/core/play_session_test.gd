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


func _last_sustain(s: PlaySession) -> PlayNote:
	var note := s.notes[s.notes.size() - 1]
	assert_bool(note.is_sustain()).is_true()
	return note


func test_holding_a_sustain_to_the_end_scores_each_beat() -> void:
	var s := _session("strings", "Expert")
	var note := _last_sustain(s)
	s.held = note.lanes.duplicate()
	s.strum(note.time)
	assert_object(s.sustain).is_same(note)
	var mid := (note.time + note.end_time) / 2.0
	var events := s.update(mid, 0.016)
	assert_float(events["bend"]).is_equal(0.0)
	s.whammy = 1.0
	assert_float(s.update(mid, 0.016)["bend"]).is_equal(1.0)  # o som só dobra segurando
	assert_bool(note.holding).is_true()
	events = s.update(note.end_time + 1.0, 0.016)
	assert_object(events["dropped"]).is_null()
	assert_object(s.sustain).is_null()
	assert_bool(note.dropped()).is_false()
	# 480 ticks = 2,5 batidas × 25 pontos; a segunda metade com o whammy no máximo (+50%)
	assert_int(s.scoring.sustain_score).is_equal(int(1.25 * 25 + 1.25 * 25 * 1.5))
	assert_float(s.update(note.end_time + 2.0, 0.016)["bend"]).is_equal(0.0)


func test_releasing_a_sustain_early_stops_the_points_without_a_miss() -> void:
	var s := _session("strings", "Expert")
	var note := _last_sustain(s)
	s.held = note.lanes.duplicate()
	s.strum(note.time)
	s.update(note.time + 0.25, 0.016)
	var points := s.scoring.sustain_score
	assert_int(points).is_greater(0)
	s.release_fret(note.lanes[1])
	var events := s.update(note.time + 0.5, 0.016)
	assert_object(events["dropped"]).is_same(note)
	assert_bool(note.dropped()).is_true()
	assert_float(note.held_until).is_equal_approx(note.time + 0.25, 1e-6)
	s.held = note.lanes.duplicate()  # apertar de novo não volta a segurar
	s.update(note.end_time, 0.016)
	assert_int(s.scoring.sustain_score).is_equal(points)
	# soltar não é erro: só as notas anteriores, que o teste pulou, contam como perdidas
	assert_int(s.scoring.misses).is_equal(s.notes.size() - 1)
	assert_int(note.state).is_equal(PlayNote.State.HIT)


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


func test_sync_frets_releases_a_fret_whose_release_event_was_lost() -> void:
	var s := _session("strings", "Expert")
	s.press_fret(0)
	s.press_fret(3)
	var released := s.sync_frets(PackedInt32Array([0]))
	assert_array(released).contains_exactly([3])
	assert_array(s.held).contains_exactly([0])
