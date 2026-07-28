class_name TestLevelManager
extends GdUnitTestSuite

## LevelManager 数据与状态测试

func test_has_seven_levels() -> void:
	# 7 关基础 + 5 关 P2-4 新增 = 12 关
	assert_int(LevelManager.levels.size()).is_equal(12)

func test_level_ids_sequential() -> void:
	for i in range(LevelManager.levels.size()):
		assert_int(LevelManager.levels[i].id).is_equal(i)

func test_every_level_has_required_fields() -> void:
	for ld in LevelManager.levels:
		assert_str(ld.title).is_not_empty()
		assert_str(ld.python_knowledge).is_not_empty()
		assert_str(ld.prompt).is_not_empty()
		assert_str(ld.starter_code).is_not_empty()
		assert_str(ld.expected_output).is_not_empty()
		assert_str(ld.hint).is_not_empty()

func test_complete_and_get_count() -> void:
	LevelManager.reset_progress()
	assert_int(LevelManager.get_completed_count()).is_equal(0)
	LevelManager.complete_level(0)
	assert_int(LevelManager.get_completed_count()).is_equal(1)
	LevelManager.complete_level(0)  # 重复 id 不重复计
	assert_int(LevelManager.get_completed_count()).is_equal(1)
	LevelManager.complete_level(3)
	assert_int(LevelManager.get_completed_count()).is_equal(2)

func test_reset_clears_progress() -> void:
	LevelManager.complete_level(1)
	LevelManager.complete_level(2)
	LevelManager.reset_progress()
	assert_int(LevelManager.get_completed_count()).is_equal(0)
	assert_int(LevelManager.current_level).is_equal(0)
	assert_int(LevelManager.completed_levels.size()).is_equal(0)

func test_chapters_progressive() -> void:
	# 7 关分 4 章，难度递进
	var chapters := []
	for ld in LevelManager.levels:
		if chapters.is_empty() or chapters[chapters.size() - 1] != ld.chapter:
			chapters.append(ld.chapter)
	# 至少 3 个不同章节
	assert_bool(chapters.size() >= 3).is_true()
