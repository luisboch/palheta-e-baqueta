extends GdUnitTestSuite


func test_sound_effects_initialization_and_playback() -> void:
	var sfx := SoundEffects.new()
	add_child(sfx)
	auto_free(sfx)

	assert_that(sfx._error_player).is_not_null()
	assert_that(sfx._miss_player).is_not_null()
	assert_that(sfx._error_player.stream).is_not_null()
	assert_that(sfx._miss_player.stream).is_not_null()

	# Executa os métodos sem falhas
	sfx.play_error()
	sfx.play_miss()
