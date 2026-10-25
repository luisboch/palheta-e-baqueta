## Ações do jogo e as teclas/botões padrão para 1 e 2 jogadores.
##
## Suporta 2 jogadores simultâneos:
## - Jogador 1: Teclado (1..5 / A..G / Espaço / H..L) ou Controle 1 (device 0).
## - Jogador 2: Teclado numérico (KP 1..5 / KP 0 / KP 7..+) ou Controle 2 (device 1).
##
## No controle, trastes como no Guitar Hero de joystick: L2 L1 R1 R2 e X (o botão de baixo, A no
## layout Xbox do Steam Input), palhetada no direcional.
## A bateria usa os mesmos botões: os 4 pads, na ordem da pista, em L2 L1 R1 R2 e o bumbo em X
## (ver `drum_fret`).
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
const P1_WHAMMY := "p1_whammy"

## Jogador 2
const P2_FRETS: Array[String] = ["p2_fret_0", "p2_fret_1", "p2_fret_2", "p2_fret_3", "p2_fret_4"]
const P2_STRUM: Array[String] = ["p2_strum_up", "p2_strum_down"]
const P2_PADS: Array[String] = [
	"p2_kick", "p2_pad_red", "p2_pad_yellow", "p2_pad_blue", "p2_pad_green"
]
const P2_PAUSE := "p2_pause"
const P2_WHAMMY := "p2_whammy"

## Cordas/baixo sem palhetada: a nota toca ao apertar o traste (ADR 0015). Teclado e controle
## comum; a guitarra USB (fase 8) desliga, porque lá a palhetada é o gesto do instrumento.
const FRET_TAPS := true

## Quanto o gatilho analógico (L2/R2) precisa descer para contar como traste apertado. Metade do
## curso: não dispara com o dedo só encostado e não exige apertar até o fim.
const TRIGGER_DEADZONE := 0.5

