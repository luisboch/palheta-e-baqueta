## Desenha o ícone do jogo (256×256): a pista em perspectiva com as cores das lanes e uma
## palheta âmbar. Identidade própria, nada de logo de outro jogo.
##   $(scripts/godot.sh) --headless --path godot -s ../scripts/steamdeck/make_icon.gd -- <saída.png>
extends SceneTree

const SIZE := 256
const BG_TOP := Color("1b1530")
const BG_BOTTOM := Color("08080f")
const PICK := Color("ffd166")
const LANES := [
	Color("2ec4b6"), Color("ff6b6b"), Color("ffd166"), Color("4d96ff"), Color("c77dff")
]


func _init() -> void:
	var out := OS.get_cmdline_user_args()[0]
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			img.set_pixel(x, y, _pixel(Vector2(x + 0.5, y + 0.5) / SIZE))
	img.save_png(out)
	quit()


func _pixel(p: Vector2) -> Color:
	var corner := _rounded_box(p - Vector2(0.5, 0.5), Vector2(0.5, 0.5), 0.18)
	if corner > 0.0:
		return Color(0, 0, 0, 0)
	var col := BG_TOP.lerp(BG_BOTTOM, p.y)
	# Pista: 5 faixas convergindo para o ponto de fuga.
	var vanish := Vector2(0.5, 0.18)
	if p.y > vanish.y:
		var t := (p.y - vanish.y) / (1.0 - vanish.y)
		var half := 0.06 + 0.42 * t
		var u := (p.x - 0.5) / half
		if absf(u) < 1.0:
			var lane := clampi(int((u + 1.0) / 2.0 * 5.0), 0, 4)
			col = col.lerp(LANES[lane], 0.25 + 0.5 * t)
	# Palheta: triângulo arredondado de ponta para baixo, com contorno escuro.
	var d := _pick(p - Vector2(0.5, 0.56))
	if d < 0.0:
		col = PICK.lerp(Color.WHITE, clampf(-d * 4.0, 0.0, 0.25))
	elif d < 0.025:
		col = Color("08080f")
	return col


func _rounded_box(p: Vector2, half: Vector2, r: float) -> float:
	var q := p.abs() - half + Vector2(r, r)
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - r


func _pick(p: Vector2) -> float:
	# Distância a um triângulo (topo largo, ponta embaixo), menos o raio do arredondamento.
	var a := Vector2(-0.16, -0.13)
	var b := Vector2(0.16, -0.13)
	var c := Vector2(0.0, 0.15)
	var d := minf(minf(_segment(p, a, b), _segment(p, b, c)), _segment(p, c, a))
	var inside := _side(p, a, b) >= 0.0 and _side(p, b, c) >= 0.0 and _side(p, c, a) >= 0.0
	return (-d if inside else d) - 0.1


func _segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var t := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
	return (p - a - (b - a) * t).length()


func _side(p: Vector2, a: Vector2, b: Vector2) -> float:
	return (b - a).cross(p - a)
