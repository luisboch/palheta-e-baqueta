extends GdUnitTestSuite


func test_steady_tempo() -> void:
	var tm := TempoMap.new([[0, 120000]])
	assert_float(tm.time(192)).is_equal_approx(0.5, 1e-9)
	assert_float(tm.tick(1.0)).is_equal_approx(384.0, 1e-9)
	assert_float(tm.bpm_at(10.0)).is_equal(120.0)


func test_tempo_changes_match_the_backend() -> void:
	# O mesmo mapa do chart de exemplo: 120 BPM até o tick 1728, depois 150.
	var tm := TempoMap.new([[0, 120000], [1728, 150000]])
	assert_float(tm.time(1728)).is_equal_approx(4.5, 1e-9)
	assert_float(tm.time(1920)).is_equal_approx(4.9, 1e-9)
	assert_float(tm.tick(4.9)).is_equal_approx(1920.0, 1e-6)
	assert_float(tm.tick(0.25)).is_equal_approx(96.0, 1e-9)
	assert_float(tm.bpm_at(5.0)).is_equal(150.0)


func test_missing_initial_tempo_defaults_to_120() -> void:
	var tm := TempoMap.new([[384, 60000]])
	assert_float(tm.time(384)).is_equal_approx(1.0, 1e-9)
	assert_float(tm.time(576)).is_equal_approx(2.0, 1e-9)
	assert_float(TempoMap.new([]).time(192)).is_equal_approx(0.5, 1e-9)


func test_roundtrip_many_changes() -> void:
	var tempos := []
	for i in 200:
		tempos.append([i * 192, 100000 + (i % 7) * 3131])
	var tm := TempoMap.new(tempos)
	for t in [0.0, 1.234, 37.5, 99.9]:
		assert_float(tm.time(tm.tick(t))).is_equal_approx(t, 1e-6)
