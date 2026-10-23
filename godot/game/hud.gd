## Placar na tela: música, instrumento, pontos, multiplicador, sequência e o resultado final.
## Suporta modo solo, cooperativo (Banda) e batalha (Duelo).
class_name Hud
extends CanvasLayer

## Botões do resultado: jogar a mesma música de novo, ou voltar para a escolha.
signal again
signal choose_song
## Botões da pausa (Recomeçar usa `again`; Sair da música, `choose_song`).
signal resume

const STAR_ON := "★"
const STAR_OFF := "☆"
const MODE_NAMES := {"coop": "Banda", "versus": "Duelo"}

var play_mode := "solo"
var _players: Array[String] = []  ## "Cordas · Difícil" de cada jogador, para as sequências
var _instruments: Array[String] = []  ## "Cordas" de cada jogador, para o resultado
var _combos: Array[Label3D] = []

@onready var _title: Label = $Title
@onready var _score: Label = $Score
@onready var _center: Label = $Center
@onready var _results: PanelContainer = %Results


func _ready() -> void:
	%Again.pressed.connect(again.emit)
	%Choose.pressed.connect(choose_song.emit)
	%Resume.pressed.connect(resume.emit)
	%Restart.pressed.connect(again.emit)
	%QuitSong.pressed.connect(choose_song.emit)


func show_pause(visible_now: bool) -> void:
	%Pause.visible = visible_now
	if visible_now:
		%Resume.grab_focus()


## Solo: título, instrumento e placar. 2 jogadores (`mode` "coop" ou "versus"): placar da Banda ou
## do Duelo no centro e a sequência de cada um sobre a própria pista (`combos`, da Highway).
func setup(
	song: Dictionary,
	instrument: String,
	difficulty: String,
	mode := "solo",
	instrument_2 := "",
	difficulty_2 := "",
	combos: Array[Label3D] = []
) -> void:
	play_mode = mode if instrument_2 != "" else "solo"
	_players = [_player_name(instrument, difficulty)]
	_instruments = [SongCatalog.INSTRUMENT_NAMES.get(instrument, instrument)]
	var heading := (
		"%s — %s"
		% [
			song.get("title", "?"),
			song.get("artist", "") if song.get("artist") else "Artista desconhecido",
		]
	)
	var two := play_mode != "solo"
	_score.visible = not two
	%Band.visible = play_mode == "coop"
	%Duel.visible = play_mode == "versus"
	if not two:
		_title.text = "%s\n%s" % [heading, _players[0]]
		_score.position.y = 100
		return
	_players.append(_player_name(instrument_2, difficulty_2))
	_instruments.append(SongCatalog.INSTRUMENT_NAMES.get(instrument_2, instrument_2))
	_title.text = "%s\n%s" % [heading, MODE_NAMES.get(play_mode, play_mode)]
	_combos = combos
	for combo in _combos:
		combo.visible = true


func update_score(scoring: Scoring, scoring_2: Scoring = null) -> void:
	if scoring_2 == null:
		_score.text = (
			"%d pontos   %d×   sequência %d" % [scoring.score, scoring.multiplier(), scoring.streak]
		)
		return
	var both: Array[Scoring] = [scoring, scoring_2]
	for i in mini(_combos.size(), both.size()):
		_combos[i].text = (
			"P%d · %s\n%d seguidas · %d×"
			% [i + 1, _players[i], both[i].streak, both[i].multiplier()]
		)
	if play_mode == "coop":
		%Band.text = (
			"BANDA\n%d pontos · %d×"
			% [
				MatchResult.band_score(scoring, scoring_2),
				MatchResult.band_multiplier(scoring, scoring_2),
			]
		)
		return
	%DuelP1.text = "P1  %d" % scoring.score
	%DuelP2.text = "%d  P2" % scoring_2.score
	%Lead.text = ["empate", "◄ na frente", "na frente ►"][MatchResult.leader(scoring, scoring_2)]


func show_message(text: String) -> void:
	_title.text = ""  # tira o texto de exemplo da cena (o que o editor mostra)
	_score.text = ""
	_center.text = text


func show_results(scoring: Scoring, scoring_2: Scoring = null) -> void:
	%Band.visible = false  # o resultado repete o placar, e o painel ficaria por cima dele
	%Duel.visible = false
	%Stars.visible = scoring_2 != null and play_mode == "coop"
	%Detail.visible = scoring_2 != null
	if scoring_2 == null:
		%Header.text = "Fim!"
		%Points.text = "%d pontos" % scoring.score
		%Accuracy.text = (
			"Acertos: %d de %d (%d%%)"
			% [scoring.hits, scoring.hits + scoring.misses, _percent(scoring.accuracy())]
		)
		%BestStreak.text = "Maior sequência: %d" % scoring.best_streak
	elif play_mode == "coop":
		var stars := MatchResult.stars(MatchResult.band_accuracy(scoring, scoring_2))
		var share := MatchResult.contributions(scoring, scoring_2)
		%Header.text = "Fim do show da Banda!"
		%Stars.text = STAR_ON.repeat(stars) + STAR_OFF.repeat(MatchResult.MAX_STARS - stars)
		%Points.text = "%d pontos" % MatchResult.band_score(scoring, scoring_2)
		%Accuracy.text = _contribution(0, scoring, share[0])
		%Detail.text = _contribution(1, scoring_2, share[1])
		%BestStreak.text = (
			"Maior sequência: P1 %d · P2 %d" % [scoring.best_streak, scoring_2.best_streak]
		)
	else:
		%Header.text = ["EMPATE!", "P1 VENCEU!", "P2 VENCEU!"][MatchResult.winner(
			scoring, scoring_2
		)]
		%Points.text = "P1  %d  ×  %d  P2" % [scoring.score, scoring_2.score]
		%Accuracy.text = (
			"Precisão: %d%%  ×  %d%%"
			% [_percent(scoring.accuracy()), _percent(scoring_2.accuracy())]
		)
		%Detail.text = (
			"Notas: %d de %d  ×  %d de %d"
			% [
				scoring.hits,
				scoring.hits + scoring.misses,
				scoring_2.hits,
				scoring_2.hits + scoring_2.misses,
			]
		)
		%BestStreak.text = (
			"Maior sequência: %d  ×  %d" % [scoring.best_streak, scoring_2.best_streak]
		)
	_results.visible = true
	%Again.grab_focus()


## Linha de um jogador no resultado da Banda: pontos, parte da Banda (%) e precisão.
func _contribution(index: int, scoring: Scoring, share: float) -> String:
	return (
		"P%d · %s: %d pontos (%d%%) · acerto %d%%"
		% [
			index + 1,
			_instruments[index],
			scoring.score,
			_percent(share),
			_percent(scoring.accuracy())
		]
	)


static func _player_name(instrument: String, difficulty: String) -> String:
	return (
		"%s · %s"
		% [
			SongCatalog.INSTRUMENT_NAMES.get(instrument, instrument),
			SongCatalog.DIFFICULTY_NAMES.get(difficulty, difficulty),
		]
	)


static func _percent(fraction: float) -> int:
	return roundi(fraction * 100)
