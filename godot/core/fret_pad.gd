## Os botões de um jogador (trastes ou pads): o que está apertado e o que mudou a cada quadro.
##
## O estado vem de uma fonte só, a leitura direta do dispositivo a cada quadro (`down`), e as
## mudanças saem da comparação com o quadro anterior. Assim um "soltou" que se perde no caminho
## não existe: o botão não fica preso, e o gatilho analógico, que repete "apertado" a cada
## movimento, só conta na descida.
class_name FretPad
extends RefCounted

var held := PackedInt32Array()  ## botões apertados agora, em ordem crescente


## Compara com o quadro anterior. `down` = botões apertados agora.
## Devolve {pressed: os que desceram, released: os que subiram}.
func poll(down: PackedInt32Array) -> Dictionary:
	var now_down := _sorted(down)
	var pressed := PackedInt32Array()
	var released := PackedInt32Array()
	for lane in now_down:
		if lane not in held:
			pressed.append(lane)
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
