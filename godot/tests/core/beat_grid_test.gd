extends GdUnitTestSuite


func _grid() -> BeatGrid:
	return BeatGrid.from_beatmap({"beats": [1.0, 1.5, 2.0, 2.5, 3.0], "downbeats": [1.0, 3.0, 9.0]})


func test_pulse_peaks_on_beats_and_doubles_on_downbeats() -> void:
	var grid := _grid()
	assert_float(grid.pulse(0.5)).is_equal(0.0)
	assert_float(grid.pulse(1.0)).is_equal_approx(2.0, 0.001)  # downbeat
	assert_float(grid.pulse(1.5)).is_equal_approx(1.0, 0.001)
	assert_float(grid.pulse(1.74)).is_less(0.2)  # quase na próxima: caiu
	assert_float(grid.pulse(3.05)).is_greater(0.5)  # última batida usa o intervalo anterior


func test_between_lists_beats_with_downbeat_flag() -> void:
	var grid := _grid()
	assert_array(grid.between(1.2, 2.0)).is_equal([[1.5, false], [2.0, false]])
	assert_array(grid.between(2.9, 9.0)).is_equal([[3.0, true]])
	assert_int(grid.index_at(0.0)).is_equal(-1)
	assert_int(grid.index_at(2.2)).is_equal(2)
	assert_float(grid.phase(2.25)).is_equal_approx(0.5, 0.001)
	assert_float(grid.phase(0.0)).is_equal(-1.0)
	assert_int(grid.bar_at(0.5)).is_equal(-1)
	assert_int(grid.bar_at(2.9)).is_equal(0)
	assert_int(grid.bar_at(3.0)).is_equal(1)
	assert_float(grid.bar_phase(2.0)).is_equal_approx(0.5, 0.001)
	assert_float(grid.bar_phase(4.0)).is_equal_approx(0.5, 0.001)  # último: duração do anterior
	assert_float(grid.bar_phase(0.0)).is_equal(-1.0)
	(
		assert_float(BeatGrid.from_beatmap({"beats": [1.0], "downbeats": [1.0]}).bar_phase(2.0))
		. is_equal(0.0)
	)


func test_from_tempo_without_beatmap() -> void:
	var grid := BeatGrid.from_tempo(TempoMap.new([[0, 120000]]), 2.0)
	assert_array(grid.between(0.0, 2.0)).is_equal(
		[[0.0, true], [0.5, false], [1.0, false], [1.5, false], [2.0, true]]
	)
	assert_float(BeatGrid.new().pulse(1.0)).is_equal(0.0)
	assert_int(grid.bar_at(1.9)).is_equal(0)
