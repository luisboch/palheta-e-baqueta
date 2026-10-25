extends GdUnitTestSuite

## Cordas com 3 níveis, sem baixo, bateria só no Muito difícil.
const AVAILABLE := {"drums": ["Expert"], "strings": ["Easy", "Hard", "Expert"]}


func test_starts_from_the_request_or_the_default() -> void:
	var pick := PlayerPick.new(AVAILABLE)
	assert_array([pick.instrument, pick.difficulty]).is_equal(["strings", "Hard"])
	pick = PlayerPick.new(AVAILABLE, "drums", "Easy")
	assert_array([pick.instrument, pick.difficulty]).is_equal(["drums", "Expert"])
	pick = PlayerPick.new({})
	assert_bool(pick.playable()).is_false()
	assert_bool(pick.move(1)).is_false()
	assert_bool(pick.toggle_ready()).is_false()


func test_moves_through_what_the_song_has() -> void:
	var pick := PlayerPick.new(AVAILABLE)
	assert_bool(pick.move(1)).is_true()  # pula o baixo, que não toca
	assert_array([pick.instrument, pick.difficulty]).is_equal(["drums", "Expert"])
	assert_bool(pick.move(1)).is_false()  # não dá a volta
	pick.move(-1)
	assert_array([pick.instrument, pick.difficulty]).is_equal(["strings", "Expert"])
	pick.move_row(1)
	assert_int(pick.row).is_equal(PlayerPick.ROW_DIFFICULTY)
	pick.move_row(1)
	assert_int(pick.row).is_equal(PlayerPick.ROW_DIFFICULTY)
	pick.move(-1)
	assert_str(pick.difficulty).is_equal("Hard")
	pick.move(-5)
	assert_str(pick.difficulty).is_equal("Easy")


func test_ready_locks_the_choice() -> void:
	var pick := PlayerPick.new(AVAILABLE)
	assert_bool(pick.toggle_ready()).is_true()
	assert_bool(pick.move(1)).is_false()
	pick.move_row(1)
	assert_int(pick.row).is_equal(PlayerPick.ROW_INSTRUMENT)
	assert_bool(pick.toggle_ready()).is_false()
	pick.toggle_ready()
	pick.pick("drums", "Expert")  # clique desfaz o pronto
	assert_bool(pick.is_ready).is_false()
	assert_str(pick.instrument).is_equal("drums")
