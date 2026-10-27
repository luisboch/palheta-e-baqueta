## Partida de 1 ou 2 jogadores: áudio, entrada e as pistas 3D. A lógica toda está em PlaySession.
##
## Vindo do menu, toca a escolha em App.selection. Rodando a cena sozinha (F6 no editor ou
## linha de comando):
##   godot --path godot res://game/play.tscn -- --song <pasta da música>
##         [--instrument strings|bass|drums] [--difficulty Easy|Medium|Hard|Expert] [--autoplay 1]
##         [--mode solo|coop|versus] [--instrument2 strings|bass|drums] [--difficulty2 Easy|...]
## --autoplay: o jogo toca sozinho, acertando cada nota no tempo (depuração e demonstração).
## Sem --song, abre a música de data/library com mais instrumentos.
extends Node3D

const LEAD_IN := 2.0  ## s antes da música: dá para ver as primeiras notas chegando
const MUSIC_BUS := "Music"
## Bus do instrumento de cada jogador, com o pitch shift do whammy (default_bus_layout.tres).
## Mandam para o Music, para o fundo continuar reagindo ao som do jogador.
const PLAYER_BUSES: Array[String] = ["Player1", "Player2"]
## Abaixo disso o pitch shift fica desligado: mesmo em 1,0 ele colore um pouco o som.
const BEND_EPSILON := 0.01
const OTHERS_DB := -3.0  ## instrumentos que ninguém toca: um pouco abaixo de quem joga
const CAM_1P_POS := Vector3(0.0, 2.4, 2.9)
const CAM_2P_POS := Vector3(0.0, 2.9, 4.0)  ## x vem da pista de cada jogador
## Com 2 jogadores, cada pista tem a sua câmera e a sua metade da tela (ADR 0019). As pistas
## ficam longe o bastante para que a câmera de um jogador não enxergue a pista do outro.
const HIGHWAY_2P_OFFSET := 50.0
## Câmera viva: balança devagar e "respira" na batida. Pouco, para a pista continuar parada
## aos olhos de quem lê as notas.
const SWAY := Vector2(0.05, 0.03)  ## m de balanço (lado, altura)
const SWAY_SECONDS := 7.0  ## um balanço inteiro
const BEAT_FOV := 0.8  ## graus a mais de abertura na batida

var auto_start := true
var camera_2: Camera3D
var highway_2: Highway
var paused := false
var play_mode := "solo"
var player: AudioStreamPlayer  ## o fundo e os outros instrumentos; o relógio vem dele
## Instrumento de cada jogador, num player e num bus próprios para o whammy mudar só o som dele
## (ADR 0021). Com os 2 no mesmo instrumento, o mesmo player nas duas posições.
var stems: Array[AudioStreamPlayer] = [null, null]
var session: PlaySession
var session_2: PlaySession
var sfx: SoundEffects
var split: CanvasLayer  ## metades da tela com 2 jogadores (null no solo)

var _autoplay := false
var _bands := SpectrumBands.new()
var _done := false
var _grid: BeatGrid
var _lead := LEAD_IN
var _loaded: Dictionary
var _spectrum: AudioEffectSpectrumAnalyzerInstance
var _started_audio := false
var _whammies: Array[Whammy] = [Whammy.new(), Whammy.new()]
var _bends: Array[float] = [0.0, 0.0]
var _others: Array[int] = []  ## stems dos instrumentos que ninguém está tocando
var _cameras: Array[Camera3D] = []
var _camera_rest: Array[Vector3] = []  ## onde cada câmera fica parada
var _fov := 0.0
var _clock := 0.0  ## s desde o começo, para o balanço da câmera

@onready var background: Background = $Background
@onready var camera: Camera3D = $Camera3D
@onready var highway: Highway = $Highway
@onready var hud: Hud = $Hud


func _ready() -> void:
	sfx = SoundEffects.new()
	add_child(sfx)
	InputProfile.apply()
	hud.again.connect(App.goto.bind(App.PLAY))  # a mesma escolha, do começo
	hud.choose_song.connect(leave)
	hud.resume.connect(set_paused.bind(false))
	if not auto_start:
		return
	if not App.selection.is_empty():
		start(
			App.selection["dir"],
			App.selection["instrument"],
			App.selection["difficulty"],
			false,
			App.selection.get("mode", "solo"),
			App.selection.get("instrument_p2", ""),
			App.selection.get("difficulty_p2", "")
		)
	else:
		var args := _args()
		start(
			args.get("song", default_song(App.library_dir)),
			args.get("instrument", ""),
			args.get("difficulty", ""),
			args.has("autoplay"),
			args.get("mode", "solo"),
			args.get("instrument2", ""),
			args.get("difficulty2", "")
		)


