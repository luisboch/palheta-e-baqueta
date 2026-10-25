## Estação do palco (escolha de música): a capa da música em foco no telão e os refletores na cor
## de destaque dela (CoverColor). O palco é o mesmo que fica atrás da pista na partida.
class_name StageStation
extends Station

@onready var backdrop: StageBackdrop = $Backdrop


## Capa (null: sem capa) e cor das luzes.
func show_cover(texture: Texture2D, color: Color) -> void:
	backdrop.show_cover(texture, color)
