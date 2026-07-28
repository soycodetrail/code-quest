extends CodeHighlighter

## Python 语法高亮器
## 给 CodeEdit 添加 Python 关键字、字符串、注释、数字的颜色
##
## 注意：Godot 4.7 的 CodeHighlighter._get_line_syntax_highlighting(line: int)
## 接收的是行号，需要自己通过持有 CodeEdit 引用来取文本。
## 但该回调不直接给文本，标准做法是用 _get_line_syntax_highlighting 时
## 通过 owner/get_parent 拿到 CodeEdit。

# 颜色定义
const COLOR_KEYWORD := Color(0.53, 0.67, 1.0)    # 蓝 - 关键字
const COLOR_STRING := Color(0.6, 0.9, 0.5)        # 绿 - 字符串
const COLOR_COMMENT := Color(0.45, 0.45, 0.5)     # 灰 - 注释
const COLOR_NUMBER := Color(0.95, 0.7, 0.3)       # 橙 - 数字
const COLOR_BUILTIN := Color(0.7, 0.5, 0.9)       # 紫 - 内置函数

const PYTHON_KEYWORDS := {
	"False": true, "None": true, "True": true, "and": true, "as": true,
	"assert": true, "async": true, "await": true, "break": true,
	"class": true, "continue": true, "def": true, "del": true,
	"elif": true, "else": true, "except": true, "finally": true,
	"for": true, "from": true, "global": true, "if": true,
	"import": true, "in": true, "is": true, "lambda": true,
	"nonlocal": true, "not": true, "or": true, "pass": true,
	"raise": true, "return": true, "try": true, "while": true,
	"with": true, "yield": true,
}

const PYTHON_BUILTINS := {
	"print": true, "input": true, "int": true, "str": true, "float": true,
	"len": true, "range": true, "list": true, "dict": true, "set": true,
	"tuple": true, "bool": true, "open": true, "type": true,
	"isinstance": true, "abs": true, "round": true, "min": true,
	"max": true, "sum": true, "sorted": true, "enumerate": true,
	"zip": true, "map": true, "filter": true, "format": true,
}

# 持有 CodeEdit 引用（在创建时由 GameScene 设置）
var _code_edit: CodeEdit = null

func set_code_edit(edit: CodeEdit) -> void:
	_code_edit = edit

func _get_line_syntax_highlighting(line: int) -> Dictionary:
	var color_map := {}
	if _code_edit == null:
		return color_map
	var line_text := _code_edit.get_line(line)
	var line_length := line_text.length()
	if line_length == 0:
		return color_map

	var pos := 0
	var in_string := false
	var string_char := ""

	while pos < line_length:
		var ch := line_text[pos]

		# 字符串内
		if in_string:
			color_map[pos] = {"color": COLOR_STRING}
			if ch == string_char:
				in_string = false
			pos += 1
			continue

		# 空白
		if ch == " " or ch == "\t":
			pos += 1
			continue

		# 注释（# 开头到行尾）
		if ch == "#":
			color_map[pos] = {"color": COLOR_COMMENT}
			return color_map

		# 字符串开始
		if ch == '"' or ch == "'":
			string_char = ch
			in_string = true
			color_map[pos] = {"color": COLOR_STRING}
			pos += 1
			continue

		# 数字
		if ch.is_valid_int() or (ch == "." and pos + 1 < line_length and line_text[pos + 1].is_valid_int()):
			var num_start := pos
			while pos < line_length and (line_text[pos].is_valid_int() or line_text[pos] == "."):
				pos += 1
			color_map[num_start] = {"color": COLOR_NUMBER}
			continue

		# 关键字/标识符
		if ch.is_valid_identifier():
			var word_start := pos
			while pos < line_length and (line_text[pos].is_valid_identifier() or line_text[pos].is_valid_int()):
				pos += 1
			var word := line_text.substr(word_start, pos - word_start)
			if PYTHON_KEYWORDS.has(word):
				color_map[word_start] = {"color": COLOR_KEYWORD}
			elif PYTHON_BUILTINS.has(word):
				color_map[word_start] = {"color": COLOR_BUILTIN}
			continue

		pos += 1

	return color_map
