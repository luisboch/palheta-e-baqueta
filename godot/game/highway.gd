## A pista 3D: lanes, linha de acerto e as notas vindo na direção do jogador.
##
## Cordas e baixo: 5 lanes, notas redondas (discos), sustentação como cauda. Segurando uma
## sustentada, a cauda vai sendo "consumida" na linha de acerto, acesa, e ondula com o whammy;
## solta antes do fim, o resto da cauda apaga.
## Bateria: 4 pads, notas quadradas (pratos metálicos), bumbo como uma barra atravessando a pista.
## Identidade própria: a paleta das lanes não é a de outros jogos do gênero.
class_name Highway
extends Node3D

const LANE_WIDTH := 0.55
const SPEED := 7.0  ## unidades por segundo: distância = tempo até a nota × SPEED
const LOOKAHEAD := 2.2  ## s de notas visíveis à frente
const BEHIND := 0.4  ## s depois da linha em que a nota perdida ainda aparece
const COLORS := [
	Color("2ec4b6"),  # turquesa
	Color("ff6b6b"),  # coral
	Color("ffd166"),  # âmbar
	Color("4d96ff"),  # azul
	Color("c77dff"),  # violeta
]
const KICK_COLOR := Color("ff9f1c")
const MISS_COLOR := Color(0.25, 0.25, 0.28)
const BEAT_LINE_POOL := 24  ## linhas de batida visíveis de uma vez (LOOKAHEAD cobre ~6 a 200 BPM)
const BEAT_LINE_COLOR := Color(0.55, 0.55, 0.75)
const HIT_POP := 1.35  ## escala do alvo no acerto, voltando a 1 em HIT_POP_TIME
const HIT_POP_TIME := 0.12
const TAIL_WIDTH := 0.07
const HOLD_WIDTH := 0.1  ## cauda segurada: um pouco mais larga, para se ver que está valendo
const HOLD_STEP := 0.08  ## distância entre os pontos da cauda segurada (a onda precisa deles)
const WOBBLE_AMPLITUDE := 0.09  ## deslocamento lateral da onda com o whammy no máximo
const WOBBLE_HZ := 9.0
const WOBBLE_WAVES := 1.6  ## ondas por unidade de pista: a cauda serpenteia, não só balança

var session: PlaySession
var lanes := 5
var _views := {}  ## PlayNote → Node3D
var _next := 0  ## próxima nota que ainda não ganhou desenho
var _flash := 0.0
var _beat_lines: Array[MeshInstance3D] = []
var _hold: MeshInstance3D  ## caudas sendo seguradas, refeitas a cada quadro
var _time := 0.0

## Sequência do jogador sobre a pista, com 2 jogadores (o texto vem do Hud).
@onready var combo: Label3D = $Combo
@onready var _board: MeshInstance3D = $Board
@onready var _strikeline: MeshInstance3D = $Strikeline
@onready var _lines: Node3D = $Lines
@onready var _targets: Node3D = $Targets
@onready var _notes: Node3D = $Notes
@onready var _beat_root: Node3D = $BeatLines


## Prepara a pista para a partida: 5 lanes (Cordas, baixo) ou 4 pads (bateria).
## A cena (play.tscn) vem montada com 5 lanes, que é o que o editor mostra.
func setup(play_session: PlaySession) -> void:
	session = play_session
	_strikeline.material_override = _strikeline.material_override.duplicate()  # brilho por partida
	lanes = 4 if session.drums else 5
	# As malhas da cena são compartilhadas entre instâncias: copia antes de mudar a largura.
	var board: BoxMesh = _board.mesh.duplicate()
	board.size.x = lanes * LANE_WIDTH + 0.2
	_board.mesh = board
	var line_mesh: BoxMesh = _strikeline.mesh.duplicate()
	line_mesh.size.x = board.size.x
	_strikeline.mesh = line_mesh
	for i in _lines.get_child_count():
		var line: Node3D = _lines.get_child(i)
		line.visible = i <= lanes
		line.position.x = _x(i) - LANE_WIDTH / 2
	for i in _targets.get_child_count():
		var target: MeshInstance3D = _targets.get_child(i)
		target.visible = i < lanes
		if i >= lanes:
			continue
		target.position.x = _x(i)
		var fresh := _note_mesh(_lane_color(i), false)
		target.mesh = fresh.mesh
		target.material_override = fresh.material_override
		fresh.free()
	_make_beat_lines(board.size.x)
	if _hold == null:
		_hold = MeshInstance3D.new()
		_hold.mesh = ImmediateMesh.new()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_hold.material_override = mat
		_notes.add_child(_hold)


