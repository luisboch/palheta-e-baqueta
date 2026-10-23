## Placar na tela: música, instrumento, pontos, multiplicador, sequência e o resultado final.
class_name Hud
extends CanvasLayer

const INSTRUMENT_NAMES := {"strings": "Cordas", "bass": "Baixo", "drums": "Bateria"}
const DIFFICULTY_NAMES := {
	"Easy": "Fácil", "Medium": "Médio", "Hard": "Difícil", "Expert": "Muito difícil"
}

@onready var _title: Label = $Title
@onready var _score: Label = $Score
@onready var _center: Label = $Center


func setup(song: Dictionary, instrument: String, difficulty: String) -> void:
	_title.text = (
		"%s — %s\n%s · %s"
		% [
			song.get("title", "?"),
			song.get("artist", "") if song.get("artist") else "Artista desconhecido",
			INSTRUMENT_NAMES.get(instrument, instrument),
			DIFFICULTY_NAMES.get(difficulty, difficulty),
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
	_center.text = (
		"Fim!\n%d pontos\nAcertos: %d de %d (%d%%)\nMaior sequência: %d\n\nEsc para sair"
		% [
			scoring.score,
			scoring.hits,
			scoring.hits + scoring.misses,
			roundi(scoring.accuracy() * 100),
			scoring.best_streak,
		]
	)
