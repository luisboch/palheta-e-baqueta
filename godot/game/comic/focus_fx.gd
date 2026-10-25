## Foco de quadrinho, igual em todas as telas: o botão em foco ganha o fundo amarelo do tema e
## solta linhas de ação em volta, uma vez. Com controle o foco é o cursor (ADR 0016): tem de ser
## óbvio, sem piscar sem parar.
class_name FocusFx
extends Control

const BURST_TIME := 0.28  ## s das linhas de ação
const LINES := 16
const LINE_LENGTH := 22.0  ## px de cada linha no começo
const LINE_GAP := 12.0  ## px entre a borda do botão e o começo da linha
const LINE_TRAVEL := 18.0  ## px que as linhas andam para fora
const LINE_WIDTH := 4.0
const FLASH_ALPHA := 0.45  ## clarão branco no botão, sumindo

var _focused: Control
var _age := BURST_TIME


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	get_viewport().gui_focus_changed.connect(_on_focus_changed)


func _process(delta: float) -> void:
	if _age < BURST_TIME:
		_age += delta
		queue_redraw()


func _on_focus_changed(control: Control) -> void:
	if is_instance_valid(_focused) and _focused is Button:
		_focused.remove_theme_stylebox_override("normal")
		_focused.remove_theme_color_override("font_color")
	_focused = control
	if control is Button:
		# Sem mouse, o "hover" do tema nunca aparece: o foco usa o mesmo destaque.
		control.add_theme_stylebox_override("normal", control.get_theme_stylebox("hover"))
		control.add_theme_color_override("font_color", control.get_theme_color("font_hover_color"))
	_age = 0.0


func _draw() -> void:
	if _age >= BURST_TIME or not is_instance_valid(_focused) or not _focused.is_visible_in_tree():
		return
	var t := _age / BURST_TIME
	var rect := _focused.get_global_rect()
	draw_rect(rect, Color(1, 1, 1, FLASH_ALPHA * (1.0 - t)))
	var center := rect.get_center()
	var half := rect.size / 2
	for i in LINES:
		var angle := TAU * (i + 0.5) / LINES
		var dir := Vector2.from_angle(angle)
		# Ponto da borda do retângulo nesta direção, e as linhas saindo dali.
		var to_edge := minf(half.x / maxf(absf(dir.x), 0.001), half.y / maxf(absf(dir.y), 0.001))
		var start := center + dir * (to_edge + LINE_GAP + LINE_TRAVEL * t)
		var length := LINE_LENGTH * (1.0 - t)
		draw_line(start, start + dir * length, Comic.INK, LINE_WIDTH * (1.0 - t) + 1.0)
