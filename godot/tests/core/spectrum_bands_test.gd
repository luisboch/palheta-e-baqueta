extends GdUnitTestSuite


func test_spectrum_bands_follow_the_recent_peak() -> void:
	assert_float(SpectrumBands.normalize(0.0, -40.0)).is_equal(0.0)
	assert_float(SpectrumBands.normalize(db_to_linear(-40.0), -40.0)).is_equal_approx(1.0, 0.001)
	assert_float(SpectrumBands.normalize(db_to_linear(-55.0), -40.0)).is_equal_approx(0.5, 0.001)
	var bands := SpectrumBands.new()
	var loud := PackedFloat32Array([db_to_linear(-30.0), db_to_linear(-90.0)])  # 3ª faixa: nada
	bands.update(loud, 0.1)
	assert_float(bands.levels[0]).is_greater(0.9)  # sobe rápido até o próprio pico
	assert_float(bands.peaks_db[0]).is_equal_approx(-30.0, 0.01)
	assert_float(bands.levels[1]).is_equal_approx(0.0, 0.001)  # abaixo do pico mínimo: silêncio
	assert_float(bands.levels[2]).is_equal(0.0)
	bands.update(PackedFloat32Array(), 0.1)
	assert_float(bands.levels[0]).is_between(0.5, 0.9)  # desce devagar
	assert_float(bands.peaks_db[0]).is_equal_approx(-30.3, 0.01)
