extends GdUnitTestSuite

const PROGRESS := '{"type": "progress", "phase": "copying", "done": 1, "total": 2, "fraction": 0.5}'
const DONE := '{"type": "done", "count": 2, "errors": []}'


func test_job_streams_contract_messages_and_ends() -> void:
	var job := BackendJob.new()
	var seen: Array[Dictionary] = []
	job.message.connect(func(data: Dictionary) -> void: seen.append(data))
	var script := "echo '%s'; echo 'log solto'; echo '%s'" % [PROGRESS, DONE]
	assert_bool(job.start("/bin/sh", ["-c", script])).is_true()
	assert_bool(job.running).is_true()
	var result: Array = await job.finished
	assert_bool(result[0]).is_true()
	assert_str(result[1]["type"]).is_equal("done")
	(
		assert_array(seen.map(func(d: Dictionary) -> String: return d["type"]))
		. is_equal(["progress", "done"])
	)
	assert_bool(job.running).is_false()


func test_job_failure_and_missing_program() -> void:
	var job := BackendJob.new()
	job.start("/bin/sh", ["-c", 'echo \'{"type": "error", "message": "sem espaço"}\'; exit 1'])
	var result: Array = await job.finished
	assert_bool(result[0]).is_false()
	assert_str(result[1]["message"]).is_equal("sem espaço")
	var missing := BackendJob.new()  # o Godot inicia o processo; o exec falha lá dentro
	if missing.start("/nao/existe", []):
		assert_bool((await missing.finished)[0]).is_false()


func test_app_is_safe_under_tests() -> void:
	assert_bool(App.backend_enabled).is_false()
	assert_object(App.run_pbq(["drive", "list"])).is_null()
	App.start_worker()
	App.pause_worker(true)
	assert_str(App.library_dir).ends_with("data/library")


func test_worker_pid_ignores_stale_lock() -> void:
	var saved := App.data_dir
	App.data_dir = create_temp_dir("dados")
	assert_int(App.worker_pid()).is_equal(-1)
	var lock := FileAccess.open(App.data_dir.path_join(App.WORKER_LOCK), FileAccess.WRITE)
	lock.store_string("%d\n" % OS.get_process_id())  # o próprio Godot: não é um pbq
	lock.close()
	assert_int(App.worker_pid()).is_equal(-1)
	App.data_dir = saved
