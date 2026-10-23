extends GdUnitTestSuite


func test_audio_time_includes_mix_latency_and_offset() -> void:
	var clock := SongClock.new()
	clock.offset = 0.03
	assert_float(clock.audio_time(10.0, 0.01, 0.02)).is_equal_approx(9.96, 1e-9)


func test_smooth_and_monotonic() -> void:
	var clock := SongClock.new()
	assert_float(clock.update(1.0, 0.0, 0.0, 0.016)).is_equal(1.0)
	# O player só anda a cada mistura: a posição repete, o relógio continua andando.
	var t1 := clock.update(1.0, 0.0, 0.0, 0.016)
	var t2 := clock.update(1.0, 0.0, 0.0, 0.016)
	assert_float(t1).is_greater(1.0)
	assert_float(t2).is_greater(t1)
	# A posição do áudio pula de volta um pouco (nova mistura): o relógio não volta.
	var t3 := clock.update(t2 - 0.02, 0.0, 0.0, 0.016)
	assert_float(t3).is_greater_equal(t2)


func test_resyncs_on_big_jumps_and_reset() -> void:
	var clock := SongClock.new()
	clock.update(1.0, 0.0, 0.0, 0.016)
	assert_float(clock.update(30.0, 0.0, 0.0, 0.016)).is_equal(30.0)  # seek
	assert_float(clock.update(5.0, 0.0, 0.0, 0.016)).is_equal(5.0)  # voltou de verdade
	clock.reset()
	assert_float(clock.update(2.0, 0.0, 0.0, 0.016)).is_equal(2.0)
	assert_float(clock.now()).is_equal(2.0)
