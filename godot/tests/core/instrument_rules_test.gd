extends GdUnitTestSuite


func test_only_present_instruments_with_notes() -> void:
	var song := {"instruments": {"drums": true, "bass": false, "strings": true}}
	var chart := {
		"tracks":
		{
			"ExpertSingle": [[0, 1, 0]],
			"EasySingle": [[0, 1, 0]],
			"HardSingle": [],
			"ExpertDoubleBass": [[0, 1, 0]],
			"ExpertDrums": [[0, 0, 0]],
		}
	}
	var available := InstrumentRules.available(song, chart)
	assert_dict(available).is_equal({"drums": ["Expert"], "strings": ["Easy", "Expert"]})
	assert_bool(InstrumentRules.is_selectable(song, chart, "strings", "Easy")).is_true()
	assert_bool(InstrumentRules.is_selectable(song, chart, "strings", "Hard")).is_false()
	assert_bool(InstrumentRules.is_selectable(song, chart, "bass", "Expert")).is_false()
	assert_dict(InstrumentRules.available({}, chart)).is_empty()
	assert_str(InstrumentRules.track_name("bass", "Medium")).is_equal("MediumDoubleBass")


func test_stem_mix_ducks_on_miss() -> void:
	var mix := StemMix.new()
	mix.on_miss()
	mix.update(0.1)
	assert_float(mix.volume_db).is_equal_approx(-6.0, 1e-6)
	mix.update(1.0)
	assert_float(mix.volume_db).is_equal(StemMix.MISSED_DB)
	mix.on_hit()
	assert_float(mix.update(1.0)).is_equal(StemMix.NORMAL_DB)
