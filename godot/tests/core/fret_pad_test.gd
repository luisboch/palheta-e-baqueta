extends GdUnitTestSuite


func test_poll_reports_only_what_changed() -> void:
	var pad := FretPad.new()
	var change := pad.poll(PackedInt32Array([3, 1]))
	assert_array(change["pressed"]).is_equal(PackedInt32Array([1, 3]))
	assert_array(change["released"]).is_empty()
	change = pad.poll(PackedInt32Array([1, 3]))  # segurando: nada novo (o gatilho repete)
	assert_array(change["pressed"]).is_empty()
	assert_array(change["released"]).is_empty()
	change = pad.poll(PackedInt32Array([3, 2]))
	assert_array(change["pressed"]).is_equal(PackedInt32Array([2]))
	assert_array(change["released"]).is_equal(PackedInt32Array([1]))
	assert_array(pad.held).is_equal(PackedInt32Array([2, 3]))


func test_a_button_cannot_stay_stuck_without_the_device_saying_so() -> void:
	var pad := FretPad.new()
	pad.poll(PackedInt32Array([1]))
	assert_array(pad.poll(PackedInt32Array())["released"]).is_equal(PackedInt32Array([1]))
	assert_array(pad.held).is_empty()
	# apertar de novo conta como aperto novo
	assert_array(pad.poll(PackedInt32Array([1]))["pressed"]).is_equal(PackedInt32Array([1]))


func test_reset_takes_the_state_without_counting_presses() -> void:
	var pad := FretPad.new()
	pad.reset(PackedInt32Array([2]))
	assert_array(pad.held).is_equal(PackedInt32Array([2]))
	assert_array(pad.poll(PackedInt32Array([2]))["pressed"]).is_empty()
