## Onde a música está agora (s), para desenhar e julgar as notas.
##
## A posição do player só anda a cada mistura de áudio (~10-20 ms), então soma-se o tempo desde a
## última mistura e desconta-se a latência de saída do driver (recomendação da documentação do
## Godot para sincronia), mais a calibração do jogador (`offset`; positivo = o som chega depois).
## O resultado é suavizado: anda com o relógio do frame e só se corrige aos poucos em direção ao
## áudio, para as notas não tremerem; nunca volta para trás (nem em salto).
class_name SongClock
extends RefCounted

## Diferença acima disso é salto de verdade (seek, pausa): pula direto, sem suavizar.
const RESYNC := 0.1
## Fração da diferença corrigida por frame: some em ~20 frames sem tranco visível.
const SMOOTHING := 0.1

var offset := 0.0
var _time := 0.0
var _started := false


func reset() -> void:
	_started = false
	_time = 0.0


func audio_time(playback_position: float, since_mix: float, output_latency: float) -> float:
	return playback_position + since_mix - output_latency - offset


## Chamar a cada frame; `delta` é o tempo do frame (s).
func update(
	playback_position: float, since_mix: float, output_latency: float, delta: float
) -> float:
	var target := audio_time(playback_position, since_mix, output_latency)
	if not _started:
		_started = true
		_time = target
		return _time
	var predicted := _time + delta
	var drift := target - predicted
	if absf(drift) > RESYNC:
		# Só pula para a frente: no fim do stream o player pode informar posição 0 por um quadro,
		# e voltar ao começo faria a música nunca terminar.
		_time = maxf(_time, target)
	else:
		_time = maxf(_time, predicted + drift * SMOOTHING)
	return _time


## Anda só com o relógio do frame, sem consultar o áudio. Serve quando o áudio acabou antes do
## fim do chart: o player parado informa posição 0, o que faria o relógio pular para o começo.
func advance(delta: float) -> float:
	_time += delta
	return _time


func now() -> float:
	return _time
