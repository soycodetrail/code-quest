extends Control

## 关卡选择界面
## 网格展示所有关卡，点击进入

@onready var grid: GridContainer = $Scroll/Grid

const LEVEL_COLORS = [
	Color(0.2, 0.6, 0.3),   # 绿 - 简单
	Color(0.2, 0.6, 0.3),
	Color(0.2, 0.6, 0.3),
	Color(0.8, 0.6, 0.1),   # 橙 - 中等
	Color(0.8, 0.6, 0.1),
	Color(0.8, 0.4, 0.1),   # 深橙 - 偏难
	Color(0.7, 0.2, 0.2),   # 红 - 难
]

func _ready() -> void:
	_build_grid()

func _build_grid() -> void:
	for child in grid.get_children():
		child.queue_free()
	
	for i in range(LevelManager.levels.size()):
		var ld = LevelManager.levels[i]
		var is_completed = i in LevelManager.completed_levels
		var is_locked = i > 0 and (i - 1) not in LevelManager.completed_levels
		
		var card = _create_card(i, ld, is_completed, is_locked)
		grid.add_child(card)

func _create_card(index: int, ld, completed: bool, locked: bool) -> Control:
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(200, 140)
	
	var vbox = VBoxContainer.new()
	vbox.offset_left = 12
	vbox.offset_top = 8
	vbox.offset_right = -12
	vbox.offset_bottom = -8
	vbox.anchors_preset = 15
	vbox.add_theme_constant_override("separation", 6)
	
	# 关卡编号
	var num_label = Label.new()
	num_label.text = "第 " + str(index + 1) + " 关"
	num_label.add_theme_color_override("font_color", LEVEL_COLORS[min(index, LEVEL_COLORS.size()-1)] if not locked else Color(0.3, 0.3, 0.3))
	num_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(num_label)
	
	# 标题
	var title_label = Label.new()
	title_label.text = ld.title
	title_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9) if not locked else Color(0.4, 0.4, 0.4))
	title_label.add_theme_font_size_override("font_size", 15)
	vbox.add_child(title_label)
	
	# 章节
	var chapter_label = Label.new()
	chapter_label.text = ld.chapter
	chapter_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6) if not locked else Color(0.3, 0.3, 0.3))
	chapter_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(chapter_label)
	
	# 状态标记
	var status_label = Label.new()
	if locked:
		status_label.text = "🔒 未解锁"
		status_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	elif completed:
		status_label.text = "✅ 已通关"
		status_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
	else:
		status_label.text = "▶ 可挑战"
		status_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
	status_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(status_label)
	
	panel.add_child(vbox)
	
	# 点击事件
	if not locked:
		panel.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				LevelManager.load_level(index)
				get_tree().change_scene_to_file("res://scenes/GameScene.tscn")
		)
	
	return panel
