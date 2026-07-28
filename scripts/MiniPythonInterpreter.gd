extends RefCounted

## MiniPython 解释器
## 用 GDScript 实现的 Python 教学子集解释器，零依赖、跨平台。
## 支持：字面量/变量/列表/算术/比较/逻辑/索引切片/print/if/elif/else/while/for/def/return
## 覆盖 Code Quest 全部 7 关。

# ===== 错误（运行时抛出，外层捕获）=====
class MPError:
	extends RefCounted
	var message: String
	var line: int
	func _init(msg: String, l: int = -1) -> void:
		message = msg
		line = l

# ===== Token =====
class Token:
	extends RefCounted
	var type: String
	var value: Variant
	var line: int
	func _init(t: String, v: Variant, l: int) -> void:
		type = t
		value = v
		line = l

const KEYWORDS := {
	"and": true, "or": true, "not": true,
	"if": true, "elif": true, "else": true,
	"while": true, "for": true, "in": true,
	"def": true, "return": true,
	"True": true, "False": true, "None": true,
	"break": true, "continue": true, "pass": true,
}

# ===== 词法 + 缩进（每行首插 BOLO）=====
func tokenize(source: String) -> Array:
	var lines: Array = source.split("\n")
	var tokens: Array = []
	for line_idx in range(lines.size()):
		var line: String = lines[line_idx]
		var line_no: int = line_idx + 1
		var indent: int = 0
		var c: int = 0
		while c < line.length() and (line[c] == " " or line[c] == "\t"):
			indent += 1 if line[c] == " " else 4
			c += 1
		var code_part: String = line.substr(c)
		var stripped: String = code_part.strip_edges()
		if stripped.is_empty() or stripped.begins_with("#"):
			continue
		tokens.append(Token.new("BOLO", indent, line_no))
		var r: Dictionary = _lex_line(code_part, line_no)
		if r["error"] != "":
			return [{"tokens": [], "error": r["error"], "line": r["line"]}]
		for t in r["tokens"]:
			tokens.append(t)
		tokens.append(Token.new("NEWLINE", null, line_no))
	tokens.append(Token.new("EOF", null, lines.size() + 1))
	tokens = _bolo_to_indent(tokens)
	return [{"tokens": tokens, "error": "", "line": -1}]

func _lex_line(line: String, line_no: int) -> Dictionary:
	var tokens: Array = []
	var i: int = 0
	while i < line.length():
		var ch: String = line[i]
		if ch == "#":
			break
		if ch == " " or ch == "\t":
			i += 1
			continue
		# 数字
		if ch.is_valid_int():
			var num_start: int = i
			while i < line.length() and line[i].is_valid_int():
				i += 1
			if i < line.length() and line[i] == ".":
				i += 1
				while i < line.length() and line[i].is_valid_int():
					i += 1
				var f: float = line.substr(num_start, i - num_start).to_float()
				tokens.append(Token.new("NUMBER", f, line_no))
			else:
				var n: int = line.substr(num_start, i - num_start).to_int()
				tokens.append(Token.new("NUMBER", n, line_no))
			continue
		# 字符串
		if ch == '"' or ch == "'":
			var quote: String = ch
			i += 1
			var s: String = ""
			while i < line.length() and line[i] != quote:
				if line[i] == "\\" and i + 1 < line.length():
					s += _decode_escape(line[i + 1])
					i += 2
				else:
					s += line[i]
					i += 1
			if i >= line.length():
				return {"tokens": [], "error": "字符串未闭合", "line": line_no}
			i += 1
			tokens.append(Token.new("STRING", s, line_no))
			continue
		# 标识符 / 关键字
		if ch.is_valid_identifier():
			var id_start: int = i
			while i < line.length() and (line[i].is_valid_identifier() or line[i].is_valid_int()):
				i += 1
			var word: String = line.substr(id_start, i - id_start)
			if KEYWORDS.has(word):
				tokens.append(Token.new("KEYWORD", word, line_no))
			else:
				tokens.append(Token.new("NAME", word, line_no))
			continue
		# 运算符
		var two: String = line.substr(i, 2)
		if two in ["==", "!=", "<=", ">=", "**", "//", "+=", "-=", "*=", "/="]:
			tokens.append(Token.new("OP", two, line_no))
			i += 2
			continue
		if ch in "+-*/%=<>()[],:.{}":
			tokens.append(Token.new("OP", ch, line_no))
			i += 1
			continue
		return {"tokens": [], "error": "无法识别的字符: " + ch, "line": line_no}
	return {"tokens": tokens, "error": "", "line": -1}

func _decode_escape(c: String) -> String:
	match c:
		"n":  return "\n"
		"t":  return "\t"
		"r":  return "\r"
		"\\": return "\\"
		"'":  return "'"
		'"':  return '"'
		_:    return c

