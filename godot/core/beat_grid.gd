## As batidas da música (beatmap.json): pulso para o fundo e linhas de compasso para a pista.
##
## Tempos em segundos desde o início do áudio, o mesmo relógio das notas (tick 0 = áudio 0).
class_name BeatGrid
extends RefCounted

## Fração do intervalo entre batidas em que o pulso cai de 1 para ~0 (curva exponencial).
const PULSE_DECAY := 0.35
const DEFAULT_BEATS_PER_BAR := 4  ## sem downbeats (chart sem beatmap): compasso de 4

var beats: PackedFloat64Array = []
var _downbeats := {}  ## índice da batida → true
var _bar_starts: PackedFloat64Array = []  ## tempos dos downbeats, para contar compassos


## `beatmap`: o dicionário do beatmap.json ({beats, downbeats}).
static func from_beatmap(beatmap: Dictionary) -> BeatGrid:
	var grid := BeatGrid.new()
	for t: float in beatmap.get("beats", []):
		grid.beats.append(t)
	var index := {}
	for i in grid.beats.size():
		index[snappedf(grid.beats[i], 0.0001)] = i
	for t: float in beatmap.get("downbeats", []):
		var i: Variant = index.get(snappedf(t, 0.0001))
		if i != null:
			grid._downbeats[i] = true
	grid._index_bars()
	return grid


## Sem beatmap: uma batida a cada semínima do mapa de tempo, compasso de 4, até `duration`.
static func from_tempo(tempo: TempoMap, duration: float) -> BeatGrid:
	var grid := BeatGrid.new()
	var k := 0
	while true:
		var t := tempo.time(k * tempo.resolution)
		if t > duration:
			break
		grid.beats.append(t)
		if k % DEFAULT_BEATS_PER_BAR == 0:
			grid._downbeats[k] = true
		k += 1
	grid._index_bars()
	return grid


func is_downbeat(index: int) -> bool:
	return _downbeats.has(index)


## Índice da última batida em ou antes de `now`; -1 antes da primeira.
func index_at(now: float) -> int:
	return beats.bsearch(now, false) - 1


## Quanto da batida atual já passou (0 na batida, perto de 1 antes da próxima); -1 antes da
## primeira.
func phase(now: float) -> float:
	var i := index_at(now)
	if i < 0:
		return -1.0
	var interval := beats[i + 1] - beats[i] if i + 1 < beats.size() else _last_interval()
	return (now - beats[i]) / maxf(interval, 0.001)


## 1 no instante da batida, caindo até perto de 0 antes da próxima. Downbeat: o dobro.
## 0 antes da primeira batida.
func pulse(now: float) -> float:
	var p := phase(now)
	if p < 0.0:
		return 0.0
	var value := exp(-p / PULSE_DECAY * 3.0)
	return value * (2.0 if is_downbeat(index_at(now)) else 1.0)


## Compasso atual (0 = o do primeiro downbeat); -1 antes dele.
func bar_at(now: float) -> int:
	return _bar_starts.bsearch(now, false) - 1


## Batidas entre `from` e `to` (s), para desenhar: [[tempo, downbeat?], ...].
func between(from: float, to: float) -> Array:
	var out := []
	var i := maxi(beats.bsearch(from), 0)
	while i < beats.size() and beats[i] <= to:
		out.append([beats[i], is_downbeat(i)])
		i += 1
	return out


## Quanto do compasso atual já passou (0-1); -1 antes do primeiro. Último compasso: usa a
## duração do anterior.
func bar_phase(now: float) -> float:
	var bar := bar_at(now)
	if bar < 0:
		return -1.0
	var length := 0.0
	if bar + 1 < _bar_starts.size():
		length = _bar_starts[bar + 1] - _bar_starts[bar]
	elif bar > 0:
		length = _bar_starts[bar] - _bar_starts[bar - 1]
	return clampf((now - _bar_starts[bar]) / length, 0.0, 1.0) if length > 0.0 else 0.0


func _index_bars() -> void:
	var indexes := _downbeats.keys()
	indexes.sort()
	for i: int in indexes:
		_bar_starts.append(beats[i])


func _last_interval() -> float:
	return beats[-1] - beats[-2] if beats.size() >= 2 else 0.5
