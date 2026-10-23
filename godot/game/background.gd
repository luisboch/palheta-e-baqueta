## Fundo animado da partida: segue as batidas (BeatGrid) e o som (SpectrumBands).
##
## Fica numa CanvasLayer atrás da pista: o Environment da cena usa o fundo "Canvas".
class_name Background
extends CanvasLayer

## Cores dos compassos: a paleta das lanes, uma por compasso, em sequência.
const BAR_COLORS := Highway.COLORS

## Menus: um ritmo calmo de mentira (sem música tocando), com o som "médio".
const IDLE_BPM := 90.0
const IDLE_LEVEL := 0.35

var _idle_grid: BeatGrid
var _idle_time := 0.0

@onready var _sky: ColorRect = $Sky


## Para as telas de menu: chame a cada quadro.
func update_idle(delta: float) -> void:
	if _idle_grid == null:
		_idle_grid = BeatGrid.from_tempo(TempoMap.new([[0, int(IDLE_BPM * 1000)]]), 3600.0)
	_idle_time += delta
	update(_idle_time, _idle_grid, PackedFloat32Array([IDLE_LEVEL, IDLE_LEVEL, IDLE_LEVEL]))


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
