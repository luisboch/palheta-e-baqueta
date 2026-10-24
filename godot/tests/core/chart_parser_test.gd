extends GdUnitTestSuite

const SAMPLE := "res://tests/fixtures/pipeline_sample.chart"


func _sample() -> Dictionary:
	return ChartParser.parse(FileAccess.get_file_as_string(SAMPLE))


func test_parses_chart_written_by_the_pipeline() -> void:
	var chart := _sample()
	assert_str(chart["name"]).is_equal("Exemplo do pipeline")
	assert_int(chart["resolution"]).is_equal(192)
	assert_array(chart["tempos"]).is_equal([[0, 120000], [1728, 150000]])
	assert_array(chart["time_signatures"]).is_equal([[0, 1], [192, 4]])
	assert_str(chart["streams"]["GuitarStream"]).is_equal("guitar.ogg")
	for difficulty: String in InstrumentRules.DIFFICULTIES:
		assert_bool(chart["tracks"].has(difficulty + "Single")).is_true()
		assert_bool(chart["tracks"].has(difficulty + "Drums")).is_true()
	# Fácil: um ataque por batida (ADR 0020), a nota longa no fim continua sustentada.
	var easy := [[192, 0, 0], [384, 1, 0], [576, 2, 0], [768, 2, 0], [960, 2, 0], [1152, 2, 0]]
	easy.append([1344, 1, 480])
	assert_array(chart["tracks"]["EasySingle"]).is_equal(easy)


func test_tolerates_other_charts() -> void:
	var text := (
		"﻿[Song]\r\n{\r\n  Resolution = 480\r\n}\r\n[SyncTrack]\r\n{\r\n  0 = A 5\r\n  x = B 1\r\n}\r\n"
		+ '[Events]\r\n{\r\n  0 = E "section Intro"\r\n}\r\n[ExpertSingle]\r\n{\r\n'
		+ "  960 = N 2 0\r\n  480 = N 1\r\n  480 = S 2 100\r\n  480 = N\r\n}\r\n"
	)
	var chart := ChartParser.parse(text)
	assert_int(chart["resolution"]).is_equal(480)
	assert_array(chart["tempos"]).is_empty()
	assert_array(chart["tracks"]["ExpertSingle"]).is_equal([[480, 1, 0], [960, 2, 0]])
	assert_bool(chart["tracks"].has("Events")).is_false()
	assert_str(ChartParser.parse("")["name"]).is_equal("")