## ação → [["key", keycode] | ["joy", botão, device] | ["axis", eixo, device, sentido]]
## O sentido do eixo é opcional (1.0): -1.0 para esquerda e para cima no analógico.
## L2/R2 são eixos no Godot, não botões: um gatilho manda um evento a cada mudança de posição.
const DEFAULTS := {
	# Menus: o Godot 4 só liga ui_accept/ui_cancel ao teclado (Enter/Espaço, Esc); sem isto o
	# direcional anda pelos botões mas o A não aperta nada. Device -1: qualquer controle.
	"ui_accept": [["joy", JOY_BUTTON_A, -1]],
	"ui_cancel": [["joy", JOY_BUTTON_B, -1]],
	# Ações gerais / P1
	"fret_0": [["key", KEY_1], ["key", KEY_A], ["axis", JOY_AXIS_TRIGGER_LEFT, 0]],
	"fret_1": [["key", KEY_2], ["key", KEY_S], ["joy", JOY_BUTTON_LEFT_SHOULDER, 0]],
	"fret_2": [["key", KEY_3], ["key", KEY_D], ["joy", JOY_BUTTON_RIGHT_SHOULDER, 0]],
	"fret_3": [["key", KEY_4], ["key", KEY_F], ["axis", JOY_AXIS_TRIGGER_RIGHT, 0]],
	"fret_4": [["key", KEY_5], ["key", KEY_G], ["joy", JOY_BUTTON_A, 0]],
	"strum_up": [["key", KEY_UP], ["joy", JOY_BUTTON_DPAD_UP, 0]],
	"strum_down": [["key", KEY_DOWN], ["key", KEY_ENTER], ["joy", JOY_BUTTON_DPAD_DOWN, 0]],
	"kick": [["key", KEY_SPACE]],
	"pad_red": [["key", KEY_H]],
	"pad_yellow": [["key", KEY_J]],
	"pad_blue": [["key", KEY_K]],
	"pad_green": [["key", KEY_L]],
	"pause": [["key", KEY_ESCAPE], ["joy", JOY_BUTTON_START, -1]],
	# Jogador 1 (específico)
	"p1_fret_0": [["key", KEY_1], ["key", KEY_A], ["axis", JOY_AXIS_TRIGGER_LEFT, 0]],
	"p1_fret_1": [["key", KEY_2], ["key", KEY_S], ["joy", JOY_BUTTON_LEFT_SHOULDER, 0]],
	"p1_fret_2": [["key", KEY_3], ["key", KEY_D], ["joy", JOY_BUTTON_RIGHT_SHOULDER, 0]],
	"p1_fret_3": [["key", KEY_4], ["key", KEY_F], ["axis", JOY_AXIS_TRIGGER_RIGHT, 0]],
	"p1_fret_4": [["key", KEY_5], ["key", KEY_G], ["joy", JOY_BUTTON_A, 0]],
	"p1_strum_up": [["key", KEY_UP], ["joy", JOY_BUTTON_DPAD_UP, 0]],
	"p1_strum_down": [["key", KEY_DOWN], ["key", KEY_ENTER], ["joy", JOY_BUTTON_DPAD_DOWN, 0]],
	"p1_kick": [["key", KEY_SPACE]],
	"p1_pad_red": [["key", KEY_H]],
	"p1_pad_yellow": [["key", KEY_J]],
	"p1_pad_blue": [["key", KEY_K]],
	"p1_pad_green": [["key", KEY_L]],
	"p1_pause": [["key", KEY_ESCAPE], ["joy", JOY_BUTTON_START, 0]],
	# Whammy: no controle são os analógicos (lidos direto, ver Whammy); no teclado, uma tecla.
	"p1_whammy": [["key", KEY_SHIFT]],
	# Jogador 2 (específico: Device 1 ou teclado numérico)
	"p2_fret_0": [["key", KEY_KP_1], ["axis", JOY_AXIS_TRIGGER_LEFT, 1]],
	"p2_fret_1": [["key", KEY_KP_2], ["joy", JOY_BUTTON_LEFT_SHOULDER, 1]],
	"p2_fret_2": [["key", KEY_KP_3], ["joy", JOY_BUTTON_RIGHT_SHOULDER, 1]],
	"p2_fret_3": [["key", KEY_KP_4], ["axis", JOY_AXIS_TRIGGER_RIGHT, 1]],
	"p2_fret_4": [["key", KEY_KP_5], ["joy", JOY_BUTTON_A, 1]],
	"p2_strum_up": [["key", KEY_KP_8], ["joy", JOY_BUTTON_DPAD_UP, 1]],
	"p2_strum_down": [["key", KEY_KP_2], ["key", KEY_KP_ENTER], ["joy", JOY_BUTTON_DPAD_DOWN, 1]],
	"p2_kick": [["key", KEY_KP_0]],
	"p2_pad_red": [["key", KEY_KP_7]],
	"p2_pad_yellow": [["key", KEY_KP_8]],
	"p2_pad_blue": [["key", KEY_KP_9]],
	"p2_pad_green": [["key", KEY_KP_ADD]],
	"p2_pause": [["key", KEY_PAUSE], ["joy", JOY_BUTTON_START, 1]],
	"p2_whammy": [["key", KEY_KP_6]],
	# Menus por jogador: na escolha de instrumento cada um anda com o próprio cursor (ADR 0022).
	# P1 nas setas e no controle 1; P2 no teclado numérico e no controle 2. Analógico também.
	"p1_menu_left":
	[["key", KEY_LEFT], ["joy", JOY_BUTTON_DPAD_LEFT, 0], ["axis", JOY_AXIS_LEFT_X, 0, -1.0]],
	"p1_menu_right":
	[["key", KEY_RIGHT], ["joy", JOY_BUTTON_DPAD_RIGHT, 0], ["axis", JOY_AXIS_LEFT_X, 0]],
	"p1_menu_up":
	[["key", KEY_UP], ["joy", JOY_BUTTON_DPAD_UP, 0], ["axis", JOY_AXIS_LEFT_Y, 0, -1.0]],
	"p1_menu_down":
	[["key", KEY_DOWN], ["joy", JOY_BUTTON_DPAD_DOWN, 0], ["axis", JOY_AXIS_LEFT_Y, 0]],
	"p1_menu_accept": [["key", KEY_ENTER], ["key", KEY_SPACE], ["joy", JOY_BUTTON_A, 0]],
	"p1_menu_back": [["key", KEY_ESCAPE], ["key", KEY_BACKSPACE], ["joy", JOY_BUTTON_B, 0]],
	"p2_menu_left":
	[["key", KEY_KP_4], ["joy", JOY_BUTTON_DPAD_LEFT, 1], ["axis", JOY_AXIS_LEFT_X, 1, -1.0]],
	"p2_menu_right":
	[["key", KEY_KP_6], ["joy", JOY_BUTTON_DPAD_RIGHT, 1], ["axis", JOY_AXIS_LEFT_X, 1]],
	"p2_menu_up":
	[["key", KEY_KP_8], ["joy", JOY_BUTTON_DPAD_UP, 1], ["axis", JOY_AXIS_LEFT_Y, 1, -1.0]],
	"p2_menu_down":
	[["key", KEY_KP_5], ["joy", JOY_BUTTON_DPAD_DOWN, 1], ["axis", JOY_AXIS_LEFT_Y, 1]],
	"p2_menu_accept": [["key", KEY_KP_ENTER], ["joy", JOY_BUTTON_A, 1]],
	"p2_menu_back": [["key", KEY_KP_PERIOD], ["joy", JOY_BUTTON_B, 1]],
}


