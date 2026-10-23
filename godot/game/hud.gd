## Placar na tela: música, instrumento, pontos, multiplicador, sequência e o resultado final.
class_name Hud
extends CanvasLayer

const INSTRUMENT_NAMES := {"strings": "Cordas", "bass": "Baixo", "drums": "Bateria"}
const DIFFICULTY_NAMES := {
	"Easy": "Fácil", "Medium": "Médio", "Hard": "Difícil", "Expert": "Muito difícil"
}

var _title := Label.new()
var _score := Label.new()
var _center := Label.new()


func _ready() -> void:
	for label: Label in [_title, _score, _center]:
		label.add_theme_font_size_override("font_size", 28)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 6)
		add_child(label)
	_title.position = Vector2(24, 16)
	_score.position = Vector2(24, 64)
	_center.set_anchors_preset(Control.PRESET_CENTER)
	_center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center.add_theme_font_size_override("font_size", 40)


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
