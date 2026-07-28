class_name TestAllLevels
extends GdUnitTestSuite

## 验证 LevelManager 中每关的示例代码（参考答案）都能产出 expected_output
## 这是端到端测试：关卡设计 + MiniPython 解释器 + expected_output 三者一致

var _interp

func before_test() -> void:
	_interp = load("res://scripts/MiniPythonInterpreter.gd").new()

# 每关的"参考答案"，对应 expected_output
const SOLUTIONS := {
	0: 'print("前进")',
	1: 'password = 42\nprint(password)',
	2: 'road = "左"\nif road == "左":\n    print("走左边")\nelse:\n    print("走右边")',
	3: 'for i in range(5):\n    print("捡金币")',
	4: 'count = 1\nwhile count <= 10:\n    print(count)\n    count = count + 1',
	5: 'treasures = ["金币", "宝石", "钥匙"]\nfor t in treasures:\n    print(t)',
	6: 'def attack(power):\n    print("造成", power, "点伤害")\nattack(10)\nattack(10)\nattack(10)',
	7: 'monster = {"name": "哥布林", "hp": 50}\nprint(monster["name"], monster["hp"])',
	8: 'hero = {"hp": 100, "mp": 30}\nprint(hero.get("hp"), hero.get("atk", 5))',
	9: 'spell = "fireball"\nprint(spell.upper())',
	10: 'spell = "flame wind ice"\nfor word in spell.split(" "):\n    print(word)',
	11: 'text = "the cat sat on the mat"\ncounts = {}\nfor word in text.split(" "):\n    if word in counts:\n        counts[word] = counts[word] + 1\n    else:\n        counts[word] = 1\nprint(counts["the"])',
}

func test_all_levels_solvable() -> void:
	var failures: Array = []
	for ld in LevelManager.levels:
		var id: int = ld.id
		var solution: String = SOLUTIONS.get(id, "")
		if solution == "":
			failures.append("关 %d 没有参考答案" % id)
			continue
		var r: Dictionary = _interp.execute(solution)
		var got: String = r["output"]
		if got.ends_with("\n"):
			got = got.substr(0, got.length() - 1)
		if r["error"] != "":
			failures.append("关 %d 执行错误: %s" % [id, r["error"]])
		elif got != ld.expected_output:
			failures.append("关 %d 输出不匹配\n  expected: %s\n  got:      %s" % [id, ld.expected_output.replace("\n", "\\n"), got.replace("\n", "\\n")])
	# 任一失败则 fail
	if not failures.is_empty():
		var msg: String = "\n".join(failures)
		assert_bool(false).is_true()  # 强制 fail
		push_error(msg)
	else:
		assert_bool(true).is_true()

func test_levels_count_is_12() -> void:
	assert_int(LevelManager.levels.size()).is_equal(12)

func test_new_chapters_exist() -> void:
	var chapters := []
	for ld in LevelManager.levels:
		if chapters.is_empty() or chapters[chapters.size() - 1] != ld.chapter:
			chapters.append(ld.chapter)
	# 现在 7 章：森林入门/迷宫探险/宝藏猎人/怪物战斗/古堡谜题/龙之挑战/终极挑战
	assert_int(chapters.size()).is_equal(7)
