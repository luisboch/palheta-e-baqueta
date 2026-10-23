extends GdUnitTestSuite


func test_input_profile_p1_and_p2_separation() -> void:
	InputProfile.apply()

	# Ações legadas e P1
	assert_bool(InputMap.has_action("fret_0")).is_true()
	assert_bool(InputMap.has_action("p1_fret_0")).is_true()
	assert_bool(InputMap.has_action("p2_fret_0")).is_true()

	# Helpers por jogador
	var p1_frets := InputProfile.player_frets(0)
	var p2_frets := InputProfile.player_frets(1)
	assert_int(p1_frets.size()).is_equal(5)
	assert_int(p2_frets.size()).is_equal(5)
	assert_str(p1_frets[0]).is_equal("p1_fret_0")
	assert_str(p2_frets[0]).is_equal("p2_fret_0")

	assert_str(InputProfile.player_strum(0)[0]).is_equal("p1_strum_up")
	assert_str(InputProfile.player_strum(1)[0]).is_equal("p2_strum_up")
	assert_str(InputProfile.player_pads(0)[0]).is_equal("p1_kick")
	assert_str(InputProfile.player_pads(1)[0]).is_equal("p2_kick")
	assert_str(InputProfile.player_pause(0)).is_equal("p1_pause")
	assert_str(InputProfile.player_pause(1)).is_equal("p2_pause")

	# Joypad device 0 aciona P1 mas não P2
	var joy0 := InputEventJoypadButton.new()
	joy0.button_index = JOY_BUTTON_A
	joy0.device = 0
	joy0.pressed = true
	assert_bool(joy0.is_action("p1_fret_4")).is_true()
	assert_bool(joy0.is_action("p2_fret_4")).is_false()

	# Joypad device 1 aciona P2 mas não P1
	var joy1 := InputEventJoypadButton.new()
	joy1.button_index = JOY_BUTTON_A
	joy1.device = 1
	joy1.pressed = true
	assert_bool(joy1.is_action("p1_fret_4")).is_false()
	assert_bool(joy1.is_action("p2_fret_4")).is_true()

	# Teclado P1 vs P2
	var key_p1 := InputEventKey.new()
	key_p1.physical_keycode = KEY_A
	key_p1.pressed = true
	assert_bool(key_p1.is_action("p1_fret_0")).is_true()
	assert_bool(key_p1.is_action("p2_fret_0")).is_false()

	var key_p2 := InputEventKey.new()
	key_p2.physical_keycode = KEY_KP_1
	key_p2.pressed = true
	assert_bool(key_p2.is_action("p1_fret_0")).is_false()
	assert_bool(key_p2.is_action("p2_fret_0")).is_true()


func test_frets_follow_the_joystick_guitar_layout() -> void:
	InputProfile.apply()
	# L2 (traste 0) é eixo: conta como traste a partir da metade do curso, e soltar volta a "solto".
	var half := InputEventJoypadMotion.new()
	half.axis = JOY_AXIS_TRIGGER_LEFT
	half.axis_value = 0.3
	assert_bool(half.is_action_pressed("p1_fret_0")).is_false()
	half.axis_value = 0.8
	assert_bool(half.is_action_pressed("p1_fret_0")).is_true()
	half.axis_value = 0.0
	assert_bool(half.is_action_released("p1_fret_0")).is_true()

	var r2 := InputEventJoypadMotion.new()
	r2.axis = JOY_AXIS_TRIGGER_RIGHT
	r2.axis_value = 1.0
	r2.device = 1
	assert_bool(r2.is_action_pressed("p2_fret_3")).is_true()
	assert_bool(r2.is_action_pressed("p1_fret_3")).is_false()

	for lane_button: Array in [
		[1, JOY_BUTTON_LEFT_SHOULDER], [2, JOY_BUTTON_RIGHT_SHOULDER], [4, JOY_BUTTON_A]
	]:
		var button := InputEventJoypadButton.new()
		button.button_index = lane_button[1]
		button.pressed = true
		assert_bool(button.is_action_pressed("p1_fret_%d" % lane_button[0])).is_true()

	(
		assert_bool(
			InputProfile.event_for(["axis", JOY_AXIS_TRIGGER_LEFT, 0]) is InputEventJoypadMotion
		)
		. is_true()
	)


func test_menus_accept_and_cancel_from_any_joypad() -> void:
	InputProfile.apply()
	for device in [0, 1]:
		var accept := InputEventJoypadButton.new()
		accept.button_index = JOY_BUTTON_A
		accept.device = device
		accept.pressed = true
		assert_bool(accept.is_action("ui_accept")).is_true()
		var cancel := InputEventJoypadButton.new()
		cancel.button_index = JOY_BUTTON_B
		cancel.device = device
		cancel.pressed = true
		assert_bool(cancel.is_action("ui_cancel")).is_true()
