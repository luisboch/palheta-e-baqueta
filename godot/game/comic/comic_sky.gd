## Céu de quadrinho dos menus (comic_sky.gdshader): gira devagar, pulsa num ritmo calmo de
## mentira (como o fundo da partida nos menus antigos) e troca de cores com a tela.
class_name ComicSky
extends CanvasLayer

const SPIN_SPEED := 0.03  ## rad/s dos raios: movimento que se nota, sem distrair
const PALETTE_TIME := 0.6  ## s da troca de cores entre telas

var _grid := BeatGrid.from_tempo(TempoMap.new([[0, int(Background.IDLE_BPM * 1000)]]), 3600.0)
var _time := 0.0
var _colors: Array[Color] = [Comic.YELLOW, Comic.ORANGE, Comic.RED]
var _tween: Tween

@onready var _rect: ColorRect = $Sky


func _ready() -> void:
	_apply(1.0, _colors, _colors)


func _process(delta: float) -> void:
	_time += delta
	var mat: ShaderMaterial = _rect.material
	mat.set_shader_parameter("spin", _time * SPIN_SPEED)
	mat.set_shader_parameter("pulse", _grid.pulse(_time))
	var size := _rect.get_viewport_rect().size
	mat.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))


## Raios (a e b) e retícula; `instant` pula a transição (a primeira tela).
func set_palette(a: Color, b: Color, dots: Color, instant := false) -> void:
	var from := _colors.duplicate()
	var to: Array[Color] = [a, b, dots]
	_colors = to
	if _tween:
		_tween.kill()
	if instant:
		_apply(1.0, from, to)
		return
	_tween = create_tween()
	_tween.tween_method(_apply.bind(from, to), 0.0, 1.0, PALETTE_TIME)


func _apply(t: float, from: Array[Color], to: Array[Color]) -> void:
	var mat: ShaderMaterial = _rect.material
	for i in to.size():
		mat.set_shader_parameter(["color_a", "color_b", "dots"][i], from[i].lerp(to[i], t))
