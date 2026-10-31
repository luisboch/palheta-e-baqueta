extends GdUnitTestSuite


func before() -> void:
	InputProfile.apply()


func test_each_player_reads_only_its_own_controller() -> void:
	for player in 2:
		for action in InputProfile.player_frets(player):
			for event in InputMap.action_get_events(action):
				if event is InputEventJoypadButton or event is InputEventJoypadMotion:
					assert_int(event.device).is_equal(player)


func test_nothing_is_down_without_input() -> void:
	assert_array(InputReader.lanes_down(0, false)).is_empty()
	assert_array(InputReader.lanes_down(1, true)).is_empty()


func _button(device: int, index: int, pressed := true) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = index
	event.pressed = pressed
	return event


func _axis(device: int, axis: int, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.device = device
	event.axis = axis
	event.axis_value = value
	return event


func test_a_button_event_presses_only_its_players_fret() -> void:
	var reader := InputReader.new()
	var l1 := _button(0, JOY_BUTTON_LEFT_SHOULDER)
	assert_array(reader.pressed_by(l1, 0, false)).is_equal(PackedInt32Array([1]))
	assert_array(reader.pressed_by(l1, 1, false)).is_empty()  # controle 1 não toca no jogador 2
	var release := _button(0, JOY_BUTTON_LEFT_SHOULDER, false)
	assert_array(reader.pressed_by(release, 0, false)).is_empty()


func test_a_trigger_presses_once_when_it_crosses_the_deadzone() -> void:
	var reader := InputReader.new()
	assert_array(reader.pressed_by(_axis(0, JOY_AXIS_TRIGGER_LEFT, 0.3), 0, false)).is_empty()
	var down := reader.pressed_by(_axis(0, JOY_AXIS_TRIGGER_LEFT, 0.8), 0, false)
	assert_array(down).is_equal(PackedInt32Array([0]))
	assert_array(reader.pressed_by(_axis(0, JOY_AXIS_TRIGGER_LEFT, 1.0), 0, false)).is_empty()
	reader.pressed_by(_axis(0, JOY_AXIS_TRIGGER_LEFT, 0.1), 0, false)
	assert_array(reader.pressed_by(_axis(0, JOY_AXIS_TRIGGER_LEFT, 0.9), 0, false)).has_size(1)


func test_drums_read_the_strings_buttons() -> void:
	var reader := InputReader.new()
	var a := _button(0, JOY_BUTTON_A)
	assert_array(reader.pressed_by(a, 0, true)).is_equal(PackedInt32Array([0]))  # bumbo
