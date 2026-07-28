extends Control

## 游戏场景
## 代码编辑器（Python高亮）+ 任务 + 角色可视化 + 进度条 + 庆祝动画

@onready var chapter_label: Label = $TopBar/ChapterLabel
@onready var level_label: Label = $TopBar/LevelLabel
@onready var knowledge_label: Label = $TopBar/KnowledgeLabel
@onready var back_btn: Button = $TopBar/BackBtn

@onready var prompt_text: RichTextLabel = $MainSplit/LeftPanel/PromptScroll/PromptText
@onready var code_edit: CodeEdit = $MainSplit/LeftPanel/CodeEdit
@onready var hint_label: Label = $MainSplit/LeftPanel/HintLabel
@onready var hint_btn: Button = $MainSplit/LeftPanel/HintBtn

@onready var run_btn: Button = $BottomBar/RunBtn
@onready var reset_btn: Button = $BottomBar/ResetBtn
@onready var next_btn: Button = $BottomBar/NextBtn

@onready var result_text: RichTextLabel = $MainSplit/RightPanel/ResultScroll/ResultText
@onready var status_label: Label = $MainSplit/RightPanel/StatusLabel

@onready var character_area: ColorRect = $MainSplit/RightPanel/CharacterArea
@onready var character_sprite: Node2D = $MainSplit/RightPanel/CharacterArea/CharacterSprite
@onready var character_effect: Label = $MainSplit/RightPanel/CharacterArea/EffectLabel

# 表情模式：normal / think / error / win
const MOOD_NORMAL := "normal"
const MOOD_THINK := "think"
const MOOD_ERROR := "error"
const MOOD_WIN := "win"

@onready var progress_bar: ProgressBar = $TopBar/ProgressBar
@onready var progress_label: Label = $TopBar/ProgressLabel

@onready var celebration_overlay: Control = $CelebrationOverlay
@onready var celebration_label: Label = $CelebrationOverlay/CelebrationLabel

var current_level_id: int = 0
var starter_code: String = ""
var level_passed: bool = false
var character_animating: bool = false

func _ready() -> void:
	current_level_id = LevelManager.current_level
	
	# 设置 Python 语法高亮
	var highlighter = load("res://scripts/PythonSyntaxHighlighter.gd").new()
	highlighter.set_code_edit(code_edit)
	code_edit.syntax_highlighter = highlighter
	
	_load_level(current_level_id)
	
	back_btn.pressed.connect(_on_back)
	run_btn.pressed.connect(_on_run)
	reset_btn.pressed.connect(_on_reset)
	next_btn.pressed.connect(_on_next)
	hint_btn.pressed.connect(_on_hint)
	
	PythonRunner.execution_finished.connect(_on_execution_finished)
	
	hint_label.visible = false
	next_btn.visible = false
	celebration_overlay.visible = false

	# 构建角色立绘（程序化矢量法师）
	for child in character_sprite.get_children():
		child.queue_free()
	var wizard := ThemeBuilder.make_character_sprite()
	wizard.name = "Wizard"
	character_sprite.add_child(wizard)
	# 法师素材以 (0,0) 为中心绘制，立绘根节点偏移到 (-20, -20) 让中心对齐
	wizard.position = Vector2.ZERO
	character_effect.text = ""

	# 居中角色
	call_deferred("_center_character")

func _center_character() -> void:
	# 法师立绘中心 (0,0) + 头部约 -6 像素，整体高约 70；居中
	character_sprite.position = Vector2(
		character_area.size.x / 2,
		character_area.size.y / 2 - 10
	)
	character_sprite.scale = Vector2(1.4, 1.4)
	character_effect.position = Vector2(
		character_area.size.x / 2 - 60,
		character_area.size.y / 2 + 60
	)
	character_effect.size = Vector2(120, 24)

