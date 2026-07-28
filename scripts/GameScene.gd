extends Control

## 游戏场景
## 代码编辑器 + 任务描述 + 运行结果 + 角色动画区

@onready var chapter_label: Label = $TopBar/ChapterLabel
@onready var level_label: Label = $TopBar/LevelLabel
@onready var knowledge_label: Label = $TopBar/KnowledgeLabel
@onready var back_btn: Button = $TopBar/BackBtn

@onready var prompt_text: RichTextLabel = $LeftPanel/PromptScroll/PromptText
@onready var code_edit: CodeEdit = $LeftPanel/CodeEdit
@onready var hint_label: Label = $LeftPanel/HintLabel
@onready var hint_btn: Button = $LeftPanel/HintBtn

@onready var run_btn: Button = $BottomBar/RunBtn
@onready var reset_btn: Button = $BottomBar/ResetBtn
@onready var next_btn: Button = $BottomBar/NextBtn

@onready var result_text: RichTextLabel = $RightPanel/ResultScroll/ResultText
@onready var status_label: Label = $RightPanel/StatusLabel
@onready var character_area: ColorRect = $RightPanel/CharacterArea

var current_level_id: int = 0
var starter_code: String = ""
var level_passed: bool = false

func _ready() -> void:
	current_level_id = LevelManager.current_level
	_load_level(current_level_id)
	
	back_btn.pressed.connect(_on_back)
	run_btn.pressed.connect(_on_run)
	reset_btn.pressed.connect(_on_reset)
	next_btn.pressed.connect(_on_next)
	hint_btn.pressed.connect(_on_hint)
	
	# PythonRunner 信号
	PythonRunner.execution_finished.connect(_on_execution_finished)
	
	# 默认隐藏提示
	hint_label.visible = false
	next_btn.visible = false
	
	# 配色
	character_area.color = Color(0.05, 0.08, 0.1, 1)

func _load_level(level_id: int) -> void:
	if level_id >= LevelManager.levels.size():
		# 全部通关
		_show_victory()
		return
	
	var ld = LevelManager.levels[level_id]
	chapter_label.text = ld.chapter
	level_label.text = "第 " + str(level_id + 1) + " 关：" + ld.title
	knowledge_label.text = "知识点：" + ld.python_knowledge
	prompt_text.text = ld.prompt
	
	starter_code = ld.starter_code
	code_edit.text = starter_code
	
	result_text.text = "[color=gray]点击「运行」执行代码[/color]"
	status_label.text = ""
	status_label.add_theme_color_override("font_color", Color.GRAY)
	
	hint_label.text = ld.hint
	hint_label.visible = false
	hint_btn.visible = true
	
	level_passed = false
	next_btn.visible = false
	character_area.color = Color(0.05, 0.08, 0.1, 1)

func _on_run() -> void:
	if level_passed:
		return
	
	var code = code_edit.text
	
	if code.strip_edges() == starter_code.strip_edges():
		result_text.text = "[color=orange]代码还没有改动，试试写点代码吧！[/color]"
		return
	
	# 语法快速检查
	var syntax_err = PythonRunner.quick_syntax_check(code)
	if syntax_err != "":
		result_text.text = "[color=red]语法提醒：" + syntax_err + "[/color]"
		return
	
	# 禁用按钮
	run_btn.disabled = true
	run_btn.text = "运行中..."
	result_text.text = "[color=gray]正在执行...[/color]"
	
	# 执行
	PythonRunner.execute_code(code)

func _on_execution_finished(output: String, success: bool) -> void:
	run_btn.disabled = false
	run_btn.text = "运行代码"
	
	if not success:
		result_text.text = "[color=red]" + output + "[/color]"
		status_label.text = "运行出错"
		status_label.add_theme_color_override("font_color", Color.RED)
		character_area.color = Color(0.3, 0.1, 0.1, 1)
		return
	
	# 显示输出
	if output.strip_edges().is_empty():
		result_text.text = "[color=gray]（代码执行完毕，没有输出）[/color]"
	else:
		result_text.text = "[color=white]" + output + "[/color]"
	
	# 检查是否通关
	var ld = LevelManager.levels[current_level_id]
	if PythonRunner.check_output(output, ld.expected_output):
		_pass_level()
	else:
		status_label.text = "输出不匹配，继续尝试"
		status_label.add_theme_color_override("font_color", Color.ORANGE)
		character_area.color = Color(0.15, 0.12, 0.05, 1)

func _pass_level() -> void:
	level_passed = true
	status_label.text = "通关！干得漂亮！"
	status_label.add_theme_color_override("font_color", Color.GREEN)
	character_area.color = Color(0.05, 0.15, 0.08, 1)
	
	# 显示通关动画文字
	result_text.append_text("\n\n[color=green][b]========== 通关！==========[/b][/color]")
	result_text.append_text("\n[color=green]你掌握了：" + LevelManager.levels[current_level_id].python_knowledge + "[/color]")
	
	# 保存进度
	LevelManager.complete_level(current_level_id)
	
	# 显示下一关按钮
	if current_level_id < LevelManager.levels.size() - 1:
		next_btn.visible = true
		next_btn.text = "下一关 →"
	else:
		_show_victory()

func _on_reset() -> void:
	code_edit.text = starter_code
	result_text.text = "[color=gray]代码已重置[/color]"
	status_label.text = ""
	level_passed = false
	next_btn.visible = false
	character_area.color = Color(0.05, 0.08, 0.1, 1)

func _on_hint() -> void:
	hint_label.visible = !hint_label.visible
	hint_btn.text = "隐藏提示" if hint_label.visible else "显示提示"

func _on_next() -> void:
	current_level_id += 1
	LevelManager.current_level = current_level_id
	_load_level(current_level_id)

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _show_victory() -> void:
	result_text.text = "[color=green][b]🎉 恭喜通关全部关卡！[/b][/color]\n\n[color=white]你学会了：\n• print 输出\n• 变量和数据类型\n• if/else 条件判断\n• for 循环\n• while 循环\n• 列表\n• 函数定义\n\n继续探索 Python 的世界吧！[/color]"
	status_label.text = "全部通关！"
	status_label.add_theme_color_override("font_color", Color.GREEN)
	next_btn.visible = false
