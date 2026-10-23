## Trilha do chart (ChartParser) → notas jogáveis (PlayNote), em ordem de tempo.
##
## Cordas e baixo: as notas do mesmo tick são um acorde (uma PlayNote com vários trastes).
## Bateria: cada peça é uma PlayNote (os pads são julgados um a um); as marcas 66/67/68 do .chart
## dizem que a peça amarela/azul/verde é prato.
class_name NoteTrack
extends RefCounted

const FRET_LANES := 5
const CYMBAL_FLAGS := {66: 2, 67: 3, 68: 4}


static func build(
	chart: Dictionary, track: String, tempo: TempoMap, drums: bool
) -> Array[PlayNote]:
	var by_tick := {}
	var cymbals := {}
	for raw: Array in chart["tracks"].get(track, []):
		var tick := int(raw[0])
		var lane := int(raw[1])
		if drums and CYMBAL_FLAGS.has(lane):
			cymbals[[tick, CYMBAL_FLAGS[lane]]] = true
			continue
		if lane >= FRET_LANES:
			continue  # notas abertas, marcas de outros jogos: fora do nosso esquema de 5 lanes
		if not by_tick.has(tick):
			by_tick[tick] = {"lanes": PackedInt32Array(), "length": 0}
		by_tick[tick]["lanes"].append(lane)
		by_tick[tick]["length"] = maxi(by_tick[tick]["length"], int(raw[2]))

	var ticks := by_tick.keys()
	ticks.sort()
	var notes: Array[PlayNote] = []
	for tick: int in ticks:
		var entry: Dictionary = by_tick[tick]
		var lanes: PackedInt32Array = entry["lanes"]
		lanes.sort()
		var start := tempo.time(tick)
		var end := tempo.time(tick + entry["length"]) if entry["length"] > 0 else start
		if drums:
			for lane in lanes:
				var note := PlayNote.new(tick, start, PackedInt32Array([lane]))
				note.cymbal = cymbals.has([tick, lane])
				notes.append(note)
		else:
			notes.append(PlayNote.new(tick, start, lanes, end))
	return notes
