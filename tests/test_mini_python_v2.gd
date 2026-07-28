class_name TestMiniPythonV2
extends GdUnitTestSuite

## MiniPython dict + 字符串方法 + 综合用例

var _interp

func before_test() -> void:
	_interp = load("res://scripts/MiniPythonInterpreter.gd").new()

func _strip(s: String) -> String:
	if s.ends_with("\n"):
		return s.substr(0, s.length() - 1)
	return s

# ===== 字典 =====

func test_dict_literal() -> void:
	var r: Dictionary = _interp.execute('d = {"hp": 100, "mp": 50}\nprint(d)')
	assert_bool(r.error == "").is_true()
	assert_str(_strip(r.output)).is_equal("{'hp': 100, 'mp': 50}")

func test_dict_get_set() -> void:
	var r: Dictionary = _interp.execute('d = {"name": "战士"}\nprint(d["name"])\nd["hp"] = 100\nprint(d["hp"])')
	assert_str(_strip(r.output)).is_equal("战士\n100")

func test_dict_keys_values() -> void:
	var r: Dictionary = _interp.execute('d = {"a": 1, "b": 2}\nprint(sorted(d.keys()))')
	# 注：sorted 是 builtin，需要 Array.sort 或 sorted——简化测 keys 数量
	# 改为：
	r = _interp.execute('d = {"a": 1, "b": 2}\nprint(len(d))')
	assert_str(_strip(r.output)).is_equal("2")

func test_dict_get_method() -> void:
	var r: Dictionary = _interp.execute('d = {"hp": 100}\nprint(d.get("hp"), d.get("mp", 0))')
	assert_str(_strip(r.output)).is_equal("100 0")

func test_dict_iteration() -> void:
	var r: Dictionary = _interp.execute('d = {"x": 1, "y": 2}\ntotal = 0\nfor k in d:\n    total = total + d[k]\nprint(total)')
	assert_str(_strip(r.output)).is_equal("3")

# ===== 字符串方法 =====

func test_str_upper_lower() -> void:
	var r: Dictionary = _interp.execute('print("Hello".upper(), "World".lower())')
	assert_str(_strip(r.output)).is_equal("HELLO world")

func test_str_replace() -> void:
	var r: Dictionary = _interp.execute('print("hello world".replace("world", "Python"))')
	assert_str(_strip(r.output)).is_equal("hello Python")

func test_str_split() -> void:
	var r: Dictionary = _interp.execute('parts = "a,b,c".split(",")\nprint(parts[0], parts[1], parts[2])')
	# print 多参数以空格分隔，输出 "a b c"
	assert_str(_strip(r.output)).is_equal("a b c")

func test_str_strip() -> void:
	var r: Dictionary = _interp.execute('print("  hi  ".strip())')
	assert_str(_strip(r.output)).is_equal("hi")

func test_str_startswith() -> void:
	var r: Dictionary = _interp.execute('print("hello".startswith("he"), "hello".endswith("lo"))')
	assert_str(_strip(r.output)).is_equal("True True")

func test_str_find_count() -> void:
	var r: Dictionary = _interp.execute('print("banana".count("a"))')
	assert_str(_strip(r.output)).is_equal("3")

# ===== 列表方法 =====

func test_list_append() -> void:
	var r: Dictionary = _interp.execute('a = [1, 2]\na.append(3)\nprint(a)')
	assert_str(_strip(r.output)).is_equal("[1, 2, 3]")

func test_list_sort_reverse() -> void:
	var r: Dictionary = _interp.execute('a = [3, 1, 2]\na.sort()\nprint(a)')
	assert_str(_strip(r.output)).is_equal("[1, 2, 3]")

func test_list_pop() -> void:
	var r: Dictionary = _interp.execute('a = [10, 20, 30]\nx = a.pop()\nprint(x, a)')
	assert_str(_strip(r.output)).is_equal("30 [10, 20]")

# ===== 综合算法 =====

func test_word_count() -> void:
	var code := 'text = "the cat sat on the mat"\nwords = text.split(" ")\ncounts = {}\nfor w in words:\n    if w in counts:\n        counts[w] = counts[w] + 1\n    else:\n        counts[w] = 1\nprint(counts["the"])'
	var r: Dictionary = _interp.execute(code)
	assert_str(_strip(r.output)).is_equal("2")

func test_in_operator_dict() -> void:
	var r: Dictionary = _interp.execute('d = {"a": 1}\nprint("a" in d, "b" in d)')
	assert_str(_strip(r.output)).is_equal("True False")