## Traste (botão) que toca a lane da bateria: o bumbo (0) no último, os pads 1-4 nos trastes 0-3.
static func drum_fret(lane: int) -> int:
	return FRETS.size() - 1 if lane == 0 else lane - 1


static func player_frets(player_index: int) -> Array[String]:
	return P1_FRETS if player_index == 0 else P2_FRETS


static func player_strum(player_index: int) -> Array[String]:
	return P1_STRUM if player_index == 0 else P2_STRUM


static func player_pads(player_index: int) -> Array[String]:
	return P1_PADS if player_index == 0 else P2_PADS


static func player_pause(player_index: int) -> String:
	return P1_PAUSE if player_index == 0 else P2_PAUSE


static func player_whammy(player_index: int) -> String:
	return P1_WHAMMY if player_index == 0 else P2_WHAMMY


## Ação de menu do jogador (0 ou 1): "left", "right", "up", "down", "accept" ou "back".
static func menu_action(player_index: int, what: String) -> String:
	return "p%d_menu_%s" % [player_index + 1, what]


## Cria as ações no InputMap (sem apagar as que já existem com outros eventos nem repetir).
static func apply(bindings: Dictionary = DEFAULTS) -> void:
	for action: String in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action, TRIGGER_DEADZONE)
		for binding: Array in bindings[action]:
			var event := event_for(binding)
			if not InputMap.action_has_event(action, event):  # cada partida chama de novo
				InputMap.action_add_event(action, event)


static func event_for(binding: Array) -> InputEvent:
	if binding[0] == "key":
		var key := InputEventKey.new()
		key.physical_keycode = binding[1]
		return key
	if binding[0] == "axis":
		var trigger := InputEventJoypadMotion.new()
		trigger.axis = binding[1]
		trigger.axis_value = binding[3] if binding.size() > 3 else 1.0
		trigger.device = binding[2] if binding.size() > 2 else 0
		return trigger
	var button := InputEventJoypadButton.new()
	button.button_index = binding[1]
	button.device = binding[2] if binding.size() > 2 else 0
	return button
