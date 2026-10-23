extends GdUnitTestSuite


func test_parses_contract_messages() -> void:
	var msg := BackendMessage.parse('{"type": "done", "count": 2, "errors": []}\n')
	assert_int(int(msg["count"])).is_equal(2)
	msg = BackendMessage.parse(
		'{"type": "progress", "phase": "copying", "done": 1, "total": 2, "fraction": 0.5}'
	)
	assert_float(msg["fraction"]).is_equal(0.5)


func test_rejects_unknown_or_incomplete() -> void:
	assert_dict(BackendMessage.parse('{"type": "done", "count": 2}')).is_empty()
	assert_dict(BackendMessage.parse('{"type": "queued", "id": "x", "label": "y"}')).is_empty()
	assert_dict(BackendMessage.parse("2026-10-22 log no lugar errado")).is_empty()
	assert_dict(BackendMessage.parse("")).is_empty()


func test_line_buffer_joins_chunks() -> void:
	var buffer := BackendMessage.LineBuffer.new()
	assert_array(buffer.feed('{"type": "er')).is_empty()
	var lines := buffer.feed('ror", "message": "x"}\n{"type"')
	assert_array(lines).has_size(1)
	assert_str(BackendMessage.parse(lines[0])["message"]).is_equal("x")
	assert_array(buffer.feed(': "done", "count": 0, "errors": []}\n')).has_size(1)


func test_protocol_matches_backend_version() -> void:
	assert_int(BackendProtocol.FORMAT_VERSION).is_equal(1)
	assert_bool(BackendProtocol.EVENTS.has("progress")).is_true()
