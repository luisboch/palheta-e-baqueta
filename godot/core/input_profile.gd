## Ações do jogo e as teclas/botões padrão. A tela de mapeamento (fase 8) parte daqui.
##
## Cordas/baixo: 5 trastes + palhetada (para cima ou para baixo). Bateria: 4 pads + bumbo.
## No controle (layout Xbox do Steam Input): trastes nos botões A B Y X LB e palhetada no
## direcional; bateria com pads em B Y X A e bumbo no LB.
class_name InputProfile
extends RefCounted

const FRETS := ["fret_0", "fret_1", "fret_2", "fret_3", "fret_4"]
const STRUM := ["strum_up", "strum_down"]
## Pads da bateria por lane (0 = bumbo).
const PADS := ["kick", "pad_red", "pad_yellow", "pad_blue", "pad_green"]
const PAUSE := "pause"

## ação → [["key", keycode] | ["joy", botão]]
const DEFAULTS := {
	"fret_0": [["key", KEY_1], ["key", KEY_A], ["joy", JOY_BUTTON_A]],
	"fret_1": [["key", KEY_2], ["key", KEY_S], ["joy", JOY_BUTTON_B]],
	"fret_2": [["key", KEY_3], ["key", KEY_D], ["joy", JOY_BUTTON_Y]],
	"fret_3": [["key", KEY_4], ["key", KEY_F], ["joy", JOY_BUTTON_X]],
	"fret_4": [["key", KEY_5], ["key", KEY_G], ["joy", JOY_BUTTON_LEFT_SHOULDER]],
	"strum_up": [["key", KEY_UP], ["joy", JOY_BUTTON_DPAD_UP]],
	"strum_down": [["key", KEY_DOWN], ["key", KEY_ENTER], ["joy", JOY_BUTTON_DPAD_DOWN]],
	"kick": [["key", KEY_SPACE], ["joy", JOY_BUTTON_LEFT_SHOULDER]],
	"pad_red": [["key", KEY_H], ["joy", JOY_BUTTON_B]],
	"pad_yellow": [["key", KEY_J], ["joy", JOY_BUTTON_Y]],
	"pad_blue": [["key", KEY_K], ["joy", JOY_BUTTON_X]],
	"pad_green": [["key", KEY_L], ["joy", JOY_BUTTON_A]],
	"pause": [["key", KEY_ESCAPE], ["joy", JOY_BUTTON_START]],
}


## Cria as ações no InputMap (sem apagar as que já existem com outros eventos).
static func apply(bindings: Dictionary = DEFAULTS) -> void:
	for action: String in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for binding: Array in bindings[action]:
			InputMap.action_add_event(action, event_for(binding))


static func event_for(binding: Array) -> InputEvent:
	if binding[0] == "key":
		var key := InputEventKey.new()
		key.physical_keycode = binding[1]
		return key
	var button := InputEventJoypadButton.new()
	button.button_index = binding[1]
	return button
