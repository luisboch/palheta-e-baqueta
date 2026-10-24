extends GdUnitTestSuite


func test_stick_deadzone_and_full_range() -> void:
	assert_float(Whammy.stick(Vector2(0.1, 0.1))).is_equal(0.0)
	assert_float(Whammy.stick(Vector2(0.0, -1.0))).is_equal(1.0)
	assert_float(Whammy.stick(Vector2(0.6, 0.0))).is_equal_approx(0.5, 1e-6)
	assert_float(Whammy.stick(Vector2(1.0, 1.0))).is_equal(1.0)


func test_update_takes_the_strongest_input_smoothly() -> void:
	var w := Whammy.new()
	var sticks: Array[Vector2] = [Vector2.ZERO, Vector2(1.0, 0.0)]
	assert_float(w.update(sticks, false, 0.025)).is_equal_approx(0.5, 1e-6)  # meio caminho
	assert_float(w.update(sticks, false, 1.0)).is_equal(1.0)
	var idle: Array[Vector2] = [Vector2.ZERO]
	assert_float(w.update(idle, false, 1.0)).is_equal(0.0)
	assert_float(w.update(idle, true, 1.0)).is_equal(1.0)  # a tecla vale o curso inteiro


func test_pitch_goes_down_up_to_a_whole_tone() -> void:
	assert_float(Whammy.pitch_scale(0.0)).is_equal(1.0)
	assert_float(Whammy.pitch_scale(1.0)).is_equal_approx(pow(2.0, -2.0 / 12.0), 1e-6)
	assert_float(Whammy.pitch_scale(5.0)).is_equal(Whammy.pitch_scale(1.0))
