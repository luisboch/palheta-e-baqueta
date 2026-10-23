extends GdUnitTestSuite


func _notes(spec: Array) -> Array[PlayNote]:
	var out: Array[PlayNote] = []
	for s: Array in spec:
		out.append(PlayNote.new(0, s[0], PackedInt32Array(s[1])))
	return out


func test_grades_by_timing() -> void:
	assert_str(Judge.grade_for(0.02)).is_equal("perfect")
	assert_str(Judge.grade_for(-0.07)).is_equal("good")
	assert_str(Judge.grade_for(0.12)).is_equal("ok")
	assert_str(Judge.grade_for(0.2)).is_equal("")


func test_strum_hits_matching_note() -> void:
	var judge := Judge.new(_notes([[1.0, [2]], [1.5, [0, 2]]]))
	var result := judge.strum(1.03, PackedInt32Array([2]))
	assert_str(result["grade"]).is_equal("perfect")
	assert_int(result["note"].state).is_equal(PlayNote.State.HIT)
	assert_str(judge.strum(1.55, PackedInt32Array([2, 0]))["grade"]).is_equal("good")  # acorde
	assert_int(judge.remaining()).is_equal(0)


func test_anchoring_and_chord_rules() -> void:
	assert_bool(Judge.frets_match(PackedInt32Array([3]), PackedInt32Array([0, 3]))).is_true()
	assert_bool(Judge.frets_match(PackedInt32Array([1]), PackedInt32Array([1, 3]))).is_false()
	assert_bool(Judge.frets_match(PackedInt32Array([0, 2]), PackedInt32Array([0, 1, 2]))).is_false()
	assert_bool(Judge.frets_match(PackedInt32Array([0]), PackedInt32Array())).is_false()


func test_overstrum_keeps_the_note() -> void:
	var judge := Judge.new(_notes([[1.0, [2]]]))
	assert_str(judge.strum(0.5, PackedInt32Array([2]))["grade"]).is_equal(Judge.OVERSTRUM)
	assert_str(judge.strum(1.0, PackedInt32Array([1]))["grade"]).is_equal(Judge.OVERSTRUM)
	assert_str(judge.strum(1.0, PackedInt32Array([2]))["grade"]).is_equal("perfect")


func test_misses_after_window() -> void:
	var judge := Judge.new(_notes([[1.0, [0]], [2.0, [1]], [3.0, [2]]]))
	assert_array(judge.update(1.1)).is_empty()
	var missed := judge.update(2.2)
	assert_int(missed.size()).is_equal(2)
	assert_int(missed[1].state).is_equal(PlayNote.State.MISSED)
	assert_int(judge.remaining()).is_equal(1)
	assert_str(judge.strum(1.0, PackedInt32Array([0]))["grade"]).is_equal(Judge.OVERSTRUM)


func test_drum_pads() -> void:
	var judge := Judge.new(_notes([[1.0, [0]], [1.0, [1]], [1.25, [1]]]))
	assert_str(judge.hit_pad(1.01, 1)["grade"]).is_equal("perfect")
	assert_str(judge.hit_pad(1.02, 0)["grade"]).is_equal("perfect")
	assert_dict(judge.hit_pad(1.02, 4)).is_empty()  # batida a mais: ignorada
	assert_str(judge.hit_pad(1.2, 1)["grade"]).is_equal("good")
	assert_dict(judge.hit_pad(1.6, 1)).is_empty()


func test_tap_builds_chords_without_penalty() -> void:
	var judge := Judge.new(_notes([[1.0, [0, 2]], [2.0, [3]]]))
	assert_dict(judge.tap(1.0, PackedInt32Array([0]))).is_empty()  # montando o acorde
	assert_str(judge.tap(1.01, PackedInt32Array([0, 2]))["grade"]).is_equal("perfect")
	assert_dict(judge.tap(1.5, PackedInt32Array([3]))).is_empty()  # cedo demais: nada
	assert_str(judge.tap(2.1, PackedInt32Array([0, 3]))["grade"]).is_equal("ok")  # ancoragem
