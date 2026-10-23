## Ticks ↔ segundos a partir das marcas de andamento do .chart ("B" em milésimos de BPM).
##
## Mesma regra do backend (pbq/charts/tempo.py): o início de cada trecho é acumulado com os BPMs já
## arredondados, então jogo e backend concordam até o fim da música.
class_name TempoMap
extends RefCounted

var resolution: int
var _ticks: PackedInt64Array = []
var _bpms: PackedFloat64Array = []
var _starts: PackedFloat64Array = []


## `tempos`: [[tick, milli_bpm], ...] em ordem, começando no tick 0.
func _init(tempos: Array, chart_resolution: int = 192) -> void:
	resolution = chart_resolution
	if tempos.is_empty() or int(tempos[0][0]) != 0:
		tempos = [[0, 120000]] + tempos  # chart sem andamento no 0: o padrão do Clone Hero
	for i in tempos.size():
		var tick := int(tempos[i][0])
		var bpm := float(tempos[i][1]) / 1000.0
		var start := 0.0
		if i > 0:
			start = _starts[i - 1] + _seconds(tick - _ticks[i - 1], _bpms[i - 1])
		_ticks.append(tick)
		_bpms.append(bpm)
		_starts.append(start)


func _seconds(ticks: float, bpm: float) -> float:
	return ticks / resolution * 60.0 / bpm


func _index_for_tick(tick: float) -> int:
	var i := _ticks.bsearch(int(floor(tick)), false) - 1
	return clampi(i, 0, _ticks.size() - 1)


func time(tick: float) -> float:
	var i := _index_for_tick(tick)
	return _starts[i] + _seconds(tick - _ticks[i], _bpms[i])


func tick(seconds: float) -> float:
	var i := _starts.bsearch(seconds, false) - 1
	i = clampi(i, 0, _starts.size() - 1)
	return _ticks[i] + (seconds - _starts[i]) * _bpms[i] / 60.0 * resolution


func bpm_at(seconds: float) -> float:
	var i := clampi(_starts.bsearch(seconds, false) - 1, 0, _starts.size() - 1)
	return _bpms[i]
