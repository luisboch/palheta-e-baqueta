## Partida de um jogador: áudio, entrada e a pista 3D. A lógica toda está em PlaySession.
##
## Vindo do menu, toca a escolha em App.selection. Rodando a cena sozinha (F6 no editor ou
## linha de comando):
##   godot --path godot res://game/play.tscn -- --song <pasta da música>
##         [--instrument strings|bass|drums] [--difficulty Easy|Medium|Hard|Expert] [--autoplay 1]
## --autoplay: o jogo toca sozinho, acertando cada nota no tempo (depuração e demonstração).
## Sem --song, abre a música de data/library com mais instrumentos.
extends Node3D

const LEAD_IN := 2.0  ## s antes da música: dá para ver as primeiras notas chegando
const MUSIC_BUS := "Music"

## Falso: quem criou a cena chama `start()` (os testes). Verdadeiro: a partida vem do menu
## (App.selection) ou da linha de comando.
var auto_start := true
var session: PlaySession
var player: AudioStreamPlayer
var paused := false
var sfx: SoundEffects
var _stem_index := -1  ## índice do stem do jogador no AudioStreamSynchronized
var _started_audio := false
var _lead := LEAD_IN
var _loaded: Dictionary
var _done := false
var _autoplay := false
var _grid: BeatGrid
var _bands := SpectrumBands.new()
var _spectrum: AudioEffectSpectrumAnalyzerInstance  ## null sem o bus Music (testes sem áudio)

@onready var highway: Highway = $Highway
@onready var hud: Hud = $Hud
@onready var background: Background = $Background


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
		start(App.selection["dir"], App.selection["instrument"], App.selection["difficulty"])
	else:
		var args := _args()
		start(
			args.get("song", default_song(App.library_dir)),
			args.get("instrument", ""),
			args.get("difficulty", ""),
			args.has("autoplay")
		)


## Começa a partida. Instrumento ou dificuldade vazios/indisponíveis: Cordas (senão o primeiro
## instrumento jogável) no Difícil (senão a dificuldade mais alta que ele tem).
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
	var choice := InstrumentRules.choose(available, instrument, difficulty)
	instrument = choice[0]
	difficulty = choice[1]

	session = PlaySession.new(_loaded["chart"], instrument, difficulty)
	App.pause_worker(true)
	_grid = (
		BeatGrid.from_beatmap(_loaded["beatmap"])
		if not _loaded["beatmap"].get("beats", []).is_empty()
		else BeatGrid.from_tempo(session.tempo, session.duration)
	)
	highway.setup(session)
	hud.setup(_loaded["song"], instrument, difficulty)
	_setup_audio(instrument)


func _exit_tree() -> void:
	if session:
		App.pause_worker(false)


## Sai da partida: para a escolha de música (vindo do menu) ou fecha o jogo (cena sozinha).
func leave() -> void:
	if not App.selection.is_empty():
		App.goto(App.SONG_SELECT)
	elif App.live:  # nos testes, fechar o jogo fecharia o executor de testes
		get_tree().quit()


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
	var bus := AudioServer.get_bus_index(MUSIC_BUS)
	if bus >= 0:  # o analisador de espectro do fundo fica no bus Music (default_bus_layout.tres)
		player.bus = MUSIC_BUS
		_spectrum = AudioServer.get_bus_effect_instance(bus, 0)
	add_child(player)


func _process(delta: float) -> void:
	if session == null or _done or paused:
		return
	var now := _song_time(delta)
	if _autoplay:
		_play_by_itself(now)
	var events := session.update(now, delta)
	if not events["missed"].is_empty() and sfx:
		sfx.play_miss()
	for note: PlayNote in events["missed"]:
		highway.on_miss(note)
	if _stem_index >= 0:
		player.stream.set_sync_stream_volume(_stem_index, events["volume_db"])
	highway.update_view(now, _grid)
	background.update(now, _grid, _bands.update(_magnitudes(), delta))
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


## Pausa: para o áudio e o relógio (o _process não anda), solta os trastes (soltar uma tecla
## com o jogo pausado não chegaria à partida) e mostra Continuar / Recomeçar / Sair.
func set_paused(value: bool) -> void:
	if session == null or _done or value == paused:
		return
	paused = value
	if player:
		player.stream_paused = value
	for lane in session.held.duplicate():
		session.release_fret(lane)
		highway.set_fret(lane, false)
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
	if session == null or _done or paused or event.is_echo():
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
			if InputProfile.FRET_TAPS:
				var tapped := session.tap(now)
				if not tapped.is_empty():
					highway.on_strum(tapped)
		elif event.is_action_released(InputProfile.FRETS[lane]):
			session.release_fret(lane)
			highway.set_fret(lane, false)
	if InputProfile.FRET_TAPS:
		return  # sem palhetada: depois de um acerto no traste, ela viraria overstrum
	for action: String in InputProfile.STRUM:
		if event.is_action_pressed(action):
			var result := session.strum(now)
			highway.on_strum(result)
			if result.get("grade") == Judge.OVERSTRUM and sfx:
				sfx.play_error()


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