## Começa a partida de 1 ou 2 jogadores.
func start(
	dir: String,
	instrument: String,
	difficulty: String,
	autoplay := false,
	mode := "solo",
	instrument_p2 := "",
	difficulty_p2 := ""
) -> void:
	play_mode = mode
	_autoplay = autoplay
	_loaded = SongLoader.load_dir(dir)
	if not _loaded["ok"]:
		hud.show_message(_loaded["error"] if dir != "" else "Nenhuma música em data/library")
		return
	var available := InstrumentRules.available(_loaded["song"], _loaded["chart"])
	if available.is_empty():
		hud.show_message("Esta música não tem nenhum instrumento jogável")
		return
	var choice := InstrumentRules.choose(available, instrument, difficulty)
	instrument = choice[0]
	difficulty = choice[1]

	session = PlaySession.new(_loaded["chart"], instrument, difficulty)
	print("partida: %s, %s, %s" % [dir.get_file(), instrument, difficulty])  # para ler o game.log
	App.pause_worker(true)
	_grid = (
		BeatGrid.from_beatmap(_loaded["beatmap"])
		if not _loaded["beatmap"].get("beats", []).is_empty()
		else BeatGrid.from_tempo(session.tempo, session.duration)
	)

	var is_2p := instrument_p2 != "" or play_mode in ["coop", "versus"]
	if is_2p and play_mode not in ["coop", "versus"]:
		play_mode = "coop"  # segundo instrumento sem modo: tocam juntos
	if is_2p:
		var choice_p2 := InstrumentRules.choose(
			available,
			instrument_p2 if instrument_p2 != "" else instrument,
			difficulty_p2 if difficulty_p2 != "" else difficulty
		)
		var inst_2: String = choice_p2[0]
		var diff_2: String = choice_p2[1]
		session_2 = PlaySession.new(_loaded["chart"], inst_2, diff_2)
		print("partida: jogador 2, %s, %s" % [inst_2, diff_2])
		highway.position.x = -HIGHWAY_2P_OFFSET
		highway_2 = highway.duplicate()
		add_child(highway_2)
		highway_2.position.x = HIGHWAY_2P_OFFSET
		highway_2.setup(session_2)
		if camera:
			_split_screen()
	else:
		if camera:
			camera.position = CAM_1P_POS
		highway.position.x = 0.0

	highway.setup(session)
	var combos: Array[Label3D] = []
	if session_2:
		combos = [highway.combo, highway_2.combo]
	hud.setup(
		_loaded["song"],
		instrument,
		difficulty,
		play_mode,
		session_2.instrument if session_2 else "",
		session_2.difficulty if session_2 else "",
		combos
	)
	_setup_audio(instrument, session_2.instrument if session_2 else "")
	_show_cover()
	for cam: Camera3D in [camera, camera_2]:
		if cam:
			_cameras.append(cam)
			_camera_rest.append(cam.position)
			_fov = cam.fov


## A capa da música no telão do palco atrás de cada pista, com as luzes na cor dela.
func _show_cover() -> void:
	var path := SongLoader.file_path(_loaded, "cover")
	var image := Image.load_from_file(path) if path != "" else null
	var texture := ImageTexture.create_from_image(image) if image else null
	for road: Highway in [highway, highway_2]:
		if road:
			road.backdrop.show_cover(texture, CoverColor.dominant(image))


