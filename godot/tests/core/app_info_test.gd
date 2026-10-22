extends GdUnitTestSuite


func test_name() -> void:
	assert_str(AppInfo.NAME).is_equal("Palheta & Baqueta")


func test_compatible_backend() -> void:
	assert_bool(AppInfo.backend_compatible('{"name": "pbq", "version": "0.1.0"}')).is_true()


func test_incompatible_backend() -> void:
	assert_bool(AppInfo.backend_compatible('{"name": "pbq", "version": "1.0.0"}')).is_false()
	assert_bool(AppInfo.backend_compatible('{"name": "outro", "version": "0.1.0"}')).is_false()
	assert_bool(AppInfo.backend_compatible('{"name": "pbq", "version": "x"}')).is_false()
	assert_bool(AppInfo.backend_compatible("não é json")).is_false()
	assert_bool(AppInfo.backend_compatible("[]")).is_false()