## Linhas de batida que correm pela pista com as notas (downbeat mais forte): mostram o tempo
## mesmo nos trechos sem nota. Um conjunto fixo, reaproveitado a cada quadro.
func _make_beat_lines(width: float) -> void:
	for line in _beat_lines:
		line.free()
	_beat_lines.clear()
	for i in BEAT_LINE_POOL:
		var line := _box(Vector3(width, 0.005, 0.03), BEAT_LINE_COLOR, 0.3)
		line.visible = false
		_beat_root.add_child(line)
		_beat_lines.append(line)


func _x(lane: int) -> float:
	return (lane - (lanes - 1) / 2.0) * LANE_WIDTH


func _lane_color(lane: int) -> Color:
	return COLORS[lane + (1 if session and session.drums else 0)]


## Lane na tela de uma nota: na bateria, lane 0 é o bumbo e os pads 1-4 viram as lanes 0-3.
func _screen_lane(note: PlayNote) -> int:
	return note.lanes[0] - 1 if session.drums else note.lanes[0]


## `grid`: as batidas da música (null: sem linhas nem pulso). `whammy`: a alavanca (0-1), que
## faz ondular a cauda segurada.
func update_view(now: float, grid: BeatGrid = null, whammy := 0.0) -> void:
	while _next < session.notes.size() and session.notes[_next].time < now + LOOKAHEAD:
		var note := session.notes[_next]
		if note.state == PlayNote.State.PENDING:
			_views[note] = _make_view(note)
			_notes.add_child(_views[note])
		_next += 1
	var holding: Array[PlayNote] = []
	for note: PlayNote in _views.keys():
		var view: Node3D = _views[note]
		view.position.z = -(note.time - now) * SPEED
		view.visible = not note.holding
		if note.holding:
			holding.append(note)
		var done := note.state == PlayNote.State.HIT and not note.holding and not note.dropped()
		if note.end_time + BEHIND < now or done:
			view.queue_free()
			_views.erase(note)
	_time += get_process_delta_time()
	_draw_holds(holding, now, whammy)
	if not holding.is_empty():
		_flash = maxf(_flash, 0.4)  # a linha de acerto continua acesa enquanto segura
	_flash = maxf(_flash - get_process_delta_time() * 4.0, 0.0)
	var pulse := grid.pulse(now) if grid else 0.0
	var mat: StandardMaterial3D = _strikeline.material_override
	mat.emission_energy_multiplier = 1.5 + _flash * 4.0 + pulse * 0.6
	if grid:
		_update_beat_lines(now, grid)


func _update_beat_lines(now: float, grid: BeatGrid) -> void:
	var visible_beats := grid.between(now - BEHIND, now + LOOKAHEAD)
	for i in _beat_lines.size():
		var line := _beat_lines[i]
		line.visible = i < visible_beats.size()
		if not line.visible:
			continue
		var beat: Array = visible_beats[i]
		line.position = Vector3(0, -0.035, -(beat[0] - now) * SPEED)
		line.scale = Vector3(1, 1, 2.5 if beat[1] else 1.0)
		line.transparency = 0.2 if beat[1] else 0.6


## As caudas seguradas: da linha de acerto até o fim da nota (ou do que se vê da pista), como
## uma fita que ondula para os lados com o whammy. Só estas mudam a cada quadro.
func _draw_holds(holding: Array[PlayNote], now: float, whammy: float) -> void:
	var mesh: ImmediateMesh = _hold.mesh
	mesh.clear_surfaces()
	if holding.is_empty():
		return
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for note in holding:
		var length := minf(note.end_time - now, LOOKAHEAD) * SPEED
		for lane in note.lanes:
			var color := _lane_color(lane).lightened(0.3)
			var steps := maxi(ceili(length / HOLD_STEP), 1)
			for i in steps:
				var z0 := -i * HOLD_STEP
				var z1 := -minf((i + 1) * HOLD_STEP, length)
				_ribbon_quad(mesh, color, _x(lane), z0, z1, whammy)
	mesh.surface_end()


func _ribbon_quad(
	mesh: ImmediateMesh, color: Color, x: float, z0: float, z1: float, whammy: float
) -> void:
	var a := x + _wobble(z0, whammy)
	var b := x + _wobble(z1, whammy)
	var half := HOLD_WIDTH / 2
	var corners := [
		Vector3(a - half, 0.0, z0),
		Vector3(a + half, 0.0, z0),
		Vector3(b + half, 0.0, z1),
		Vector3(b - half, 0.0, z1),
	]
	for i: int in [0, 1, 2, 0, 2, 3]:
		mesh.surface_set_color(color)
		mesh.surface_add_vertex(corners[i])