## 切换角色表情（通过旋转/缩放/颜色变化，不动矢量结构）
func _set_mood(mood: String) -> void:
	var wizard := character_sprite.get_node_or_null("Wizard")
	if wizard == null:
		return
	var head := wizard.get_node_or_null("Head")
	var mouth := wizard.get_node_or_null("Mouth")
	var orb := wizard.get_node_or_null("Orb")
	var star := wizard.get_node_or_null("HatStar")
	match mood:
		MOOD_NORMAL:
			if mouth: mouth.visible = true
			character_sprite.modulate = Color.WHITE
			if orb: orb.modulate = Color.WHITE
		MOOD_THINK:
			if mouth: mouth.visible = true
			if orb: orb.modulate = ThemeBuilder.COLOR_WARNING
		MOOD_ERROR:
			if mouth: mouth.visible = false
			character_sprite.modulate = Color(1, 0.7, 0.7)
			if orb: orb.modulate = ThemeBuilder.COLOR_DANGER
		MOOD_WIN:
			if mouth: mouth.visible = true
			character_sprite.modulate = Color.WHITE
			if orb: orb.modulate = ThemeBuilder.COLOR_ACCENT
			if star:
				var t := create_tween().set_loops(3)
				t.tween_property(star, "scale", Vector2(1.5, 1.5), 0.15)
				t.tween_property(star, "scale", Vector2(1, 1), 0.15)

func _load_level(level_id: int) -> void:
	if level_id >= LevelManager.levels.size():
		_show_victory()
		return
	
	var ld = LevelManager.levels[level_id]
	chapter_label.text = ld.chapter
	level_label.text = "第 " + str(level_id + 1) + " 关：" + ld.title
	knowledge_label.text = "知识点：" + ld.python_knowledge
	prompt_text.text = ld.prompt
	
	# 进度条
	var completed = LevelManager.get_completed_count()
	var total = LevelManager.get_total_levels()
	progress_bar.value = float(completed) / float(total) * 100.0
	progress_label.text = str(completed) + "/" + str(total)
	
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
	character_area.color = ThemeBuilder.COLOR_CARD
	_set_mood(MOOD_NORMAL)
	character_effect.text = ""
	call_deferred("_center_character")

func _on_run() -> void:
	if level_passed:
		return
	
	var code = code_edit.text
	
	if code.strip_edges() == starter_code.strip_edges():
		result_text.text = "[color=orange]代码还没有改动，试试写点代码吧！[/color]"
		return
	
	var syntax_err = PythonRunner.quick_syntax_check(code)
	if syntax_err != "":
		result_text.text = "[color=red]语法提醒：" + syntax_err + "[/color]"
		_shake_character()
		SoundManager.play_error()
		return

	run_btn.disabled = true
	run_btn.text = "运行中..."
	result_text.text = "[color=gray]正在执行...[/color]"
	SoundManager.play_step()
	
	# 角色等待动画
	character_effect.text = "..."
	character_effect.modulate = Color.GRAY
	
	PythonRunner.execute_code(code)

func _on_execution_finished(output: String, success: bool) -> void:
	run_btn.disabled = false
	run_btn.text = "运行代码"
	
	if not success:
		result_text.text = "[color=red]" + output + "[/color]"
		status_label.text = "运行出错"
		status_label.add_theme_color_override("font_color", ThemeBuilder.COLOR_DANGER)
		character_area.color = Color(0.25, 0.08, 0.08, 1)
		character_effect.text = "出错"
		character_effect.add_theme_color_override("font_color", ThemeBuilder.COLOR_DANGER)
		_set_mood(MOOD_ERROR)
		_shake_character()
		SoundManager.play_error()
		return
	
	if output.strip_edges().is_empty():
		result_text.text = "[color=gray]（代码执行完毕，没有输出）[/color]"
	else:
		result_text.text = "[color=white]" + output + "[/color]"
	
	var ld = LevelManager.levels[current_level_id]
	if PythonRunner.check_output(output, ld.expected_output):
		_pass_level()
	else:
		status_label.text = "输出不匹配，继续尝试"
		status_label.add_theme_color_override("font_color", ThemeBuilder.COLOR_WARNING)
		character_area.color = Color(0.18, 0.14, 0.05, 1)
		character_effect.text = "再想想"
		character_effect.add_theme_color_override("font_color", ThemeBuilder.COLOR_WARNING)
		_set_mood(MOOD_THINK)

