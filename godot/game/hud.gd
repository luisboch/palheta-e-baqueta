## Placar na tela: música, instrumento, pontos, multiplicador, sequência e o resultado final.
class_name Hud
extends CanvasLayer

## Botões do resultado: jogar a mesma música de novo, ou voltar para a escolha.
signal again
signal choose_song

@onready var _title: Label = $Title
@onready var _score: Label = $Score
@onready var _center: Label = $Center
@onready var _results: PanelContainer = %Results


func _ready() -> void:
	%Again.pressed.connect(again.emit)
	%Choose.pressed.connect(choose_song.emit)


func setup(song: Dictionary, instrument: String, difficulty: String) -> void:
	_title.text = (
		"%s — %s\n%s · %s"
		% [
			song.get("title", "?"),
			song.get("artist", "") if song.get("artist") else "Artista desconhecido",
			SongCatalog.INSTRUMENT_NAMES.get(instrument, instrument),
			SongCatalog.DIFFICULTY_NAMES.get(difficulty, difficulty),
		]
	)
	_score.position.y = 100


func update_score(scoring: Scoring) -> void:
	_score.text = (
		"%d pontos   %d×   sequência %d" % [scoring.score, scoring.multiplier(), scoring.streak]
	)


func show_message(text: String) -> void:
	_title.text = ""  # tira o texto de exemplo da cena (o que o editor mostra)
	_score.text = ""
	_center.text = text


func show_results(scoring: Scoring) -> void:
	%Points.text = "%d pontos" % scoring.score
	%Accuracy.text = (
		"Acertos: %d de %d (%d%%)"
		% [scoring.hits, scoring.hits + scoring.misses, roundi(scoring.accuracy() * 100)]
	)
	%BestStreak.text = "Maior sequência: %d" % scoring.best_streak
	_results.visible = true
	%Again.grab_focus()
