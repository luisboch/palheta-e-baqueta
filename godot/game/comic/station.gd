## Um ponto do cenário dos menus (ADR 0022): onde a câmera para quando a tela abre e as cores do
## céu de quadrinho. A câmera fica no filho "Eye" olhando para o filho "Target": arraste os dois
## no editor para enquadrar.
class_name Station
extends Node3D

@export var sky_a := Comic.YELLOW
@export var sky_b := Comic.ORANGE
@export var sky_dots := Comic.RED


## Onde a câmera fica (posição e direção) quando esta tela está aberta.
func view() -> Transform3D:
	var eye: Node3D = $Eye
	var target: Node3D = $Target
	return Transform3D(Basis(), eye.global_position).looking_at(target.global_position)