## Deslocamento lateral da cauda no ponto `z`: parada sem whammy; a onda corre pela cauda.
func _wobble(z: float, whammy: float) -> float:
	return WOBBLE_AMPLITUDE * whammy * sin(TAU * (WOBBLE_HZ * _time + WOBBLE_WAVES * z))


func _make_view(note: PlayNote) -> Node3D:
	var root := Node3D.new()
	if session.drums and note.lanes[0] == 0:
		var bar := _box(Vector3(lanes * LANE_WIDTH, 0.05, 0.1), KICK_COLOR, 0.6)
		root.add_child(bar)
		return root
	for lane in note.lanes:
		var screen := lane - 1 if session.drums else lane
		var mesh := _note_mesh(_lane_color(screen), note.cymbal)
		mesh.position.x = _x(screen)
		root.add_child(mesh)
		if note.is_sustain():
			var tail_len := (note.end_time - note.time) * SPEED
			var tail := _box(Vector3(TAIL_WIDTH, 0.03, tail_len), _lane_color(screen), 0.8)
			tail.position = Vector3(_x(screen), -0.01, -tail_len / 2)
			tail.name = "Tail%d" % screen
			root.add_child(tail)
	return root


## Nota redonda (disco) para Cordas e baixo, quadrada para a bateria (prato: metálico).
func _note_mesh(color: Color, cymbal: bool) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	if session and session.drums:
		var box := BoxMesh.new()
		box.size = Vector3(0.42, 0.1, 0.24)
		mesh.mesh = box
	else:
		var disc := CylinderMesh.new()
		disc.top_radius = 0.2
		disc.bottom_radius = 0.22
		disc.height = 0.1
		mesh.mesh = disc
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.35
	if cymbal:
		# Metálico puro fica escuro sem nada para refletir: brilho próprio mais forte e cor clara.
		mat.metallic = 0.5
		mat.roughness = 0.25
		mat.albedo_color = color.lightened(0.35)
		mat.emission_energy_multiplier = 0.8
	mesh.material_override = mat
	return mesh


func _box(size: Vector3, color: Color, glow: float = 0.0) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	mesh.material_override = mat
	return mesh


func set_fret(lane: int, pressed: bool) -> void:
	if lane < lanes:
		_target(lane).transparency = 0.0 if pressed else 0.6


func _target(lane: int) -> MeshInstance3D:
	return _targets.get_child(lane)


func on_strum(result: Dictionary) -> void:
	_flash = 1.0 if result.has("note") else 0.3
	if result.has("note"):
		for lane: int in result["note"].lanes:
			_pop(lane)


## O alvo da lane cresce e volta: o "estouro" de um acerto.
func _pop(screen: int) -> void:
	if screen < 0 or screen >= lanes:
		return
	var target := _target(screen)
	target.scale = Vector3(HIT_POP, 0.4 * HIT_POP, HIT_POP)
	create_tween().tween_property(target, "scale", Vector3(1, 0.4, 1), HIT_POP_TIME)


func on_input(lane: int, result: Dictionary) -> void:
	var screen := lane - 1 if session.drums else lane
	if screen >= 0 and screen < lanes:
		_target(screen).transparency = 0.0
		create_tween().tween_property(_target(screen), "transparency", 0.6, 0.15)
	if result.has("note"):
		_flash = 1.0
		_pop(screen)


func on_miss(note: PlayNote) -> void:
	var view: Node3D = _views.get(note)
	if view == null:
		return
	for child in view.get_children():
		if child is MeshInstance3D:
			_gray(child)


## Sustentada solta antes do fim: fica só o resto da cauda (de onde soltou até o fim), apagado,
## seguindo com a pista.
func on_drop(note: PlayNote) -> void:
	var view: Node3D = _views.get(note)
	if view == null:
		return
	var start := (note.held_until - note.time) * SPEED
	var rest := maxf((note.end_time - note.held_until) * SPEED, 0.001)
	for child in view.get_children():
		if not child.name.begins_with("Tail"):
			child.visible = false  # a cabeça da nota já foi tocada
			continue
		var tail: MeshInstance3D = child
		var box: BoxMesh = tail.mesh
		box.size.z = rest
		tail.position.z = -start - rest / 2
		_gray(tail)


func _gray(mesh: MeshInstance3D) -> void:
	var mat: StandardMaterial3D = mesh.material_override
	mat.albedo_color = MISS_COLOR
	mat.emission_enabled = false
