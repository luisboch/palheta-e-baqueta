## A pista 3D: lanes, linha de acerto e as notas vindo na direção do jogador.
##
## Cordas e baixo: 5 lanes, notas redondas (discos), sustentação como cauda.
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

var session: PlaySession
var lanes: int
var _views := {}  ## PlayNote → Node3D
var _next := 0  ## próxima nota que ainda não ganhou desenho
var _targets: Array[MeshInstance3D] = []
var _strikeline: MeshInstance3D
var _flash := 0.0


func _init(play_session: PlaySession) -> void:
	session = play_session
	lanes = 4 if session.drums else 5


func _ready() -> void:
	var camera := Camera3D.new()
	camera.position = Vector3(0, 2.4, 2.9)
	camera.fov = 60
	add_child(camera)
	camera.look_at(Vector3(0, 0, -5.5))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -20, 0)
	add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("101018")
	env.environment.glow_enabled = true
	add_child(env)

	var length := SPEED * (LOOKAHEAD + BEHIND)
	var board := _box(Vector3(lanes * LANE_WIDTH + 0.2, 0.02, length), Color("1c1c2a"))
	board.position = Vector3(0, -0.05, -length / 2 + SPEED * BEHIND)
	add_child(board)
	for lane in lanes + 1:
		var line := _box(Vector3(0.015, 0.03, length), Color("3a3a55"))
		line.position = Vector3(_x(lane) - LANE_WIDTH / 2, -0.03, board.position.z)
		add_child(line)
	_strikeline = _box(Vector3(lanes * LANE_WIDTH + 0.2, 0.03, 0.04), Color.WHITE, 1.5)
	add_child(_strikeline)
	for lane in lanes:
		var target := _note_mesh(_lane_color(lane), false)
		target.scale = Vector3(1.0, 0.4, 1.0)
		target.position = Vector3(_x(lane), 0.0, 0.0)
		target.transparency = 0.6
		add_child(target)
		_targets.append(target)


func _x(lane: int) -> float:
	return (lane - (lanes - 1) / 2.0) * LANE_WIDTH


func _lane_color(lane: int) -> Color:
	return COLORS[lane + (1 if session.drums else 0)]


## Lane na tela de uma nota: na bateria, lane 0 é o bumbo e os pads 1-4 viram as lanes 0-3.
func _screen_lane(note: PlayNote) -> int:
	return note.lanes[0] - 1 if session.drums else note.lanes[0]


func update_view(now: float) -> void:
	while _next < session.notes.size() and session.notes[_next].time < now + LOOKAHEAD:
		var note := session.notes[_next]
		if note.state == PlayNote.State.PENDING:
			_views[note] = _make_view(note)
			add_child(_views[note])
		_next += 1
	for note: PlayNote in _views.keys():
		var view: Node3D = _views[note]
		view.position.z = -(note.time - now) * SPEED
		if note.end_time + BEHIND < now or note.state == PlayNote.State.HIT:
			view.queue_free()
			_views.erase(note)
	_flash = maxf(_flash - get_process_delta_time() * 4.0, 0.0)
	var mat: StandardMaterial3D = _strikeline.material_override
	mat.emission_energy_multiplier = 1.5 + _flash * 4.0


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
			var tail := _box(Vector3(0.07, 0.03, tail_len), _lane_color(screen), 0.8)
			tail.position = Vector3(_x(screen), -0.01, -tail_len / 2)
			root.add_child(tail)
	return root


## Nota redonda (disco) para Cordas e baixo, quadrada para a bateria (prato: metálico).
func _note_mesh(color: Color, cymbal: bool) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	if session.drums:
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
	if lane < _targets.size():
		_targets[lane].transparency = 0.0 if pressed else 0.6


func on_strum(result: Dictionary) -> void:
	_flash = 1.0 if result.has("note") else 0.3


func on_input(lane: int, result: Dictionary) -> void:
	var screen := lane - 1 if session.drums else lane
	if screen >= 0 and screen < _targets.size():
		_targets[screen].transparency = 0.0
		create_tween().tween_property(_targets[screen], "transparency", 0.6, 0.15)
	if result.has("note"):
		_flash = 1.0


func on_miss(note: PlayNote) -> void:
	var view: Node3D = _views.get(note)
	if view == null:
		return
	for child in view.get_children():
		if child is MeshInstance3D:
			var mat: StandardMaterial3D = child.material_override
			mat.albedo_color = MISS_COLOR
			mat.emission_enabled = false
