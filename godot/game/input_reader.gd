## Lê a entrada de um jogador: quais trastes e pads estão apertados (direto do dispositivo, a cada
## quadro) e quais um evento acabou de apertar (para o toque que cabe entre dois quadros).
##
## Lê o teclado e o controle direto (e não o estado das ações do InputMap), com o dispositivo de
## cada ligação: o controle 2 não toca no jogador 1 (o InputMap ignora o device dos botões).
## Quem junta as duas fontes e compara com o quadro anterior é o FretPad.
class_name InputReader
extends RefCounted

var _axes := {}  ## "device:eixo" → último valor visto, para o gatilho contar só na descida


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


## Lanes (trastes; na bateria, peças) do jogador que este evento acabou de apertar.
func pressed_by(event: InputEvent, player_index: int, drums: bool) -> PackedInt32Array:
	var before := 0.0
	if event is InputEventJoypadMotion:
		var key := "%d:%d" % [event.device, event.axis]
		before = _axes.get(key, 0.0)
		_axes[key] = event.axis_value
	var out := PackedInt32Array()
	var frets := InputProfile.player_frets(player_index)
	var pads := InputProfile.player_pads(player_index)
	for lane in frets.size():
		var actions: Array[String] = [frets[lane]]
		if drums:
			actions = [pads[lane], frets[InputProfile.drum_fret(lane)]]
		for action in actions:
			if _action_pressed_by(action, event, before):
				out.append(lane)
				break
	return out


static func _action_pressed_by(action: String, event: InputEvent, before: float) -> bool:
	for binding in InputMap.action_get_events(action):
		if presses(binding, event, before):
			return true
	return false


## O evento aperta esta ligação? `before` = valor anterior do eixo (só para gatilho): conta quando
## ele cruza a metade do curso descendo, não a cada movimento.
static func presses(binding: InputEvent, event: InputEvent, before := 0.0) -> bool:
	if binding is InputEventKey and event is InputEventKey:
		if not event.pressed or event.echo:
			return false
		var key := binding as InputEventKey
		return (
			(key.physical_keycode != KEY_NONE and key.physical_keycode == event.physical_keycode)
			or (key.keycode != KEY_NONE and key.keycode == event.keycode)
		)
	if binding is InputEventJoypadButton and event is InputEventJoypadButton:
		var button := binding as InputEventJoypadButton
		return (
			event.pressed
			and button.button_index == event.button_index
			and (button.device < 0 or button.device == event.device)
		)
	if binding is InputEventJoypadMotion and event is InputEventJoypadMotion:
		var motion := binding as InputEventJoypadMotion
		var direction := signf(motion.axis_value)
		return (
			motion.axis == event.axis
			and (motion.device < 0 or motion.device == event.device)
			and event.axis_value * direction >= InputProfile.TRIGGER_DEADZONE
			and before * direction < InputProfile.TRIGGER_DEADZONE
		)
	return false
