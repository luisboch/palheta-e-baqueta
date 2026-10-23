extends GdUnitTestSuite


func _scoring(hits: int, misses := 0, grade := "perfect") -> Scoring:
	var s := Scoring.new()
	for i in hits:
		s.on_hit(grade)
	for i in misses:
		s.on_miss()
	return s


func test_band_score_and_multiplier() -> void:
	var p1 := _scoring(30)  # 4×
	var p2 := _scoring(5)  # 1×
	assert_int(MatchResult.band_score(p1, p2)).is_equal(p1.score + p2.score)
	assert_int(MatchResult.band_multiplier(p1, p2)).is_equal(2)
	assert_int(MatchResult.band_multiplier(_scoring(40), _scoring(40))).is_equal(4)
	assert_int(MatchResult.band_multiplier(Scoring.new(), Scoring.new())).is_equal(1)


func test_band_accuracy() -> void:
	assert_float(MatchResult.band_accuracy(_scoring(3, 1), _scoring(1, 3))).is_equal(0.5)
	assert_float(MatchResult.band_accuracy(Scoring.new(), Scoring.new())).is_equal(1.0)


func test_stars_by_accuracy() -> void:
	assert_int(MatchResult.stars(0.0)).is_equal(1)
	assert_int(MatchResult.stars(0.649)).is_equal(1)
	assert_int(MatchResult.stars(0.65)).is_equal(2)
	assert_int(MatchResult.stars(0.78)).is_equal(3)
	assert_int(MatchResult.stars(0.88)).is_equal(4)
	assert_int(MatchResult.stars(0.95)).is_equal(5)
	assert_int(MatchResult.stars(1.0)).is_equal(MatchResult.MAX_STARS)


func test_contributions() -> void:
	var c := MatchResult.contributions(_scoring(3), _scoring(1))
	assert_float(c[0]).is_equal(0.75)
	assert_float(c[1]).is_equal(0.25)
	assert_array(MatchResult.contributions(Scoring.new(), Scoring.new())).is_equal([0.5, 0.5])


func test_leader_and_winner_by_score() -> void:
	# Menos acertos, mas melhores: quem vale é o ponto.
	var p1 := _scoring(2, 0, "perfect")  # 200
	var p2 := _scoring(3, 0, "ok")  # 150
	assert_int(MatchResult.leader(p1, p2)).is_equal(1)
	assert_int(MatchResult.winner(p2, p1)).is_equal(2)
	assert_int(MatchResult.winner(_scoring(2), _scoring(2))).is_equal(MatchResult.TIE)
