extends Node

## Python 代码执行器（Autoload 单例）
## 双 backend：
##   1. MiniPython（内置 GDScript 解释器）——零依赖、跨平台、覆盖教学子集
##   2. 系统 python3（仅桌面，OS.execute 子进程）——支持完整 Python
## 策略：桌面端优先用系统 python3（若可用），失败/不存在则回退 MiniPython；
##       移动端/Web 直接用 MiniPython。

signal execution_finished(output: String, success: bool)

const MINIPY_SCRIPT := preload("res://scripts/MiniPythonInterpreter.gd")

var _minipy: Object = null
var _python3_available: bool = false
var _use_real_python: bool = false

func _ready() -> void:
	_minipy = MINIPY_SCRIPT.new()
	# 仅桌面平台尝试用系统 python3
	var platform := OS.get_name()
	if platform == "macOS" or platform == "Windows" or platform == "Linux":
		_python3_available = _detect_python3()
		_use_real_python = _python3_available
	else:
		# Android / iOS / Web
		_python3_available = false
		_use_real_python = false

## 检测系统 python3 是否可用
func _detect_python3() -> bool:
	var out: Array = []
	# 优先 python3，再尝试 python
	var ec := OS.execute("python3", ["--version"], out, true)
	if ec == 0:
		return true
	ec = OS.execute("python", ["--version"], out, true)
	return ec == 0

## 切换 backend（设置页可调）
func set_use_real_python(v: bool) -> void:
	if v and not _python3_available:
		push_warning("系统 python3 不可用，仍使用内置解释器")
		_use_real_python = false
	else:
		_use_real_python = v

func is_real_python_available() -> bool:
	return _python3_available

func is_using_real_python() -> bool:
	return _use_real_python

## 执行玩家代码（异步信号 execution_finished）
func execute_code(code: String) -> void:
	if _use_real_python and _python3_available:
		var r: Dictionary = _exec_with_python3(code)
		if r["fallback"]:
			# 系统 python3 失败，回退内置
			var r2: Dictionary = _exec_with_minipy(code)
			execution_finished.emit(r2["output"], r2["success"])
		else:
			execution_finished.emit(r["output"], r["success"])
	else:
		var r3: Dictionary = _exec_with_minipy(code)
		execution_finished.emit(r3["output"], r3["success"])

## 用系统 python3 执行
func _exec_with_python3(code: String) -> Dictionary:
	var tmp_path := "user://code_quest_player.py"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		return {"output": "无法写入临时文件", "success": false, "fallback": true}
	file.store_string(code)
	file.close()
	var abs_path := ProjectSettings.globalize_path(tmp_path)
	var out: Array = []
	var exit_code := OS.execute("python3", [abs_path], out, true)
	if exit_code == -1:
		# 命令不存在或失败
		return {"output": "", "success": false, "fallback": true}
	var result := "\n".join(out)
	return {"output": result, "success": exit_code == 0, "fallback": false}

## 用内置解释器执行
func _exec_with_minipy(code: String) -> Dictionary:
	var r: Dictionary = _minipy.execute(code)
	if r["error"] != "":
		return {"output": r["error"] + "\n（行 " + str(r["line"]) + "）", "success": false}
	return {"output": r["output"], "success": true}

## 检查输出是否匹配期望
func check_output(actual: String, expected: String) -> bool:
	var actual_lines := actual.strip_edges().split("\n")
	var expected_lines := expected.strip_edges().split("\n")
	if actual_lines.size() != expected_lines.size():
		return false
	for i in range(actual_lines.size()):
		if actual_lines[i].strip_edges() != expected_lines[i].strip_edges():
			return false
	return true

## 检查代码是否包含指定关键字（用于教学模式）
func check_keyword(code: String, keyword: String) -> bool:
	return keyword in code

## 静态检查：代码是否有基本语法错误
func quick_syntax_check(code: String) -> String:
	var lines := code.split("\n")
	for i in range(lines.size()):
		var line := lines[i]
		if line.strip_edges() == "":
			continue
		if line.strip_edges().ends_with(":"):
			if i + 1 < lines.size():
				var next_line := lines[i + 1]
				if next_line.strip_edges() != "" and not next_line.begins_with(" ") and not next_line.begins_with("\t"):
					return "第 " + str(i + 2) + " 行：冒号后面需要缩进"
	return ""
