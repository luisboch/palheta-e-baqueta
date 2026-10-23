## Lê o formato .chart do Clone Hero (o que pbq/charts/chart_file.py escreve).
##
## Resultado: um Dictionary com
##   name, artist, resolution, streams {MusicStream: "song.ogg", ...},
##   tempos [[tick, milli_bpm]], time_signatures [[tick, batidas]],
##   tracks {"ExpertDrums": [[tick, lane, duração], ...], ...}
## Linhas desconhecidas (eventos, star power, solos de charts de outros jogos) são ignoradas.
class_name ChartParser
extends RefCounted

const DEFAULT_RESOLUTION := 192
const META_SECTIONS := ["Song", "SyncTrack", "Events"]


static func parse(text: String) -> Dictionary:
	var sections := {}
	var current := ""
	for raw_line in text.split("\n"):
		var line := raw_line.strip_edges().trim_prefix("﻿")
		if line.begins_with("[") and line.ends_with("]"):
			current = line.substr(1, line.length() - 2)
			sections[current] = []
		elif current != "" and "=" in line:
			var key := line.get_slice("=", 0).strip_edges()
			var value := line.substr(line.find("=") + 1).strip_edges()
			sections[current].append([key, value])

	var song := {}
	for entry: Array in sections.get("Song", []):
		song[entry[0]] = str(entry[1]).trim_prefix('"').trim_suffix('"')
	var chart := {
		"name": song.get("Name", ""),
		"artist": song.get("Artist", ""),
		"resolution": int(song.get("Resolution", DEFAULT_RESOLUTION)),
		"streams": {},
		"tempos": [],
		"time_signatures": [],
		"tracks": {},
	}
	for key: String in song:
		if key.ends_with("Stream"):
			chart["streams"][key] = song[key]

	for entry: Array in sections.get("SyncTrack", []):
		var parts := str(entry[1]).split(" ", false)
		if parts.size() < 2 or not str(entry[0]).is_valid_int():
			continue
		if parts[0] == "B":
			chart["tempos"].append([int(entry[0]), int(parts[1])])
		elif parts[0] == "TS":
			chart["time_signatures"].append([int(entry[0]), int(parts[1])])

	for name: String in sections:
		if name in META_SECTIONS:
			continue
		var notes := []
		for entry: Array in sections[name]:
			var parts := str(entry[1]).split(" ", false)
			if parts.size() >= 2 and parts[0] == "N" and str(entry[0]).is_valid_int():
				var length := int(parts[2]) if parts.size() > 2 else 0
				notes.append([int(entry[0]), int(parts[1]), length])
		notes.sort_custom(func(a: Array, b: Array) -> bool: return a < b)
		chart["tracks"][name] = notes
	return chart