func _pass_level() -> void:
	level_passed = true
	status_label.text = "通关！干得漂亮！"
	status_label.add_theme_color_override("font_color", ThemeBuilder.COLOR_SUCCESS)

	# 角色庆祝
	character_area.color = Color(0.05, 0.18, 0.08, 1)
	_set_mood(MOOD_WIN)
	character_effect.text = "通关！"
	character_effect.add_theme_color_override("font_color", ThemeBuilder.COLOR_SUCCESS)
	_bounce_character()

	# 庆祝粒子
	_spawn_celebration()
	SoundManager.play_success()
	
	# 输出区
	result_text.append_text("\n\n[color=green][b]========== 通关！==========[/b][/color]")
	result_text.append_text("\n[color=green]你掌握了：" + LevelManager.levels[current_level_id].python_knowledge + "[/color]")
	
	LevelManager.complete_level(current_level_id)
	
	# 更新进度条
	var completed = LevelManager.get_completed_count()
	var total = LevelManager.get_total_levels()
	progress_bar.value = float(completed) / float(total) * 100.0
	progress_label.text = str(completed) + "/" + str(total)
	
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
	character_area.color = ThemeBuilder.COLOR_CARD
	_set_mood(MOOD_NORMAL)
	character_effect.text = ""
	call_deferred("_center_character")

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
	celebration_label.text = "🎉 全部通关！🎉"
	celebration_overlay.visible = true
	celebration_label.pivot_offset = celebration_label.size / 2
	var tween = create_tween().set_loops()
	tween.tween_property(celebration_label, "scale", Vector2(1.2, 1.2), 0.5)
	tween.tween_property(celebration_label, "scale", Vector2(1.0, 1.0), 0.5)

# ===== 角色动画 =====

func _bounce_character() -> void:
	if character_animating:
		return
	character_animating = true
	var orig_pos = character_sprite.position
	var tween = create_tween()
	tween.set_parallel(false)
	tween.tween_property(character_sprite, "position:y", orig_pos.y - 30, 0.2).set_trans(Tween.TRANS_SINE)
	tween.tween_property(character_sprite, "position:y", orig_pos.y, 0.2).set_trans(Tween.TRANS_BOUNCE)
	tween.tween_callback(func(): character_animating = false)

func _shake_character() -> void:
	if character_animating:
		return
	character_animating = true
	var orig_pos = character_sprite.position
	var tween = create_tween()
	tween.set_parallel(false)
	for i in 3:
		tween.tween_property(character_sprite, "position:x", orig_pos.x + 8, 0.05)
		tween.tween_property(character_sprite, "position:x", orig_pos.x - 8, 0.05)
	tween.tween_property(character_sprite, "position:x", orig_pos.x, 0.05)
	tween.tween_callback(func(): character_animating = false)

# ===== 庆祝粒子（程序化彩色圆点）=====

func _spawn_celebration() -> void:
	var colors := [
		ThemeBuilder.COLOR_PRIMARY,
		ThemeBuilder.COLOR_ACCENT,
		ThemeBuilder.COLOR_SUCCESS,
		ThemeBuilder.COLOR_WARNING,
		Color("#FF6B9D"),
		Color("#7FE7D4"),
	]
	for i in 24:
		var particle := Polygon2D.new()
		# 随机：圆 / 五角星
		if randf() < 0.5:
			var pts := PackedVector2Array()
			var r := randf_range(4, 8)
			for j in 12:
				var a := TAU * float(j) / 12.0
				pts.append(Vector2(cos(a) * r, sin(a) * r))
			particle.polygon = pts
		else:
			particle.polygon = ThemeBuilder._make_star_shape(Vector2.ZERO, 5, randf_range(5, 9), randf_range(2, 4))
		particle.color = colors[i % colors.size()]
		particle.position = Vector2(
			character_area.size.x / 2 + randf_range(-60, 60),
			character_area.size.y / 2 + 20
		)
		character_area.add_child(particle)

		var tween := create_tween()
		tween.set_parallel(true)
		var angle := randf_range(-PI, 0)
		var distance := randf_range(60, 130)
		tween.tween_property(particle, "position:x", particle.position.x + cos(angle) * distance, 0.8)
		tween.tween_property(particle, "position:y", particle.position.y + sin(angle) * distance, 0.8)
		tween.tween_property(particle, "rotation", randf_range(-PI, PI), 0.8)
		tween.chain().tween_property(particle, "modulate:a", 0.0, 0.4)
		tween.chain().tween_callback(particle.queue_free)
