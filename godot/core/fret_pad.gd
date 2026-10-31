## Os botões de um jogador (trastes ou pads): o que está apertado e o que mudou a cada quadro.
##
## O que está apertado vem da leitura direta do dispositivo a cada quadro (`down`): um "soltou"
## que se perde no caminho não existe, o botão não fica preso. Os apertos vêm de duas fontes: o
## que desceu desde o quadro anterior e os eventos de aperto do quadro (`tapped`). Os eventos
## pegam o toque que começa e acaba entre dois quadros (a 30 fps, um toque rápido cabe em 33 ms)
## e o "soltou e apertou de novo" no mesmo quadro, que a comparação de estados não vê.
class_name FretPad
extends RefCounted

var held := PackedInt32Array()  ## botões apertados agora, em ordem crescente


## Compara com o quadro anterior. `down` = botões apertados agora; `tapped` = botões com evento
## de aperto neste quadro. Devolve {pressed: os apertados neste quadro (em ordem, sem repetir),
## released: os que subiram}. Um toque que já soltou está em `pressed` e fora de `held`.
func poll(down: PackedInt32Array, tapped := PackedInt32Array()) -> Dictionary:
	var now_down := _sorted(down)
	var pressed := PackedInt32Array()
	var released := PackedInt32Array()
	for lane in now_down:
		if lane not in held:
			pressed.append(lane)
	for lane in tapped:
		if lane not in pressed:
			pressed.append(lane)
	pressed.sort()
	for lane in held:
		if lane not in now_down:
			released.append(lane)
	held = now_down
	return {"pressed": pressed, "released": released}


## Assume `down` como o estado atual sem contar nada como aperto: ao voltar da pausa, o botão
## que ficou apertado não vira uma batida nova.
func reset(down := PackedInt32Array()) -> void:
	held = _sorted(down)


static func _sorted(lanes: PackedInt32Array) -> PackedInt32Array:
	var out := lanes.duplicate()
	out.sort()
	return out
