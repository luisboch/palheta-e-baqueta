## Ações do jogo e as teclas/botões padrão para 1 e 2 jogadores.
##
## Suporta 2 jogadores simultâneos:
## - Jogador 1: Teclado (1..5 / A..G / Espaço / H..L) ou Controle 1 (device 0).
## - Jogador 2: Teclado numérico (KP 1..5 / KP 0 / KP 7..+) ou Controle 2 (device 1).
##
## No controle (layout Xbox do Steam Input): trastes nos botões A B Y X LB e palhetada no
## direcional; bateria com pads em B Y X A e bumbo no LB.
class_name InputProfile
extends RefCounted

## Ações legadas / P1 (compatibilidade)
const FRETS := ["fret_0", "fret_1", "fret_2", "fret_3", "fret_4"]
const STRUM := ["strum_up", "strum_down"]
const PADS := ["kick", "pad_red", "pad_yellow", "pad_blue", "pad_green"]
const PAUSE := "pause"

## Jogador 1
const P1_FRETS: Array[String] = ["p1_fret_0", "p1_fret_1", "p1_fret_2", "p1_fret_3", "p1_fret_4"]
const P1_STRUM: Array[String] = ["p1_strum_up", "p1_strum_down"]
const P1_PADS: Array[String] = [
	"p1_kick", "p1_pad_red", "p1_pad_yellow", "p1_pad_blue", "p1_pad_green"
]
const P1_PAUSE := "p1_pause"

## Jogador 2
const P2_FRETS: Array[String] = ["p2_fret_0", "p2_fret_1", "p2_fret_2", "p2_fret_3", "p2_fret_4"]
const P2_STRUM: Array[String] = ["p2_strum_up", "p2_strum_down"]
const P2_PADS: Array[String] = [
	"p2_kick", "p2_pad_red", "p2_pad_yellow", "p2_pad_blue", "p2_pad_green"
]
const P2_PAUSE := "p2_pause"

## Cordas/baixo sem palhetada: a nota toca ao apertar o traste (ADR 0015). Teclado e controle
## comum; a guitarra USB (fase 8) desliga, porque lá a palhetada é o gesto do instrumento.
const FRET_TAPS := true