func _bolo_to_indent(tokens: Array) -> Array:
	var result: Array = []
	var indent_stack: Array = [0]
	for t in tokens:
		if t.type == "BOLO":
			var indent: int = int(t.value)
			var top: int = indent_stack[indent_stack.size() - 1]
			if indent > top:
				indent_stack.append(indent)
				result.append(Token.new("OP", "INDENT", t.line))
			else:
				while indent < indent_stack[indent_stack.size() - 1]:
					indent_stack.pop_back()
					result.append(Token.new("OP", "DEDENT", t.line))
			continue
		result.append(t)
	var last_line: int = tokens[tokens.size() - 1].line if tokens.size() > 0 else -1
	while indent_stack.size() > 1:
		indent_stack.pop_back()
		result.append(Token.new("OP", "DEDENT", last_line))
	return result

# ===== 语法分析 =====
class Parser:
	extends RefCounted
	var tokens: Array = []
	var pos: int = 0
	var last_error: String = ""
	var last_error_line: int = -1

	func _init(toks: Array) -> void:
		tokens = toks

	func peek(o: int = 0) -> Token:
		var p: int = pos + o
		if p >= tokens.size():
			return tokens[tokens.size() - 1]
		return tokens[p]

	func advance() -> Token:
		var t: Token = tokens[pos]
		if pos < tokens.size() - 1:
			pos += 1
		return t

	func check(type_: String, value: Variant = null) -> bool:
		var t: Token = peek()
		if t.type != type_:
			return false
		if value != null and t.value != value:
			return false
		return true

	func _match(type_: String, value: Variant = null) -> bool:
		if check(type_, value):
			advance()
			return true
		return false

	func expect(type_: String, value: Variant = null) -> Token:
		if not check(type_, value):
			var t: Token = peek()
			var msg: String = "期望 %s" % type_
			if value != null:
				msg += " '%s'" % str(value)
			msg += "，但拿到 %s '%s'" % [t.type, str(t.value)]
			_error(msg)
			return null
		return advance()

	func _error(msg: String) -> void:
		if last_error == "":
			last_error = msg
			last_error_line = peek().line

	func skip_newlines() -> void:
		while check("NEWLINE"):
			advance()

	func parse_program() -> Variant:
		var stmts: Array = []
		skip_newlines()
		while not check("EOF"):
			var stmt: Variant = parse_statement()
			if stmt == null:
				return null
			stmts.append(stmt)
			skip_newlines()
		return {"_t": "block", "stmts": stmts}

	func parse_statement() -> Variant:
		var t: Token = peek()
		if t.type == "KEYWORD":
			if t.value == "if":     return parse_if()
			if t.value == "while":  return parse_while()
			if t.value == "for":    return parse_for()
			if t.value == "def":    return parse_def()
			if t.value == "return":
				advance()
				var e: Variant = parse_expr_or_none()
				return {"_t": "return", "value": e, "line": t.line}
			if t.value == "pass":     advance(); return {"_t": "pass", "line": t.line}
			if t.value == "break":    advance(); return {"_t": "break", "line": t.line}
			if t.value == "continue": advance(); return {"_t": "continue", "line": t.line}
		return parse_simple_stmt()

	func parse_simple_stmt() -> Variant:
		var t: Token = peek()
		var expr: Variant = parse_expr()
		if expr == null:
			return null
		if check("OP", "="):
			advance()
			var rhs: Variant = parse_expr()
			if rhs == null:
				return null
			return {"_t": "assign", "target": expr, "value": rhs, "line": t.line}
		return {"_t": "expr_stmt", "expr": expr, "line": t.line}

	func parse_if() -> Variant:
		var kw: Token = advance()
		var cond: Variant = parse_expr()
		if cond == null:
			return null
		if expect("OP", ":") == null:
			return null
		var body: Variant = parse_block()
		if body == null:
			return null
		var node: Dictionary = {"_t": "if", "cond": cond, "body": body, "elifs": [], "else_body": null, "line": kw.line}
		while check("KEYWORD", "elif") or check("KEYWORD", "else"):
			if check("KEYWORD", "elif"):
				advance()
				var c2: Variant = parse_expr()
				if c2 == null:
					return null
				if expect("OP", ":") == null:
					return null
				var b2: Variant = parse_block()
				if b2 == null:
					return null
				node["elifs"].append({"cond": c2, "body": b2})
			else:
				advance()
				if expect("OP", ":") == null:
					return null
				var eb: Variant = parse_block()
				if eb == null:
					return null
				node["else_body"] = eb
				break
		return node

	func parse_while() -> Variant:
		var kw: Token = advance()
		var cond: Variant = parse_expr()
		if cond == null:
			return null
		if expect("OP", ":") == null:
			return null
		var body: Variant = parse_block()
		if body == null:
			return null
		return {"_t": "while", "cond": cond, "body": body, "line": kw.line}

	func parse_for() -> Variant:
		var kw: Token = advance()
		if not check("NAME"):
			_error("for 后需要变量名")
			return null
		var var_name: String = advance().value
		if not _match("KEYWORD", "in"):
			_error("for 缺少 in")
			return null
		var iter_expr: Variant = parse_expr()
		if iter_expr == null:
			return null
		if expect("OP", ":") == null:
			return null
		var body: Variant = parse_block()
		if body == null:
			return null
		return {"_t": "for", "var": var_name, "iter": iter_expr, "body": body, "line": kw.line}

	func parse_def() -> Variant:
		var kw: Token = advance()
		if not check("NAME"):
			_error("def 后需要函数名")
			return null
		var name: String = advance().value
		if expect("OP", "(") == null:
			return null
		var params: Array = []
		while not check("OP", ")"):
			if not check("NAME"):
				_error("函数参数需要是标识符")
				return null
			params.append(advance().value)
			if not _match("OP", ","):
				break
		if expect("OP", ")") == null:
			return null
		if expect("OP", ":") == null:
			return null
		var body: Variant = parse_block()
		if body == null:
			return null
		return {"_t": "def", "name": name, "params": params, "body": body, "line": kw.line}

	func parse_block() -> Variant:
		skip_newlines()
		if not _match("OP", "INDENT"):
			_error("块体需要缩进")
			return null
		var stmts: Array = []
		skip_newlines()
		while not check("OP", "DEDENT") and not check("EOF"):
			var s: Variant = parse_statement()
			if s == null:
				return null
			stmts.append(s)
			skip_newlines()
		_match("OP", "DEDENT")
		return {"_t": "block", "stmts": stmts}

	func parse_expr_or_none() -> Variant:
		if check("NEWLINE") or check("EOF") or check("OP", "DEDENT"):
			return null
		return parse_expr()

	# 表达式：or < and < not < 比较 < 算术
	func parse_expr() -> Variant:
		return parse_or()

	func parse_or() -> Variant:
		var left: Variant = parse_and()
		if left == null:
			return null
		while check("KEYWORD", "or"):
			var op: Token = advance()
			var right: Variant = parse_and()
			if right == null:
				return null
			left = {"_t": "binop", "op": "or", "left": left, "right": right, "line": op.line}
		return left

	func parse_and() -> Variant:
		var left: Variant = parse_not()
		if left == null:
			return null
		while check("KEYWORD", "and"):
			var op: Token = advance()
			var right: Variant = parse_not()
			if right == null:
				return null
			left = {"_t": "binop", "op": "and", "left": left, "right": right, "line": op.line}
		return left

	func parse_not() -> Variant:
		if check("KEYWORD", "not"):
			var op: Token = advance()
			var e: Variant = parse_not()
			if e == null:
				return null
			return {"_t": "unaryop", "op": "not", "operand": e, "line": op.line}
		return parse_comparison()

	func parse_comparison() -> Variant:
		var left: Variant = parse_additive()
		if left == null:
			return null
		while check("OP", "==") or check("OP", "!=") or check("OP", "<") \
				or check("OP", "<=") or check("OP", ">") or check("OP", ">=") \
				or check("KEYWORD", "in") or check("KEYWORD", "not"):
			# not in 处理
			if check("KEYWORD", "not"):
				# 需要 not in 组合
				var not_op: Token = peek()
				advance()
				if not _match("KEYWORD", "in"):
					_error("not 后期望 in")
					return null
				var right_ni: Variant = parse_additive()
				if right_ni == null:
					return null
				left = {"_t": "binop", "op": "not_in", "left": left, "right": right_ni, "line": not_op.line}
				continue
			var op: Token = advance()
			var right: Variant = parse_additive()
			if right == null:
				return null
			left = {"_t": "binop", "op": op.value, "left": left, "right": right, "line": op.line}
		return left

	func parse_additive() -> Variant:
		var left: Variant = parse_multiplicative()
		if left == null:
			return null
		while check("OP", "+") or check("OP", "-"):
			var op: Token = advance()
			var right: Variant = parse_multiplicative()
			if right == null:
				return null
			left = {"_t": "binop", "op": op.value, "left": left, "right": right, "line": op.line}
		return left

	func parse_multiplicative() -> Variant:
		var left: Variant = parse_unary()
		if left == null:
			return null
		while check("OP", "*") or check("OP", "/") or check("OP", "//") or check("OP", "%"):
			var op: Token = advance()
			var right: Variant = parse_unary()
			if right == null:
				return null
			left = {"_t": "binop", "op": op.value, "left": left, "right": right, "line": op.line}
		return left

	func parse_unary() -> Variant:
		if check("OP", "-"):
			var op: Token = advance()
			var e: Variant = parse_unary()
			if e == null:
				return null
			return {"_t": "unaryop", "op": "-", "operand": e, "line": op.line}
		if check("OP", "+"):
			advance()
			return parse_unary()
		return parse_power()

	func parse_power() -> Variant:
		var base: Variant = parse_postfix()
		if base == null:
			return null
		if check("OP", "**"):
			var op: Token = advance()
			var exp: Variant = parse_unary()
			if exp == null:
				return null
			return {"_t": "binop", "op": "**", "left": base, "right": exp, "line": op.line}
		return base

	func parse_postfix() -> Variant:
		var e: Variant = parse_primary()
		if e == null:
			return null
		while true:
			if check("OP", "("):
				e = _parse_call(e)
				if e == null:
					return null
			elif check("OP", "["):
				e = _parse_index(e)
				if e == null:
					return null
			elif check("OP", "."):
				# 方法调用 obj.method(args)
				advance()  # 消费 .
				if not check("NAME"):
					_error(". 后需要方法名")
					return null
				var method_name: String = advance().value
				if not _match("OP", "("):
					_error("方法调用需要 ()")
					return null
				var args: Array = []
				while not check("OP", ")"):
					var a: Variant = parse_expr()
					if a == null:
						return null
					args.append(a)
					if not _match("OP", ","):
						break
				if expect("OP", ")") == null:
					return null
				e = {"_t": "method", "obj": e, "method": method_name, "args": args, "line": peek().line}
			else:
				break
		return e

	func _parse_call(callee: Variant) -> Variant:
		var op: Token = advance()
		var args: Array = []
		while not check("OP", ")"):
			var a: Variant = parse_expr()
			if a == null:
				return null
			args.append(a)
			if not _match("OP", ","):
				break
		if expect("OP", ")") == null:
			return null
		return {"_t": "call", "callee": callee, "args": args, "line": op.line}

	func _parse_index(obj: Variant) -> Variant:
		var op: Token = advance()
		var start: Variant = null
		var end: Variant = null
		var is_slice: bool = false
		if not check("OP", ":") and not check("OP", "]"):
			start = parse_expr()
			if start == null:
				return null
		if _match("OP", ":"):
			is_slice = true
			if not check("OP", "]") and not check("OP", ":"):
				end = parse_expr()
				if end == null:
					return null
		if expect("OP", "]") == null:
			return null
		if is_slice:
			return {"_t": "slice", "obj": obj, "start": start, "end": end, "line": op.line}
		return {"_t": "index", "obj": obj, "index": start, "line": op.line}

	func parse_primary() -> Variant:
		var t: Token = peek()
		if t.type == "NUMBER":
			advance()
			return {"_t": "lit", "value": t.value, "line": t.line}
		if t.type == "STRING":
			advance()
			return {"_t": "lit", "value": t.value, "line": t.line}
		if t.type == "KEYWORD":
			if t.value == "True":
				advance(); return {"_t": "lit", "value": true, "line": t.line}
			if t.value == "False":
				advance(); return {"_t": "lit", "value": false, "line": t.line}
			if t.value == "None":
				advance(); return {"_t": "lit", "value": null, "line": t.line}
		if t.type == "NAME":
			advance()
			return {"_t": "name", "value": t.value, "line": t.line}
		if t.type == "OP":
			if t.value == "(":
				advance()
				var e: Variant = parse_expr()
				if e == null:
					return null
				if expect("OP", ")") == null:
					return null
				return e
			if t.value == "[":
				advance()
				var elems: Array = []
				while not check("OP", "]"):
					var el: Variant = parse_expr()
					if el == null:
						return null
					elems.append(el)
					if not _match("OP", ","):
						break
				if expect("OP", "]") == null:
					return null
				return {"_t": "list", "elems": elems, "line": t.line}
			if t.value == "{":
				advance()
				var pairs: Array = []
				while not check("OP", "}"):
					var k: Variant = parse_expr()
					if k == null:
						return null
					if expect("OP", ":") == null:
						return null
					var v: Variant = parse_expr()
					if v == null:
						return null
					pairs.append([k, v])
					if not _match("OP", ","):
						break
				if expect("OP", "}") == null:
					return null
				return {"_t": "dict", "pairs": pairs, "line": t.line}
		_error("非预期的 token: %s '%s'" % [t.type, str(t.value)])
		return null

