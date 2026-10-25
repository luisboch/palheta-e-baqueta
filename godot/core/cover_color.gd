## Cor de destaque de uma capa, para as luzes do palco (ADR 0022): a cor viva que mais aparece.
## Cinzas, pretos e brancos não contam: uma capa em preto e branco dá a cor padrão.
class_name CoverColor
extends RefCounted

const SAMPLE := 24  ## px de lado: a capa é reduzida antes de contar
const HUE_BINS := 12  ## faixas de matiz (de 30° cada)
const MIN_SATURATION := 0.25  ## abaixo disso é cinza
const MIN_VALUE := 0.2  ## abaixo disso é preto
## A luz sai sempre forte, mesmo de uma capa apagada.
const LIGHT_SATURATION := 0.65
const LIGHT_VALUE := 0.9
const FALLBACK := Color("7b2cbf")  ## o roxo do palco sem capa


static func dominant(image: Image) -> Color:
	if image == null or image.is_empty():
		return FALLBACK
	var small: Image = image.duplicate()
	if small.is_compressed():
		small.decompress()
	small.resize(SAMPLE, SAMPLE, Image.INTERPOLATE_BILINEAR)
	var weights: Array[float] = []
	var sums: Array[Color] = []
	weights.resize(HUE_BINS)
	weights.fill(0.0)
	sums.resize(HUE_BINS)
	sums.fill(Color(0, 0, 0, 0))
	for y in SAMPLE:
		for x in SAMPLE:
			var c := small.get_pixel(x, y)
			if c.s < MIN_SATURATION or c.v < MIN_VALUE:
				continue
			var hue_bin := int(c.h * HUE_BINS) % HUE_BINS
			var weight := c.s * c.v  # cor viva e clara pesa mais
			weights[hue_bin] += weight
			sums[hue_bin] += c * weight
	var best := 0
	for i in HUE_BINS:
		if weights[i] > weights[best]:
			best = i
	if weights[best] <= 0.0:
		return FALLBACK
	var mean := sums[best] / weights[best]
	return Color.from_hsv(mean.h, maxf(mean.s, LIGHT_SATURATION), maxf(mean.v, LIGHT_VALUE))