## ação → [["key", keycode] | ["joy", botão, device]]
const DEFAULTS := {
	# Ações gerais / P1
	"fret_0": [["key", KEY_1], ["key", KEY_A], ["joy", JOY_BUTTON_A, 0]],
	"fret_1": [["key", KEY_2], ["key", KEY_S], ["joy", JOY_BUTTON_B, 0]],
	"fret_2": [["key", KEY_3], ["key", KEY_D], ["joy", JOY_BUTTON_Y, 0]],
	"fret_3": [["key", KEY_4], ["key", KEY_F], ["joy", JOY_BUTTON_X, 0]],
	"fret_4": [["key", KEY_5], ["key", KEY_G], ["joy", JOY_BUTTON_LEFT_SHOULDER, 0]],
	"strum_up": [["key", KEY_UP], ["joy", JOY_BUTTON_DPAD_UP, 0]],
	"strum_down": [["key", KEY_DOWN], ["key", KEY_ENTER], ["joy", JOY_BUTTON_DPAD_DOWN, 0]],
	"kick": [["key", KEY_SPACE], ["joy", JOY_BUTTON_LEFT_SHOULDER, 0]],
	"pad_red": [["key", KEY_H], ["joy", JOY_BUTTON_B, 0]],
	"pad_yellow": [["key", KEY_J], ["joy", JOY_BUTTON_Y, 0]],
	"pad_blue": [["key", KEY_K], ["joy", JOY_BUTTON_X, 0]],
	"pad_green": [["key", KEY_L], ["joy", JOY_BUTTON_A, 0]],
	"pause": [["key", KEY_ESCAPE], ["joy", JOY_BUTTON_START, -1]],
	# Jogador 1 (específico)
	"p1_fret_0": [["key", KEY_1], ["key", KEY_A], ["joy", JOY_BUTTON_A, 0]],
	"p1_fret_1": [["key", KEY_2], ["key", KEY_S], ["joy", JOY_BUTTON_B, 0]],
	"p1_fret_2": [["key", KEY_3], ["key", KEY_D], ["joy", JOY_BUTTON_Y, 0]],
	"p1_fret_3": [["key", KEY_4], ["key", KEY_F], ["joy", JOY_BUTTON_X, 0]],
	"p1_fret_4": [["key", KEY_5], ["key", KEY_G], ["joy", JOY_BUTTON_LEFT_SHOULDER, 0]],
	"p1_strum_up": [["key", KEY_UP], ["joy", JOY_BUTTON_DPAD_UP, 0]],
	"p1_strum_down": [["key", KEY_DOWN], ["key", KEY_ENTER], ["joy", JOY_BUTTON_DPAD_DOWN, 0]],
	"p1_kick": [["key", KEY_SPACE], ["joy", JOY_BUTTON_LEFT_SHOULDER, 0]],
	"p1_pad_red": [["key", KEY_H], ["joy", JOY_BUTTON_B, 0]],
	"p1_pad_yellow": [["key", KEY_J], ["joy", JOY_BUTTON_Y, 0]],
	"p1_pad_blue": [["key", KEY_K], ["joy", JOY_BUTTON_X, 0]],
	"p1_pad_green": [["key", KEY_L], ["joy", JOY_BUTTON_A, 0]],
	"p1_pause": [["key", KEY_ESCAPE], ["joy", JOY_BUTTON_START, 0]],
	# Jogador 2 (específico: Device 1 ou teclado numérico)
	"p2_fret_0": [["key", KEY_KP_1], ["joy", JOY_BUTTON_A, 1]],
	"p2_fret_1": [["key", KEY_KP_2], ["joy", JOY_BUTTON_B, 1]],
	"p2_fret_2": [["key", KEY_KP_3], ["joy", JOY_BUTTON_Y, 1]],
	"p2_fret_3": [["key", KEY_KP_4], ["joy", JOY_BUTTON_X, 1]],
	"p2_fret_4": [["key", KEY_KP_5], ["joy", JOY_BUTTON_LEFT_SHOULDER, 1]],
	"p2_strum_up": [["key", KEY_KP_8], ["joy", JOY_BUTTON_DPAD_UP, 1]],
	"p2_strum_down": [["key", KEY_KP_2], ["key", KEY_KP_ENTER], ["joy", JOY_BUTTON_DPAD_DOWN, 1]],
	"p2_kick": [["key", KEY_KP_0], ["joy", JOY_BUTTON_LEFT_SHOULDER, 1]],
	"p2_pad_red": [["key", KEY_KP_7], ["joy", JOY_BUTTON_B, 1]],
	"p2_pad_yellow": [["key", KEY_KP_8], ["joy", JOY_BUTTON_Y, 1]],
	"p2_pad_blue": [["key", KEY_KP_9], ["joy", JOY_BUTTON_X, 1]],
	"p2_pad_green": [["key", KEY_KP_ADD], ["joy", JOY_BUTTON_A, 1]],
	"p2_pause": [["key", KEY_PAUSE], ["joy", JOY_BUTTON_START, 1]],
}


static func player_frets(player_index: int) -> Array[String]:
	return P1_FRETS if player_index == 0 else P2_FRETS


static func player_strum(player_index: int) -> Array[String]:
	return P1_STRUM if player_index == 0 else P2_STRUM


static func player_pads(player_index: int) -> Array[String]:
	return P1_PADS if player_index == 0 else P2_PADS


static func player_pause(player_index: int) -> String:
	return P1_PAUSE if player_index == 0 else P2_PAUSE


## Cria as ações no InputMap (sem apagar as que já existem com outros eventos nem repetir).
static func apply(bindings: Dictionary = DEFAULTS) -> void:
	for action: String in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for binding: Array in bindings[action]:
			var event := event_for(binding)
			if not InputMap.action_has_event(action, event):  # cada partida chama de novo
				InputMap.action_add_event(action, event)


static func event_for(binding: Array) -> InputEvent:
	if binding[0] == "key":
		var key := InputEventKey.new()
		key.physical_keycode = binding[1]
		return key
	var button := InputEventJoypadButton.new()
	button.button_index = binding[1]
	button.device = binding[2] if binding.size() > 2 else 0
	return button
