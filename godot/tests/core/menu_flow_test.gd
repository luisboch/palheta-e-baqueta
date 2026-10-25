extends GdUnitTestSuite


func test_one_player_skips_the_mode() -> void:
	var flow := MenuFlow.new()
	assert_str(flow.start(1)).is_equal(MenuFlow.SONGS)
	assert_str(flow.mode).is_equal("solo")
	assert_str(flow.next(MenuFlow.SONGS)).is_equal(MenuFlow.INSTRUMENTS)
	assert_str(flow.next(MenuFlow.INSTRUMENTS)).is_equal(MenuFlow.PLAY)
	assert_str(flow.back(MenuFlow.SONGS)).is_equal(MenuFlow.MAIN)
	assert_str(flow.back(MenuFlow.INSTRUMENTS)).is_equal(MenuFlow.SONGS)
	assert_str(flow.back(MenuFlow.PLAY)).is_equal(MenuFlow.SONGS)
	assert_str(flow.back(MenuFlow.MANAGE)).is_equal(MenuFlow.MAIN)
	assert_str(flow.next(MenuFlow.MANAGE)).is_equal(MenuFlow.MAIN)


func test_two_players_choose_and_remember_the_mode() -> void:
	var flow := MenuFlow.new()
	assert_str(flow.start(2)).is_equal(MenuFlow.MODE)
	assert_str(flow.mode).is_equal("coop")  # a Banda é o padrão
	assert_str(flow.choose_mode("versus")).is_equal(MenuFlow.SONGS)
	assert_str(flow.mode).is_equal("versus")
	assert_str(flow.back(MenuFlow.SONGS)).is_equal(MenuFlow.MODE)
	assert_str(flow.back(MenuFlow.MODE)).is_equal(MenuFlow.MAIN)
	flow.start(1)
	assert_str(flow.mode).is_equal("solo")
	flow.start(2)
	assert_str(flow.mode).is_equal("versus")  # lembrado
	flow.choose_mode("qualquer")  # desconhecido: fica o lembrado
	assert_str(flow.mode).is_equal("versus")
	assert_str(flow.start(5)).is_equal(MenuFlow.MODE)  # mais de 2: 2
	assert_int(flow.players).is_equal(2)
