## Partida de um jogador: áudio, entrada e a pista 3D. A lógica toda está em PlaySession.
##
## Uso (fase 6, antes dos menus):
##   godot --path godot -- --song <pasta da música> [--instrument strings|bass|drums]
##                         [--difficulty Easy|Medium|Hard|Expert] [--autoplay 1]
## --autoplay: o jogo toca sozinho, acertando cada nota no tempo (depuração e demonstração).
## Sem --song, abre a primeira música de data/library (ao lado do projeto Godot).
extends Node3D

const LEAD_IN := 2.0  ## s antes da música: dá para ver as primeiras notas chegando
const DEFAULT_LIBRARY := "../data/library"

## Falso: quem criou a cena chama `start()` (os menus, na fase 9; os testes). Verdadeiro: a
## partida vem da linha de comando.
var auto_start := true
var session: PlaySession
var player: AudioStreamPlayer
var _stem_index := -1  ## índice do stem do jogador no AudioStreamSynchronized
var _started_audio := false
var _lead := LEAD_IN
var _loaded: Dictionary
var _done := false
var _autoplay := false

@onready var highway: Highway = $Highway
@onready var hud: Hud = $Hud


func _ready() -> void:
	InputProfile.apply()
	if auto_start:
		var args := _args()
		start(
			args.get("song", _first_song()),
			args.get("instrument", ""),
			args.get("difficulty", ""),
			args.has("autoplay")
		)


## Começa a partida. Instrumento ou dificuldade vazios/indisponíveis: o primeiro instrumento
## jogável, na dificuldade mais alta que ele tem.
func start(dir: String, instrument: String, difficulty: String, autoplay := false) -> void:
	_autoplay = autoplay
	_loaded = SongLoader.load_dir(dir)
	if not _loaded["ok"]:
		hud.show_message(_loaded["error"] if dir != "" else "Nenhuma música em data/library")
		return
	var available := InstrumentRules.available(_loaded["song"], _loaded["chart"])
	if available.is_empty():
		hud.show_message("Esta música não tem nenhum instrumento jogável")
		return
	if not available.has(instrument):
		instrument = available.keys()[0]
	var levels: Array = available[instrument]
	if difficulty not in levels:
		difficulty = levels[levels.size() - 1]

	session = PlaySession.new(_loaded["chart"], instrument, difficulty)
	highway.setup(session)
	hud.setup(_loaded["song"], instrument, difficulty)
	_setup_audio(instrument)


func _setup_audio(instrument: String) -> void:
	var sync := AudioStreamSynchronized.new()
	var streams: Array[AudioStream] = []
	for role: String in ["song", instrument]:
		var path := SongLoader.file_path(_loaded, role)
		if path == "":
			continue
		var stream := AudioStreamOggVorbis.load_from_file(path)
		if stream:
			if role == instrument:
				_stem_index = streams.size()
			streams.append(stream)
	sync.stream_count = streams.size()
	for i in streams.size():
		sync.set_sync_stream(i, streams[i])
	player = AudioStreamPlayer.new()
	player.stream = sync
	add_child(player)


func _process(delta: float) -> void:
	if session == null or _done:
		return
	var now := _song_time(delta)
	if _autoplay:
		_play_by_itself(now)
	var events := session.update(now, delta)
	for note: PlayNote in events["missed"]:
		highway.on_miss(note)
	if _stem_index >= 0:
		player.stream.set_sync_stream_volume(_stem_index, events["volume_db"])
	highway.update_view(now)
	hud.update_score(session.scoring)
	if (
		session.finished(now)
		and (player == null or not player.playing or now > session.duration + 3.0)
	):
		_done = true
		hud.show_results(session.scoring)


## Tempo da música: contagem regressiva no começo, depois o relógio sincronizado com o áudio.
## Sem áudio (testes, música sem OGG), o relógio do frame.
func _song_time(delta: float) -> float:
	if _lead > 0.0:
		_lead -= delta
		if _lead <= 0.0 and player and player.stream.stream_count > 0:
			player.play()
			_started_audio = true
		return -maxf(_lead, 0.0)
	if not _started_audio:
		return session.clock.update(session.clock.now() + delta, 0.0, 0.0, delta)
	return session.clock.update(
		player.get_playback_position(),
		AudioServer.get_time_since_last_mix(),
		AudioServer.get_output_latency(),
		delta
	)


## Toca as notas que chegaram na linha (modo --autoplay).
func _play_by_itself(now: float) -> void:
	for note in session.notes:
		if note.time > now:
			break
		if note.state != PlayNote.State.PENDING or note.time + Judge.WINDOWS["ok"] < now:
			continue
		if session.drums:
			highway.on_input(note.lanes[0], session.pad(note.time, note.lanes[0]))
		else:
			session.held = note.lanes.duplicate()
			highway.on_strum(session.strum(note.time))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputProfile.PAUSE):
		get_tree().quit()
		return
	if session == null or _done or event.is_echo():
		return
	var now := session.clock.now() if _lead <= 0.0 else -_lead
	if session.drums:
		for lane in InputProfile.PADS.size():
			if event.is_action_pressed(InputProfile.PADS[lane]):
				highway.on_input(lane, session.pad(now, lane))
		return
	for lane in InputProfile.FRETS.size():
		if event.is_action_pressed(InputProfile.FRETS[lane]):
			session.press_fret(lane)
			highway.set_fret(lane, true)
		elif event.is_action_released(InputProfile.FRETS[lane]):
			session.release_fret(lane)
			highway.set_fret(lane, false)
	for action: String in InputProfile.STRUM:
		if event.is_action_pressed(action):
			var result := session.strum(now)
			highway.on_strum(result)


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


func _first_song() -> String:
	var library := (
		ProjectSettings.globalize_path("res://").path_join(DEFAULT_LIBRARY).simplify_path()
	)
	var dir := DirAccess.open(library)
	if dir == null:
		return ""
	var names := dir.get_directories()
	names.sort()
	for name in names:
		if FileAccess.file_exists(library.path_join(name).path_join("song.json")):
			return library.path_join(name)
	return ""
