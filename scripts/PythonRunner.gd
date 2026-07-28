extends Node

## Python 代码执行器
## 通过子进程调用系统 Python，执行玩家代码并返回输出

signal execution_finished(output: String, success: bool)

## 执行 Python 代码
func execute_code(code: String) -> void:
	# 写入临时文件（user:// 目录可读写）
	var tmp_path = "user://code_quest_player.py"
	var file = FileAccess.open(tmp_path, FileAccess.WRITE)
	if file:
		file.store_string(code)
		file.close()
	
	# 转成系统绝对路径供 python3 进程读取
	var abs_path = ProjectSettings.globalize_path(tmp_path)
	
	# 调用系统 Python 执行
	var output = []
	var exit_code = OS.execute("python3", [abs_path], output, true)
	
	var result = "\n".join(output)
	var success = (exit_code == 0)
	
	execution_finished.emit(result, success)

## 检查输出是否匹配期望
func check_output(actual: String, expected: String) -> bool:
	# 去除首尾空白，逐行比较
	var actual_lines = actual.strip_edges().split("\n")
	var expected_lines = expected.strip_edges().split("\n")
	
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
	# 检查缩进（Python 最常见的错误）
	var lines = code.split("\n")
	for i in range(lines.size()):
		var line = lines[i]
		if line.strip_edges() == "":
			continue
		# 检查以冒号结尾但下一行没有缩进
		if line.strip_edges().ends_with(":"):
			if i + 1 < lines.size():
				var next_line = lines[i + 1]
				if next_line.strip_edges() != "" and not next_line.begins_with(" ") and not next_line.begins_with("\t"):
					return "第 " + str(i + 2) + " 行：冒号后面需要缩进"
	
	return ""  # 无错误
