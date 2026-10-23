extends GdUnitTestSuite


func _sample() -> Dictionary:
	return ChartParser.parse(
		FileAccess.get_file_as_string("res://tests/fixtures/pipeline_sample.chart")
	)


func test_strings_group_chords_and_sustain() -> void:
	var chart := _sample()
	var tm := TempoMap.new(chart["tempos"], chart["resolution"])
	var notes := NoteTrack.build(chart, "ExpertSingle", tm, false)
	assert_int(notes.size()).is_equal(7)
	assert_float(notes[0].time).is_equal_approx(0.5, 1e-9)  # 1ª batida em 0,5 s, como no backend
	var last := notes[notes.size() - 1]
	assert_int(last.lanes.size()).is_equal(2)  # acorde de 2
	assert_bool(last.is_sustain()).is_true()
	assert_bool(notes[0].is_sustain()).is_false()


func test_drums_one_note_per_piece_with_cymbals() -> void:
	var chart := _sample()
	var tm := TempoMap.new(chart["tempos"], chart["resolution"])
	var notes := NoteTrack.build(chart, "ExpertDrums", tm, true)
	var first: Array[PlayNote] = notes.filter(func(n: PlayNote) -> bool: return n.tick == 192)
	var lanes := first.map(func(n: PlayNote) -> int: return n.lanes[0])
	assert_array(lanes).is_equal([0, 2, 4])  # bumbo, chimbal e prato (sem as marcas 66/68)
	assert_bool(first[1].cymbal).is_true()
	assert_bool(first[0].cymbal).is_false()


func test_ignores_unknown_lanes_and_missing_tracks() -> void:
	var chart := {"tracks": {"ExpertSingle": [[0, 7, 0], [192, 1, 0]]}}
	var tm := TempoMap.new([[0, 120000]])
	assert_int(NoteTrack.build(chart, "ExpertSingle", tm, false).size()).is_equal(1)
	assert_int(NoteTrack.build(chart, "HardSingle", tm, false).size()).is_equal(0)