## Tela dividida: P1 à esquerda, P2 à direita, cada metade com a câmera no centro da própria
## pista, para as notas virem do ponto de fuga de cada um. As duas metades veem o mesmo mundo
## 3D; o fundo (CanvasLayer atrás) aparece pelo fundo transparente delas.
func _split_screen() -> void:
	split = CanvasLayer.new()
	split.name = "Split"
	split.layer = 0  # entre o fundo (-1) e o HUD (1)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	split.add_child(row)
	add_child(split)

	# Numa SubViewport o fundo "Canvas" seria o canvas vazio dela: cor transparente no lugar.
	var env: Environment = $Environment.environment.duplicate()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.background_color = Color(0, 0, 0, 0)
	camera_2 = camera.duplicate()
	for i in 2:
		var cam := camera if i == 0 else camera_2
		var road := highway if i == 0 else highway_2
		var box := SubViewportContainer.new()
		box.stretch = true
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var view := SubViewport.new()
		view.world_3d = get_viewport().world_3d
		view.transparent_bg = true
		# A SubViewport não herda o MSAA do projeto: sem ele as linhas finas da pista somem
		# no fundo (a do meio, reta para a câmera, some primeiro).
		view.msaa_3d = get_viewport().msaa_3d
		view.handle_input_locally = false
		box.add_child(view)
		row.add_child(box)
		if cam.get_parent():
			cam.reparent(view, false)
		else:
			view.add_child(cam)
		cam.environment = env
		cam.position = Vector3(road.position.x, CAM_2P_POS.y, CAM_2P_POS.z)
		cam.current = true


func _exit_tree() -> void:
	if session:
		App.pause_worker(false)


## Sai da partida: para a escolha de música (vindo do menu) ou fecha o jogo (cena sozinha).
func leave() -> void:
	if not App.selection.is_empty():
		App.goto(App.SONG_SELECT)
	elif App.live:  # nos testes, fechar o jogo fecharia o executor de testes
		get_tree().quit()


func _setup_audio(instrument: String, instrument_2 := "") -> void:
	var sync := AudioStreamSynchronized.new()
	var streams: Array[AudioStream] = []
	# O fundo (song.ogg) não tem nenhum instrumento presente; os outros instrumentos continuam
	# tocando por baixo do jogador, só um pouco mais baixos, para destacar o que ele toca.
	var roles: Array[String] = ["song"]
	for role: String in BackendProtocol.INSTRUMENTS:
		roles.append(role)
	var played: Array[String] = [instrument, instrument_2]

	for role: String in roles:
		var path := SongLoader.file_path(_loaded, role)
		if path == "":
			continue
		var stream := AudioStreamOggVorbis.load_from_file(path)
		if stream == null:
			continue
		if role in played and role != "":
			_add_stem(played.find(role), stream)
			if instrument_2 == instrument:
				stems[1] = stems[0]
		else:
			if role != "song":
				_others.append(streams.size())
			streams.append(stream)
	sync.stream_count = streams.size()
	for i in streams.size():
		sync.set_sync_stream(i, streams[i])
	for i: int in _others:
		sync.set_sync_stream_volume(i, OTHERS_DB)
	player = AudioStreamPlayer.new()
	player.stream = sync
	var bus := AudioServer.get_bus_index(MUSIC_BUS)
	if bus >= 0:  # o analisador de espectro do fundo fica no bus Music (default_bus_layout.tres)
		player.bus = MUSIC_BUS
		_spectrum = AudioServer.get_bus_effect_instance(bus, 0)
	add_child(player)


func _add_stem(index: int, stream: AudioStream) -> void:
	var stem := AudioStreamPlayer.new()
	stem.stream = stream
	if AudioServer.get_bus_index(PLAYER_BUSES[index]) >= 0:
		stem.bus = PLAYER_BUSES[index]
	add_child(stem)
	stems[index] = stem


## Volume (dB) e whammy (`bend`, 0-1) do instrumento de um jogador. Com os 2 no mesmo
## instrumento, vale o maior dos dois.
func _set_stem(index: int, volume_db: float, bend: float) -> void:
	var stem := stems[index]
	if stem == null:
		return
	if index == 1 and stem == stems[0]:
		volume_db = maxf(volume_db, stem.volume_db)
		bend = maxf(bend, _bends[0])
	stem.volume_db = volume_db
	_bends[index] = bend
	var bus := AudioServer.get_bus_index(stem.bus)
	if bus < 0 or stem.bus == MUSIC_BUS or AudioServer.get_bus_effect_count(bus) == 0:
		return
	var shift := AudioServer.get_bus_effect(bus, 0) as AudioEffectPitchShift
	if shift:
		shift.pitch_scale = Whammy.pitch_scale(bend)
		AudioServer.set_bus_effect_enabled(bus, 0, bend > BEND_EPSILON)


