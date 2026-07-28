class_name TestMiniPython
extends GdUnitTestSuite

## MiniPython 解释器单元测试
## 覆盖：词法、语法、语义、错误处理

var _interp

func before_test() -> void:
	_interp = load("res://scripts/MiniPythonInterpreter.gd").new()

# ===== 7 关回归（与官方 expected_output 严格一致）=====

func test_print_string() -> void:
	var r: Dictionary = _interp.execute('print("前进")')
	assert_str(r.output).starts_with("前进")
	assert_bool(r.error == "").is_true()

func test_variable_print() -> void:
	var r: Dictionary = _interp.execute('password = 42\nprint(password)')
	assert_str(_strip(r.output)).is_equal("42")

func test_if_else() -> void:
	var r: Dictionary = _interp.execute('road = "左"\nif road == "左":\n    print("走左边")\nelse:\n    print("走右边")')
	assert_str(_strip(r.output)).is_equal("走左边")

func test_for_range() -> void:
	var r: Dictionary = _interp.execute('for i in range(5):\n    print("捡金币")')
	assert_str(_strip(r.output)).is_equal("捡金币\n捡金币\n捡金币\n捡金币\n捡金币")

func test_while_counter() -> void:
	var r: Dictionary = _interp.execute('count = 1\nwhile count <= 10:\n    print(count)\n    count = count + 1')
	assert_str(_strip(r.output)).is_equal("1\n2\n3\n4\n5\n6\n7\n8\n9\n10")

func test_list_iteration() -> void:
	var r: Dictionary = _interp.execute('treasures = ["金币", "宝石", "钥匙"]\nfor t in treasures:\n    print(t)')
	assert_str(_strip(r.output)).is_equal("金币\n宝石\n钥匙")

func test_function_multi_args() -> void:
	var r: Dictionary = _interp.execute('def attack(power):\n    print("造成", power, "点伤害")\nattack(10)\nattack(10)\nattack(10)')
	assert_str(_strip(r.output)).is_equal("造成 10 点伤害\n造成 10 点伤害\n造成 10 点伤害")

# ===== 表达式语义 =====

func test_arithmetic() -> void:
	var cases := {
		"print(1 + 2)": "3",
		"print(10 - 4)": "6",
		"print(3 * 4)": "12",
		"print(15 // 4)": "3",
		"print(15 % 4)": "3",
		"print(2 ** 10)": "1024",
		"print(7 / 2)": "3.5",
	}
	for code in cases:
		var r: Dictionary = _interp.execute(code)
		assert_str(_strip(r.output)).is_equal(cases[code])

func test_string_concat() -> void:
	var r: Dictionary = _interp.execute('print("hello" + " " + "world")')
	assert_str(_strip(r.output)).is_equal("hello world")

func test_string_repeat() -> void:
	var r: Dictionary = _interp.execute('print("ab" * 3)')
	assert_str(_strip(r.output)).is_equal("ababab")

func test_comparison() -> void:
	var r: Dictionary = _interp.execute('print(1 < 2, 2 > 3, 2 == 2, 3 != 4)')
	assert_str(_strip(r.output)).is_equal("True False True True")

func test_logic_and_or_not() -> void:
	var r: Dictionary = _interp.execute('print(True and False, True or False, not False)')
	assert_str(_strip(r.output)).is_equal("False True True")

# ===== 索引与切片 =====

func test_negative_index() -> void:
	var r: Dictionary = _interp.execute('a = [10, 20, 30]\nprint(a[0], a[-1])')
	assert_str(_strip(r.output)).is_equal("10 30")

func test_slice() -> void:
	var r: Dictionary = _interp.execute('print("hello"[1:4])')
	assert_str(_strip(r.output)).is_equal("ell")

func test_slice_open_ended() -> void:
	var r: Dictionary = _interp.execute('print("hello"[:2], "hello"[3:])')
	assert_str(_strip(r.output)).is_equal("he lo")

# ===== 控制流 =====

func test_elif_chain() -> void:
	var code := 'x = 5\nif x < 0:\n    print("负")\nelif x == 0:\n    print("零")\nelse:\n    print("正")'
	var r: Dictionary = _interp.execute(code)
	assert_str(_strip(r.output)).is_equal("正")

func test_break_in_for() -> void:
	var code := 'for i in range(10):\n    if i == 3:\n        break\n    print(i)'
	var r: Dictionary = _interp.execute(code)
	assert_str(_strip(r.output)).is_equal("0\n1\n2")

func test_continue_in_for() -> void:
	var code := 'for i in range(5):\n    if i == 2:\n        continue\n    print(i)'
	var r: Dictionary = _interp.execute(code)
	assert_str(_strip(r.output)).is_equal("0\n1\n3\n4")

func test_nested_function() -> void:
	var code := 'def double(x):\n    return x * 2\nprint(double(5))'
	var r: Dictionary = _interp.execute(code)
	assert_str(_strip(r.output)).is_equal("10")

# ===== 内建函数 =====

func test_builtins() -> void:
	var r: Dictionary = _interp.execute('print(abs(-7), min(3, 1, 2), max([4, 9, 2]), sum([1, 2, 3]), len([1, 2, 3]))')
	assert_str(_strip(r.output)).is_equal("7 1 9 6 3")

func test_range_with_step() -> void:
	var r: Dictionary = _interp.execute('for i in range(0, 10, 3):\n    print(i)')
	assert_str(_strip(r.output)).is_equal("0\n3\n6\n9")

# ===== 错误处理 =====

func test_undefined_variable() -> void:
	var r: Dictionary = _interp.execute('print(y)')
	assert_str(r.error).contains("未定义")

func test_missing_colon() -> void:
	var r: Dictionary = _interp.execute('if x > 0\n    print(x)')
	assert_bool(r.error != "").is_true()

func test_bad_indent() -> void:
	var r: Dictionary = _interp.execute('if True:\nprint("x")')
	assert_bool(r.error != "").is_true()

func test_index_out_of_bounds() -> void:
	var r: Dictionary = _interp.execute('a = [1, 2]\nprint(a[10])')
	assert_str(r.error).contains("越界")

func test_infinite_loop_guard() -> void:
	var r: Dictionary = _interp.execute('i = 0\nwhile True:\n    i = i + 1')
	assert_str(r.error).contains("过多")

# ===== 工具 =====

func _strip(s: String) -> String:
	if s.ends_with("\n"):
		return s.substr(0, s.length() - 1)
	return s