# ===== 解释器 =====
class Interpreter:
	extends RefCounted
	var globals: Dictionary = {}
	var funcs: Dictionary = {}
	var output: String = ""
	var error: String = ""
	var error_line: int = -1
	var user_input: Array = []
	var input_idx: int = 0
	var max_steps: int = 1000000
	var steps: int = 0

	# 控制流
	var break_flag: bool = false
	var continue_flag: bool = false
	var return_value: Variant = null
	var has_return: bool = false

	func run(ast: Variant) -> void:
		_setup_builtins()
		var block: Dictionary = ast
		for stmt in block["stmts"]:
			if stmt is Dictionary and stmt["_t"] == "def":
				funcs[stmt["name"]] = stmt
		for stmt in block["stmts"]:
			if error != "":
				return
			_exec_stmt(stmt)
			if has_return:
				return

	func _setup_builtins() -> void:
		globals["len"] = "BUILTIN_LEN"
		globals["range"] = "BUILTIN_RANGE"
		globals["int"] = "BUILTIN_INT"
		globals["str"] = "BUILTIN_STR"
		globals["float"] = "BUILTIN_FLOAT"
		globals["abs"] = "BUILTIN_ABS"
		globals["min"] = "BUILTIN_MIN"
		globals["max"] = "BUILTIN_MAX"
		globals["sum"] = "BUILTIN_SUM"
		globals["print"] = "BUILTIN_PRINT"
		globals["input"] = "BUILTIN_INPUT"

	func _check_steps() -> void:
		steps += 1
		if steps > max_steps:
			_set_error("执行步数超限（可能死循环）")

	func _set_error(msg: String, line: int = -1) -> void:
		if error == "":
			error = msg
			error_line = line

	func _exec_stmt(node: Variant) -> void:
		if error != "" or not (node is Dictionary):
			return
		match node["_t"]:
			"assign":     _exec_assign(node)
			"expr_stmt":  _eval(node["expr"])
			"if":         _exec_if(node)
			"while":      _exec_while(node)
			"for":        _exec_for(node)
			"def":        pass
			"return":
				return_value = _eval_or_null(node["value"])
				has_return = true
			"pass":       pass
			"break":      break_flag = true
			"continue":   continue_flag = true

	func _eval_or_null(node: Variant) -> Variant:
		if node == null:
			return null
		return _eval(node)

	func _exec_assign(node: Dictionary) -> void:
		var v: Variant = _eval(node["value"])
		if error != "":
			return
		var target: Dictionary = node["target"]
		if target["_t"] == "name":
			globals[target["value"]] = v
		elif target["_t"] == "index":
			var obj: Variant = _eval(target["obj"])
			var idx: Variant = _eval(target["index"])
			_set_index(obj, idx, v)
		else:
			_set_error("不支持的赋值目标")

	func _set_index(obj: Variant, idx: Variant, v: Variant) -> void:
		if obj is Array:
			var i: int = _norm_index(idx, obj.size())
			if i >= 0 and i < obj.size():
				obj[i] = v
			else:
				_set_error("列表索引越界")
		elif obj is Dictionary:
			obj[idx] = v
		else:
			_set_error("不支持的对象索引赋值")

	func _norm_index(idx: Variant, size: int) -> int:
		var i: int = int(idx)
		if i < 0:
			i += size
		return i

	func _exec_if(node: Dictionary) -> void:
		if _truthy(_eval(node["cond"])):
			_exec_block(node["body"])
		else:
			var matched: bool = false
			for elif_branch in node["elifs"]:
				if _truthy(_eval(elif_branch["cond"])):
					_exec_block(elif_branch["body"])
					matched = true
					break
			if not matched and node["else_body"] != null:
				_exec_block(node["else_body"])

	func _exec_block(block: Variant) -> void:
		if not (block is Dictionary):
			return
		for stmt in block["stmts"]:
			_exec_stmt(stmt)
			if break_flag or continue_flag or has_return or error != "":
				return

	func _exec_while(node: Dictionary) -> void:
		var safety: int = 0
		while error == "" and _truthy(_eval(node["cond"])):
			safety += 1
			if safety > 1000000:
				_set_error("while 循环次数过多")
				return
			_exec_block(node["body"])
			if break_flag:
				break_flag = false
				break
			if continue_flag:
				continue_flag = false
				continue
			if has_return or error != "":
				return

	func _exec_for(node: Dictionary) -> void:
		var iter_val: Variant = _eval(node["iter"])
		if error != "":
			return
		var seq: Array = []
		if iter_val is Array:
			seq = (iter_val as Array).duplicate()
		elif iter_val is String:
			for ch in iter_val:
				seq.append(ch)
		elif iter_val is Dictionary:
			# Python 默认迭代 dict 的 keys
			for k in iter_val:
				seq.append(k)
		else:
			_set_error("for 不能迭代该类型")
			return
		for item in seq:
			if error != "":
				return
			globals[node["var"]] = item
			_exec_block(node["body"])
			if break_flag:
				break_flag = false
				break
			if continue_flag:
				continue_flag = false
				continue
			if has_return or error != "":
				return

	func _eval(node: Variant) -> Variant:
		if error != "" or not (node is Dictionary):
			return null
		match node["_t"]:
			"lit":     return node["value"]
			"name":    return _lookup(node["value"])
			"list":    return _eval_list(node["elems"])
			"dict":    return _eval_dict(node)
			"binop":   return _eval_binop(node)
			"unaryop": return _eval_unaryop(node)
			"call":    return _eval_call(node)
			"index":   return _eval_index(node)
			"slice":   return _eval_slice(node)
			"method":  return _eval_method(node)
		_set_error("未知节点类型 %s" % node["_t"])
		return null

	func _eval_dict(node: Dictionary) -> Dictionary:
		var d: Dictionary = {}
		for kv in node["pairs"]:
			var k: Variant = _eval(kv[0])
			if error != "":
				return {}
			var v: Variant = _eval(kv[1])
			if error != "":
				return {}
			d[k] = v
		return d

	func _eval_method(node: Dictionary) -> Variant:
		var obj: Variant = _eval(node["obj"])
		if error != "":
			return null
		var method: String = node["method"]
		# 先求参数
		var args: Array = []
		for a in node["args"]:
			args.append(_eval(a))
			if error != "":
				return null
		if obj is String:
			return _string_method(obj, method, args)
		if obj is Array:
			return _list_method(obj, method, args)
		if obj is Dictionary:
			return _dict_method(obj, method, args)
		_set_error("类型 %s 不支持方法调用" % str(typeof(obj)))
		return null

	func _string_method(s: String, method: String, args: Array) -> Variant:
		match method:
			"upper":  return s.to_upper()
			"lower":  return s.to_lower()
			"strip", "trim": return s.strip_edges()
			"lstrip": return s.strip_edges(true, false)
			"rstrip": return s.strip_edges(false, true)
			"replace": return s.replace(args[0], args[1])
			"split":
				var raw = s.split(args[0]) if args.size() >= 1 else s.split(" ")
				# Godot split 返回 PackedStringArray，转 Array 保持类型一致
				var arr: Array = []
				for x in raw:
					arr.append(x)
				return arr
			"startswith": return s.begins_with(args[0])
			"endswith":   return s.ends_with(args[0])
			"find":   return s.find(args[0])
			"count":  return s.count(args[0])
			"join":   return s.join(args[0] if args.size() >= 1 else [])
			"isdigit": return s.is_valid_int()
			"index":  var i = s.find(args[0]); if i < 0: _set_error("子串未找到"); return -1; return i
		_set_error("String 无此方法: %s" % method)
		return null

	func _list_method(arr: Array, method: String, args: Array) -> Variant:
		match method:
			"append": arr.append(args[0]); return null
			"pop":
				if args.size() == 0:
					if arr.is_empty():
						_set_error("pop 空列表")
						return null
					return arr.pop_back()
				else:
					return arr.pop_at(int(args[0]))
			"remove": arr.erase(args[0]); return null
			"sort": arr.sort(); return null
			"reverse": arr.reverse(); return null
			"count": return arr.count(args[0])
			"index": var idx = arr.find(args[0]); if idx < 0: _set_error("元素未找到"); return idx
			"extend": arr.append_array(args[0]); return null
			"insert": arr.insert(int(args[0]), args[1]); return null
			"copy": return arr.duplicate()
		_set_error("List 无此方法: %s" % method)
		return null

	func _dict_method(d: Dictionary, method: String, args: Array) -> Variant:
		match method:
			"keys":
				var arr: Array = []
				for k in d.keys(): arr.append(k)
				return arr
			"values":
				var arr2: Array = []
				for v in d.values(): arr2.append(v)
				return arr2
			"get":
				if args.size() == 1:
					return d.get(args[0], null)
				return d.get(args[0], args[1])
			"pop":
				if not d.has(args[0]):
					if args.size() >= 2: return args[1]
					_set_error("dict.pop 键不存在")
					return null
				var v = d[args[0]]
				d.erase(args[0])
				return v
			"items":  return d.keys()  # 简化：不支持 d.items() 元组列表
		_set_error("Dict 无此方法: %s" % method)
		return null

	func _eval_list(elems: Array) -> Array:
		var r: Array = []
		for e in elems:
			r.append(_eval(e))
			if error != "":
				return []
		return r

	func _truthy(v: Variant) -> bool:
		if v == null:
			return false
		if v is bool:
			return v
		if v is int or v is float:
			return v != 0
		if v is String:
			return v.length() > 0
		if v is Array:
			return v.size() > 0
		if v is Dictionary:
			return v.size() > 0
		return true

	func _lookup(name: String) -> Variant:
		if globals.has(name):
			return globals[name]
		_set_error("未定义的变量 '%s'" % name)
		return null

	func _eval_binop(node: Dictionary) -> Variant:
		if node["op"] == "and":
			var l: Variant = _eval(node["left"])
			if error != "":
				return null
			if not _truthy(l):
				return l
			return _eval(node["right"])
		if node["op"] == "or":
			var l2: Variant = _eval(node["left"])
			if error != "":
				return null
			if _truthy(l2):
				return l2
			return _eval(node["right"])
		var l3: Variant = _eval(node["left"])
		if error != "":
			return null
		var r: Variant = _eval(node["right"])
		if error != "":
			return null
		var op: String = node["op"]
		if op == "+":
			if l3 is String or r is String:
				return _py_str(l3) + _py_str(r) if (l3 is String or r is String) and not (l3 is Array or r is Array) else _py_add(l3, r)
			if l3 is Array or r is Array:
				return _py_add(l3, r)
			return l3 + r
		if op == "-":  return l3 - r
		if op == "*":
			if (l3 is String and r is int) or (l3 is Array and r is int):
				return _py_repeat(l3, r)
			if (r is String and l3 is int) or (r is Array and l3 is int):
				return _py_repeat(r, l3)
			return l3 * r
		if op == "/":  return float(l3) / float(r)
		if op == "//": return _floor_div(l3, r)
		if op == "%":  return _py_mod(l3, r)
		if op == "**":
			# Python 整数幂返回 int（如 2**10 == 1024），浮点幂才返回 float
			if l3 is int and r is int:
				var result: int = 1
				var base_v: int = int(l3)
				var exp_v: int = int(r)
				if exp_v < 0:
					return pow(l3, r)  # 负指数退回 float
				for i in range(exp_v):
					result *= base_v
				return result
			return pow(l3, r)
		if op == "==": return l3 == r
		if op == "!=": return l3 != r
		if op == "<":  return l3 < r
		if op == "<=": return l3 <= r
		if op == ">":  return l3 > r
		if op == ">=": return l3 >= r
		if op == "in":
			return _py_in(l3, r)
		if op == "not_in":
			return not _py_in(l3, r)
		_set_error("未知运算符 %s" % op)
		return null

	func _py_in(needle: Variant, hay: Variant) -> bool:
		if hay is Array:
			return hay.has(needle)
		if hay is Dictionary:
			return hay.has(needle)
		if hay is String:
			return (hay as String).find(str(needle)) >= 0
		_set_error("in 右操作数类型不支持")
		return false

	func _floor_div(l: Variant, r: Variant) -> Variant:
		if l is int and r is int:
			var v: int = int(l / r)
			# Python 的 floor div：-7//2 = -4，不是 -3
			var mod_val: int = int(l) - v * int(r)
			if mod_val != 0 and ((mod_val < 0) != (int(r) < 0)):
				v -= 1
			return v
		var v2: float = float(l) / float(r)
		return floor(v2) if v2 >= 0 else ceil(v2)

	func _py_add(l: Variant, r: Variant) -> Variant:
		if l is Array and r is Array:
			return (l as Array) + (r as Array)
		# 字符串拼接（其中一个是字符串）
		return _py_str(l) + _py_str(r)

	func _py_repeat(seq: Variant, n: int) -> Variant:
		if seq is String:
			return (seq as String).repeat(max(0, n))
		var r: Array = []
		var arr: Array = seq
		for i in range(max(0, n)):
			r.append_array(arr)
		return r

	func _py_mod(l: Variant, r: Variant) -> Variant:
		var m: Variant = fmod(l, r)
		if (m < 0 and r > 0) or (m > 0 and r < 0):
			m += r
		if l is int and r is int:
			return int(m)
		return m

	func _eval_unaryop(node: Dictionary) -> Variant:
		var v: Variant = _eval(node["operand"])
		if error != "":
			return null
		if node["op"] == "-":
			return -v
		if node["op"] == "not":
			return not _truthy(v)
		_set_error("未知一元运算 %s" % node["op"])
		return null

	func _eval_call(node: Dictionary) -> Variant:
		var callee: Variant = node["callee"]
		if not (callee is Dictionary) or callee["_t"] != "name":
			_set_error("暂只支持函数名调用")
			return null
		var name: String = callee["value"]
		if funcs.has(name):
			var args: Array = []
			for a in node["args"]:
				args.append(_eval(a))
				if error != "":
					return null
			return _call_user_func(funcs[name], args)
		if globals.has(name):
			var bi: Variant = globals[name]
			if typeof(bi) == TYPE_STRING and (bi as String).begins_with("BUILTIN_"):
				return _call_builtin(name, bi, node["args"])
		_set_error("未定义的函数 '%s'" % name)
		return null

	func _call_user_func(fn: Dictionary, args: Array) -> Variant:
		var params: Array = fn["params"]
		if args.size() != params.size():
			_set_error("函数 %s 期望 %d 个参数，得到 %d" % [fn["name"], params.size(), args.size()])
			return null
		# 保存当前全局态
		var saved: Dictionary = globals.duplicate(true)
		var saved_funcs: Dictionary = funcs.duplicate(true)
		var saved_has_return: bool = has_return
		var saved_return: Variant = return_value
		var saved_input_idx: int = input_idx
		has_return = false
		return_value = null
		for i in params.size():
			globals[params[i]] = args[i]
		_exec_block(fn["body"])
		var rv: Variant = return_value
		# 恢复
		globals = saved
		funcs = saved_funcs
		has_return = saved_has_return
		return_value = saved_return
		input_idx = saved_input_idx
		return rv

	func _call_builtin(name: String, bi: String, arg_nodes: Array) -> Variant:
		if bi == "BUILTIN_PRINT":
			_builtin_print(arg_nodes)
			return null
		if bi == "BUILTIN_LEN":
			var v: Variant = _eval(arg_nodes[0])
			if error != "": return 0
			if v is String: return v.length()
			if v is Array:  return v.size()
			if v is Dictionary: return v.size()
			_set_error("len: 类型错误")
			return 0
		if bi == "BUILTIN_RANGE":
			return _builtin_range(arg_nodes)
		if bi == "BUILTIN_INT":
			var v2: Variant = _eval(arg_nodes[0])
			if error != "": return 0
			if v2 is String: return v2.to_int()
			return int(v2)
		if bi == "BUILTIN_STR":
			return _py_str(_eval(arg_nodes[0]))
		if bi == "BUILTIN_FLOAT":
			var v3: Variant = _eval(arg_nodes[0])
			if error != "": return 0.0
			if v3 is String: return v3.to_float()
			return float(v3)
		if bi == "BUILTIN_ABS":  return abs(_eval(arg_nodes[0]))
		if bi == "BUILTIN_MIN":
			var vals = _eval_or_seq(arg_nodes)
			if vals.is_empty(): return null
			var m = vals[0]
			for x in vals:
				if x < m: m = x
			return m
		if bi == "BUILTIN_MAX":
			var vals2 = _eval_or_seq(arg_nodes)
			if vals2.is_empty(): return null
			var m2 = vals2[0]
			for x in vals2:
				if x > m2: m2 = x
			return m2
		if bi == "BUILTIN_SUM":
			var vals3 = _eval_or_seq(arg_nodes)
			var s: Variant = 0
			for x in vals3: s += x
			return s
		if bi == "BUILTIN_INPUT":
			if input_idx < user_input.size():
				var line_in: String = user_input[input_idx]
				input_idx += 1
				output += line_in + "\n"
				return line_in
			_set_error("input: 没有更多输入")
			return ""
		_set_error("未知内置 %s" % name)
		return null

	func _eval_or_seq(arg_nodes: Array) -> Array:
		if arg_nodes.size() == 1:
			var v: Variant = _eval(arg_nodes[0])
			if v is Array: return v
			return [v]
		var r: Array = []
		for n in arg_nodes:
			r.append(_eval(n))
		return r

	func _builtin_print(arg_nodes: Array) -> void:
		var parts: Array = []
		for n in arg_nodes:
			parts.append(_py_str(_eval(n)))
			if error != "":
				return
		var line_out: String = " ".join(parts)
		output += line_out + "\n"

	func _py_str(v: Variant) -> String:
		if v == null: return "None"
		if v is bool: return "True" if v else "False"
		if v is float:
			if v == round(v) and abs(v) < 1e16:
				return "%.1f" % v
			return str(v)
		if v is Array:
			var parts: Array = []
			for x in v:
				if x is String:
					parts.append("'" + x + "'")
				else:
					parts.append(_py_str(x))
			return "[" + ", ".join(parts) + "]"
		if v is Dictionary:
			var parts2: Array = []
			for k in v:
				var ks: String = ("'" + k + "'") if k is String else _py_str(k)
				var vs: String = ("'" + v[k] + "'") if v[k] is String else _py_str(v[k])
				parts2.append(ks + ": " + vs)
			return "{" + ", ".join(parts2) + "}"
		return str(v)

	func _builtin_range(arg_nodes: Array) -> Array:
		var args: Array = []
		for n in arg_nodes:
			args.append(int(_eval(n)))
			if error != "":
				return []
		var start: int = 0
		var stop: int = 0
		var step: int = 1
		match args.size():
			1: stop = args[0]
			2: start = args[0]; stop = args[1]
			3: start = args[0]; stop = args[1]; step = args[2]
			_:
				_set_error("range: 参数数量错误")
				return []
		if step == 0:
			_set_error("range: step 不能为 0")
			return []
		var r: Array = []
		if step > 0:
			var i: int = start
			while i < stop:
				r.append(i)
				i += step
		else:
			var i2: int = start
			while i2 > stop:
				r.append(i2)
				i2 += step
		return r

	func _eval_index(node: Dictionary) -> Variant:
		var obj: Variant = _eval(node["obj"])
		if error != "": return null
		var idx: Variant = _eval(node["index"])
		if error != "": return null
		if obj is Array:
			var arr: Array = obj
			var i: int = _norm_index(idx, arr.size())
			if i < 0 or i >= arr.size():
				_set_error("列表索引越界 %d" % i)
				return null
			return arr[i]
		if obj is String:
			var s: String = obj
			var i2: int = _norm_index(idx, s.length())
			if i2 < 0 or i2 >= s.length():
				_set_error("字符串索引越界")
				return null
			return s[i2]
		if obj is Dictionary:
			var d: Dictionary = obj
			if not d.has(idx):
				_set_error("KeyError: '%s'" % str(idx))
				return null
			return d[idx]
		_set_error("该对象不支持索引")
		return null

	func _eval_slice(node: Dictionary) -> Variant:
		var obj: Variant = _eval(node["obj"])
		if error != "": return null
		var start_idx: int = -1
		var end_idx: int = -1
		if node["start"] != null:
			start_idx = int(_eval(node["start"]))
		if node["end"] != null:
			end_idx = int(_eval(node["end"]))
		if obj is String:
			var s: String = obj
			var begin: int = start_idx if start_idx != -1 else 0
			var stop_v: int = end_idx if end_idx != -1 else s.length()
			if begin < 0: begin += s.length()
			if stop_v < 0: stop_v += s.length()
			begin = clamp(begin, 0, s.length())
			stop_v = clamp(stop_v, 0, s.length())
			return s.substr(begin, max(0, stop_v - begin))
		if obj is Array:
			var arr: Array = obj
			var begin2: int = start_idx if start_idx != -1 else 0
			var stop_v2: int = end_idx if end_idx != -1 else arr.size()
			if begin2 < 0: begin2 += arr.size()
			if stop_v2 < 0: stop_v2 += arr.size()
			begin2 = clamp(begin2, 0, arr.size())
			stop_v2 = clamp(stop_v2, 0, arr.size())
			var r: Array = []
			var i: int = begin2
			while i < stop_v2:
				r.append(arr[i])
				i += 1
			return r
		_set_error("不支持切片的对象")
		return null

# ===== 顶层入口 =====
func execute(source: String, in_user_input: Array = []) -> Dictionary:
	var lex_result: Array = tokenize(source)
	var lex: Dictionary = lex_result[0]
	if lex["error"] != "":
		return {"output": "", "error": lex["error"], "line": lex["line"]}
	var p := Parser.new(lex["tokens"])
	var ast: Variant = p.parse_program()
	if ast == null:
		return {"output": "", "error": p.last_error if p.last_error != "" else "语法错误", "line": p.last_error_line}
	var interp := Interpreter.new()
	interp.user_input = in_user_input
	interp.run(ast)
	return {"output": interp.output, "error": interp.error, "line": interp.error_line}
