## Efeitos sonoros do jogo: erro evidente e nota escapando (miss).
##
## Toca no barramento SFX (direcionado ao Master), separado de Music para não
## interferir no analisador de espectro do fundo animado.
class_name SoundEffects
extends Node

const SFX_BUS := "SFX"
const ERROR_STREAM: AudioStream = preload("res://game/sfx/error.wav")
const MISS_STREAM: AudioStream = preload("res://game/sfx/miss.wav")

var _error_player: AudioStreamPlayer
var _miss_player: AudioStreamPlayer


func _ready() -> void:
	var bus_name := SFX_BUS if AudioServer.get_bus_index(SFX_BUS) >= 0 else "Master"
	_error_player = AudioStreamPlayer.new()
	_error_player.stream = ERROR_STREAM
	_error_player.bus = bus_name
	add_child(_error_player)

	_miss_player = AudioStreamPlayer.new()
	_miss_player.stream = MISS_STREAM
	_miss_player.bus = bus_name
	add_child(_miss_player)


func play_error() -> void:
	if _error_player:
		_error_player.play()


func play_miss() -> void:
	if _miss_player:
		_miss_player.play()