func _process(delta: float) -> void:
	if session == null or _done or paused:
		return
	var now := _song_time(delta)
	if _autoplay:
		_play_by_itself(now)
	_update_player(0, session, highway, now, delta)
	if session_2 and highway_2:
		_update_player(1, session_2, highway_2, now, delta)
	var levels := _bands.update(_magnitudes(), delta)
	background.update(now, _grid, levels)
	var pulse := _grid.pulse(now)
	for road: Highway in [highway, highway_2]:
		if road:
			road.backdrop.update(now, _grid, levels)
	hud.update_score(session.scoring, session_2.scoring if session_2 else null, pulse)
	_move_cameras(delta, pulse)
	var finished_all := session.finished(now) and (session_2 == null or session_2.finished(now))
	if finished_all and (player == null or not player.playing or now > session.duration + 3.0):
		_done = true
		hud.show_results(session.scoring, session_2.scoring if session_2 else null)


func _move_cameras(delta: float, pulse: float) -> void:
	_clock += delta
	var t := TAU * _clock / SWAY_SECONDS
	var sway := Vector3(sin(t) * SWAY.x, sin(t * 1.3) * SWAY.y, 0)
	for i in _cameras.size():
		_cameras[i].position = _camera_rest[i] + sway
		_cameras[i].fov = _fov + BEAT_FOV * pulse


## Um quadro da partida de um jogador: whammy, notas perdidas e soltas, som e pista.
func _update_player(index: int, s: PlaySession, h: Highway, now: float, delta: float) -> void:
	var sticks: Array[Vector2] = [_stick(index, true), _stick(index, false)]
	var key := Input.is_action_pressed(InputProfile.player_whammy(index))
	s.whammy = _whammies[index].update(sticks, key, delta)
	if not _autoplay:
		_read_input(s, h, InputReader.lanes_down(index, s.drums), now)
	var events := s.update(now, delta)
	if not events["missed"].is_empty() and sfx:
		sfx.play_miss()
	for note: PlayNote in events["missed"]:
		h.on_miss(note)
	if events["dropped"]:
		h.on_drop(events["dropped"])
	_set_stem(index, events["volume_db"], events["bend"])
	h.update_view(now, _grid, events["bend"])
	h.set_power(s.scoring.multiplier(), _grid.pulse(now))


## Os botões deste quadro (`down` = apertados agora): julga cada aperto e desenha o traste (ou
## pad) apertado e solto.
func _read_input(s: PlaySession, h: Highway, down: PackedInt32Array, now: float) -> void:
	if s.drums:
		for hit: Dictionary in s.pad_input(down, now):
			h.on_input(hit["lane"], hit["result"])
		return
	var change := s.fret_input(down, now, InputProfile.FRET_TAPS)
	for lane in change["released"]:
		h.set_fret(lane, false)
	for lane in change["pressed"]:
		h.set_fret(lane, true)
	for tap: Dictionary in change["taps"]:
		var result: Dictionary = tap["result"]
		if result.is_empty():
			continue
		h.on_strum(result)
		if result.get("grade") == Judge.OVERSTRUM and sfx:
			sfx.play_error()


## Posição de um analógico (o esquerdo ou o direito) do controle do jogador.
static func _stick(device: int, left: bool) -> Vector2:
	var x := JOY_AXIS_LEFT_X if left else JOY_AXIS_RIGHT_X
	var y := JOY_AXIS_LEFT_Y if left else JOY_AXIS_RIGHT_Y
	return Vector2(Input.get_joy_axis(device, x), Input.get_joy_axis(device, y))


## Tempo da música: contagem regressiva no começo, depois o relógio sincronizado com o áudio.
## Sem áudio (testes, música sem OGG), o relógio do frame.
func _song_time(delta: float) -> float:
	if _lead > 0.0:
		_lead -= delta
		if _lead <= 0.0 and player and player.stream.stream_count > 0:
			# No mesmo quadro: entram no mesmo bloco do mixer e seguem juntos (mesma taxa).
			player.play()
			for stem in stems:
				if stem and not stem.playing:
					stem.play()
			_started_audio = true
		return -maxf(_lead, 0.0)
	if not _started_audio:
		return session.clock.update(session.clock.now() + delta, 0.0, 0.0, delta)
	if not player.playing:  # o áudio acabou antes de o chart terminar (última nota perto do fim)
		return session.clock.advance(delta)
	return session.clock.update(
		player.get_playback_position(),
		AudioServer.get_time_since_last_mix(),
		AudioServer.get_output_latency(),
		delta
	)


