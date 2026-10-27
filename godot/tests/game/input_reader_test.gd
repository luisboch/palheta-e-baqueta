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
