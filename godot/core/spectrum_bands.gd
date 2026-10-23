## Graves, médios e agudos da música, de 0 a 1, para o fundo reagir ao som.
##
## Recebe as magnitudes lineares do AudioEffectSpectrumAnalyzer (uma por faixa) e devolve níveis
## suavizados: sobe rápido (o ataque de um bumbo aparece) e desce devagar (sem cintilar).
## Cada faixa é medida contra o próprio pico recente: medido no Deck, as faixas ficam entre
## -85 e -25 dB e mudam muito de música para música, então uma escala fixa deixava o fundo parado.
class_name SpectrumBands
extends RefCounted

## Faixas em Hz: graves (bumbo, baixo), médios (voz, Cordas), agudos (pratos).
const BANDS := [[20.0, 150.0], [150.0, 2000.0], [2000.0, 12000.0]]
const RANGE_DB := 30.0  ## abaixo do pico recente por mais que isso é 0
const PEAK_FALL_DB := 3.0  ## por segundo: o pico esquece devagar um trecho alto que passou
const MIN_PEAK_DB := -60.0  ## pico mínimo: silêncio não vira "nível máximo"
const ATTACK := 25.0  ## por segundo: quanto da diferença é vencida ao subir
const RELEASE := 4.0  ## por segundo, ao descer

var levels := PackedFloat32Array([0.0, 0.0, 0.0])
var peaks_db := PackedFloat32Array([MIN_PEAK_DB, MIN_PEAK_DB, MIN_PEAK_DB])


## Magnitude linear → 0 a 1: 1 no pico, 0 a RANGE_DB abaixo dele.
static func normalize(magnitude: float, peak_db: float) -> float:
	if magnitude <= 0.0:
		return 0.0
	return clampf((linear_to_db(magnitude) - peak_db + RANGE_DB) / RANGE_DB, 0.0, 1.0)


func update(magnitudes: PackedFloat32Array, delta: float) -> PackedFloat32Array:
	for i in levels.size():
		var magnitude := magnitudes[i] if i < magnitudes.size() else 0.0
		var db := linear_to_db(magnitude) if magnitude > 0.0 else -INF
		peaks_db[i] = maxf(maxf(peaks_db[i] - PEAK_FALL_DB * delta, db), MIN_PEAK_DB)
		var target := normalize(magnitude, peaks_db[i])
		var rate := ATTACK if target > levels[i] else RELEASE
		levels[i] = lerpf(levels[i], target, clampf(rate * delta, 0.0, 1.0))
	return levels
