extends GdUnitTestSuite

var _path: String


func before_test() -> void:
	_path = create_temp_dir("events").path_join("events.jsonl")


func _append(text: String) -> void:
	var mode := FileAccess.READ_WRITE if FileAccess.file_exists(_path) else FileAccess.WRITE
	var file := FileAccess.open(_path, mode)
	file.seek_end()
	file.store_string(text)
	file.close()


func test_starts_at_end_and_reads_new_events() -> void:
	_append('{"type": "queue", "pending": 1}\n')
	var reader := EventReader.new(_path)
	assert_array(reader.poll()).is_empty()
	_append('{"type": "ready", "id": "x", "label": "A - B"}\n')
	var events := reader.poll()
	assert_int(events.size()).is_equal(1)
	assert_str(events[0]["label"]).is_equal("A - B")
	assert_array(reader.poll()).is_empty()


func test_partial_line_waits_for_the_rest() -> void:
	var reader := EventReader.new(_path)
	_append('{"type": "queue", "pend')
	assert_array(reader.poll()).is_empty()
	_append('ing": 3}\n')
	assert_int(int(reader.poll()[0]["pending"])).is_equal(3)


func test_utf8_split_between_reads() -> void:
	var reader := EventReader.new(_path)
	var line := '{"type": "ready", "id": "x", "label": "Canção"}\n'.to_utf8_buffer()
	var cut := line.find(0xC3) + 1  # no meio do "ç"
	var file := FileAccess.open(_path, FileAccess.WRITE)
	file.store_buffer(line.slice(0, cut))
	file.close()
	assert_array(reader.poll()).is_empty()
	file = FileAccess.open(_path, FileAccess.READ_WRITE)
	file.seek_end()
	file.store_buffer(line.slice(cut))
	file.close()
	assert_str(reader.poll()[0]["label"]).is_equal("Canção")


func test_ignores_lines_outside_contract() -> void:
	var reader := EventReader.new(_path)
	_append('não é json\n{"type": "inventado"}\n{"type": "ready", "id": "x"}\n[]\n')
	_append('{"type": "queue", "pending": 0}\n')
	var events := reader.poll()
	assert_int(events.size()).is_equal(1)
	assert_str(events[0]["type"]).is_equal("queue")


func test_restarts_when_file_is_emptied() -> void:
	_append('{"type": "queue", "pending": 1}\n{"type": "queue", "pending": 2}\n')
	var reader := EventReader.new(_path)
	var file := FileAccess.open(_path, FileAccess.WRITE)  # rotate do worker
	file.store_string('{"type": "queue", "pending": 9}\n')
	file.close()
	assert_int(int(reader.poll()[0]["pending"])).is_equal(9)


func test_missing_file() -> void:
	var reader := EventReader.new(_path.get_base_dir().path_join("nao-existe.jsonl"))
	assert_array(reader.poll()).is_empty()
