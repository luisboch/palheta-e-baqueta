## Lê do dispositivo, a cada quadro, quais trastes e pads de um jogador estão apertados.
##
## Lê o teclado e o controle direto (e não os eventos nem o estado das ações do InputMap), com o
## dispositivo de cada ligação: o controle 2 não toca no jogador 1. Quem compara com o quadro
## anterior é o FretPad.
class_name InputReader
extends RefCounted


## Trastes apertados (0-4) do jogador; na bateria, as peças (0-4) apertadas.
static func lanes_down(player_index: int, drums: bool) -> PackedInt32Array:
	var out := PackedInt32Array()
	var frets := InputProfile.player_frets(player_index)
	var pads := InputProfile.player_pads(player_index)
	for lane in frets.size():
		if drums:
			# Os botões das Cordas também tocam a bateria: os 4 pads, na ordem da pista, em
			# L2 L1 R1 R2 e o bumbo no último (X).
			if action_down(pads[lane]) or action_down(frets[InputProfile.drum_fret(lane)]):
				out.append(lane)
		elif action_down(frets[lane]):
			out.append(lane)
	return out


## A ação está apertada agora? Confere cada tecla, botão e gatilho dela direto no dispositivo.
static func action_down(action: String) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key := event as InputEventKey
			if (
				Input.is_physical_key_pressed(key.physical_keycode)
				or Input.is_key_pressed(key.keycode)
			):
				return true
		elif event is InputEventJoypadButton:
			var button := event as InputEventJoypadButton
			if Input.is_joy_button_pressed(button.device, button.button_index):
				return true
		elif event is InputEventJoypadMotion:
			var motion := event as InputEventJoypadMotion
			var value := Input.get_joy_axis(motion.device, motion.axis) * signf(motion.axis_value)
			if value >= InputProfile.TRIGGER_DEADZONE:
				return true
	return false