## Magnitude de cada faixa de SpectrumBands (média dos dois canais); vazio sem analisador.
func _magnitudes() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if _spectrum == null:
		return out
	for band: Array in SpectrumBands.BANDS:
		var m := _spectrum.get_magnitude_for_frequency_range(band[0], band[1])
		out.append((m.x + m.y) / 2.0)
	return out


## Toca as notas que chegaram na linha (modo --autoplay).
func _play_by_itself(now: float) -> void:
	_autoplay_player(session, highway, now)
	if session_2 and highway_2:
		_autoplay_player(session_2, highway_2, now)


func _autoplay_player(s: PlaySession, h: Highway, now: float) -> void:
	for note in s.notes:
		if note.time > now:
			break
		if note.state != PlayNote.State.PENDING or note.time + Judge.WINDOWS["ok"] < now:
			continue
		if s.drums:
			h.on_input(note.lanes[0], s.pad(note.time, note.lanes[0]))
		else:
			s.held = note.lanes.duplicate()
			h.on_strum(s.strum(note.time))


## Pausa: para o áudio e o relógio (o _process não anda) e mostra Continuar / Recomeçar / Sair.
## Ao pausar e ao voltar, os trastes passam a valer o que está apertado de verdade, sem contar
## como aperto novo o botão que o jogador já segurava.
func set_paused(value: bool) -> void:
	if session == null or _done or value == paused:
		return
	paused = value
	if player:
		player.stream_paused = value
	for stem in stems:
		if stem:
			stem.stream_paused = value
	_resync_input(0, session, highway)
	if session_2 and highway_2:
		_resync_input(1, session_2, highway_2)
	hud.show_pause(value)


## Apertar o botão Steam ou trocar de janela pausa a partida.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		set_paused(true)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputProfile.PAUSE):
		if session == null or _done:
			leave()
		else:
			set_paused(not paused)
		return
	if InputProfile.FRET_TAPS or session == null or _done or paused or event.is_echo():
		return
	# Guitarra USB (fase 8): a nota toca na palhetada, com os trastes que estão apertados.
	var now := session.clock.now() if _lead <= 0.0 else -_lead
	_strum(0, event, session, highway, now)
	if session_2 and highway_2:
		_strum(1, event, session_2, highway_2, now)


func _strum(index: int, event: InputEvent, s: PlaySession, h: Highway, now: float) -> void:
	for action in InputProfile.player_strum(index):
		if event.is_action_pressed(action):
			var result := s.strum(now)
			h.on_strum(result)
			if result.get("grade") == Judge.OVERSTRUM and sfx:
				sfx.play_error()


## Faz o estado dos botões valer o que está apertado agora, sem contar aperto, e redesenha.
func _resync_input(index: int, s: PlaySession, h: Highway) -> void:
	s.buttons.reset(InputReader.lanes_down(index, s.drums))
	s.held = s.buttons.held
	for lane in InputProfile.FRETS.size():
		h.set_fret(lane, lane in s.held and not s.drums and not paused)


func _args() -> Dictionary:
	var out := {}
	var user := OS.get_cmdline_user_args()
	var i := 0
	while i < user.size():
		if user[i].begins_with("--") and i + 1 < user.size():
			out[user[i].trim_prefix("--")] = user[i + 1]
			i += 2
		else:
			i += 1
	return out


## A música com mais instrumentos presentes (empate: a primeira pelo nome da pasta); "" se nenhuma.
static func default_song(library: String) -> String:
	var dir := DirAccess.open(library)
	if dir == null:
		return ""
	var names := dir.get_directories()
	names.sort()
	var best := ""
	var best_count := -1
	for name in names:
		var path := library.path_join(name)
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(path.path_join("song.json"))) != OK:
			continue
		var present: Dictionary = (
			json.data.get("instruments", {}) if json.data is Dictionary else {}
		)
		var count := present.values().count(true)
		if count > best_count:
			best = path
			best_count = count
	return best
