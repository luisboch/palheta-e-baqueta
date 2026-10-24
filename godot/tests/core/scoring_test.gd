extends GdUnitTestSuite


func test_multiplier_grows_every_ten_and_caps() -> void:
	var s := Scoring.new()
	for i in 9:
		s.on_hit("perfect")
	assert_int(s.multiplier()).is_equal(1)
	s.on_hit("perfect")
	assert_int(s.multiplier()).is_equal(2)
	for i in 40:
		s.on_hit("perfect")
	assert_int(s.multiplier()).is_equal(4)
	assert_int(s.best_streak).is_equal(50)


func test_points_and_breaks() -> void:
	var s := Scoring.new()
	s.on_hit("perfect")
	s.on_hit("ok")
	assert_int(s.score).is_equal(150)
	s.on_miss()
	assert_int(s.streak).is_equal(0)
	s.on_hit("good")
	s.on_overstrum()
	assert_int(s.streak).is_equal(0)
	assert_int(s.overstrums).is_equal(1)
	assert_float(s.accuracy()).is_equal_approx(0.75, 1e-9)
	assert_dict(s.grades).is_equal({"perfect": 1, "good": 1, "ok": 1})
	assert_float(Scoring.new().accuracy()).is_equal(1.0)


func test_sustain_points_per_beat_with_multiplier_and_whammy() -> void:
	var s := Scoring.new()
	s.on_sustain(1.0, 0.0)
	assert_int(s.score).is_equal(25)
	s.on_sustain(1.0, 1.0)
	assert_int(s.score).is_equal(25 + 37)  # +50% com a alavanca no máximo; sobra meio ponto
	s.on_sustain(0.02, 0.0)  # o meio ponto guardado mais 0,5 deste quadro
	assert_int(s.score).is_equal(63)
	for i in 10:
		s.on_hit("perfect")
	var before := s.score
	s.on_sustain(1.0, 0.0)
	assert_int(s.score - before).is_equal(50)  # vezes o multiplicador (2×)
	assert_int(s.sustain_score).is_equal(113)
	assert_int(s.streak).is_equal(10)  # segurar não conta acerto
