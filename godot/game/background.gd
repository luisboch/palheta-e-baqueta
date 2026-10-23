## Fundo animado da partida: segue as batidas (BeatGrid) e o som (SpectrumBands).
##
## Fica numa CanvasLayer atrás da pista: o Environment da cena usa o fundo "Canvas".
class_name Background
extends CanvasLayer

## Cores dos compassos: a paleta das lanes, uma por compasso, em sequência.
const BAR_COLORS := Highway.COLORS

@onready var _sky: ColorRect = $Sky


func update(now: float, grid: BeatGrid, levels: PackedFloat32Array) -> void:
	var mat: ShaderMaterial = _sky.material
	var bar := maxi(grid.bar_at(now), 0)
	var n := BAR_COLORS.size()
	mat.set_shader_parameter("phase", grid.phase(now))
	mat.set_shader_parameter("pulse", grid.pulse(now))
	mat.set_shader_parameter("low", levels[0])
	mat.set_shader_parameter("mid", levels[1])
	mat.set_shader_parameter("high", levels[2])
	# A cor muda a cada compasso, passando da anterior para a nova no começo dele.
	mat.set_shader_parameter("color_a", BAR_COLORS[(bar + n - 1) % n])
	mat.set_shader_parameter("color_b", BAR_COLORS[bar % n])
	mat.set_shader_parameter("bar_mix", maxf(grid.bar_phase(now), 0.0))
	var size := _sky.get_viewport_rect().size
	mat.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
