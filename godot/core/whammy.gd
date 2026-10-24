## Quanto o jogador está "mexendo na alavanca" (0-1): os analógicos do controle ou uma tecla.
##
## Qualquer um dos dois analógicos serve: no Steam Deck o polegar direito também toca o X, e o
## esquerdo fica livre quando a nota toca no traste (ADR 0015). A tecla vale o curso inteiro.
## Suavizado para a cauda e o som não tremerem com o ruído do analógico (ADR 0021).
class_name Whammy
extends RefCounted

const DEADZONE := 0.2  ## analógico parado não é exatamente 0; abaixo disso, nada
const SPEED := 20.0  ## curso por segundo: acompanha o vaivém da alavanca (~5 Hz) sem saltos
const BEND_SEMITONES := 2.0  ## no máximo, o instrumento desce um tom, como uma alavanca de verdade

var amount := 0.0
var _target := 0.0


## Deflexão de um analógico (0-1), com a zona morta descontada.
static func stick(direction: Vector2) -> float:
	return clampf((direction.length() - DEADZONE) / (1.0 - DEADZONE), 0.0, 1.0)


## `sticks`: a posição de cada analógico; `key`: a tecla do whammy apertada.
func update(sticks: Array[Vector2], key: bool, delta: float) -> float:
	_target = 1.0 if key else 0.0
	for direction in sticks:
		_target = maxf(_target, stick(direction))
	amount = move_toward(amount, _target, SPEED * delta)
	return amount


## Escala de altura do som para o whammy `value` (1 = sem mudar).
static func pitch_scale(value: float) -> float:
	return pow(2.0, -BEND_SEMITONES * clampf(value, 0.0, 1.0) / 12.0)
