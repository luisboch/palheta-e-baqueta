extends GdUnitTestSuite


## Imagem com `main` em quase tudo e uma faixa de `other` no topo.
func _image(main: Color, other: Color) -> Image:
	var image := Image.create(32, 32, false, Image.FORMAT_RGB8)
	image.fill(main)
	image.fill_rect(Rect2i(0, 0, 32, 6), other)
	return image


func test_picks_the_most_common_vivid_color() -> void:
	var color := CoverColor.dominant(_image(Color(0.8, 0.1, 0.1), Color(0.1, 0.2, 0.9)))
	assert_float(color.h).is_less(0.05)  # vermelho
	assert_float(color.s).is_greater_equal(CoverColor.LIGHT_SATURATION - 0.01)
	assert_float(color.v).is_greater_equal(CoverColor.LIGHT_VALUE - 0.01)


func test_ignores_grays_and_dark() -> void:
	# Quase tudo cinza: a faixa azul é a única cor viva.
	var color := CoverColor.dominant(_image(Color(0.5, 0.5, 0.5), Color(0.1, 0.2, 0.9)))
	assert_float(color.h).is_between(0.55, 0.7)
	var gray := CoverColor.dominant(_image(Color(0.5, 0.5, 0.5), Color(0.05, 0.05, 0.05)))
	assert_object(gray).is_equal(CoverColor.FALLBACK)
	assert_object(CoverColor.dominant(null)).is_equal(CoverColor.FALLBACK)
	assert_object(CoverColor.dominant(Image.new())).is_equal(CoverColor.FALLBACK)
