extends Control

## 主菜单 - Code Quest
## 全面防御性写法：不依赖 @onready，每步容错，屏幕显示状态

var start_btn: Button = null
var level_select_btn: Button = null
var settings_btn: Button = null
var exit_btn: Button = null
var _debug_label: Label = null
var _touch_count: int = 0

func _ready() -> void:
	# 最先创建调试标签，确保任何后续错误都能在屏幕上看到
	_create_debug_label()
	_log("MENU READY start")
	
	# 查找按钮（容错）
	var vbox = get_node_or_null("VBox")
	if vbox == null:
		_log("ERROR: VBox not found!")
		return
	var child_names: Array = []
	for c in vbox.get_children():
		child_names.append(c.name)
	_log("VBox found, children: %s" % str(child_names))
	
	start_btn = vbox.get_node_or_null("StartBtn")
	level_select_btn = vbox.get_node_or_null("LevelSelectBtn")
	settings_btn = vbox.get_node_or_null("SettingsBtn")
	exit_btn = vbox.get_node_or_null("ExitBtn")
	
	if start_btn == null:
		_log("ERROR: StartBtn not found!")
		return
	
	# 连接信号
	start_btn.pressed.connect(_on_start)
	level_select_btn.pressed.connect(_on_level_select)
	settings_btn.pressed.connect(_on_settings)
	exit_btn.pressed.connect(_on_exit)
	_log("signals connected")
	
	# 打印按钮位置（用于诊断触控映射问题）
	for b in [start_btn, level_select_btn, settings_btn, exit_btn]:
		if b:
			_log("%s rect=%s filter=%d" % [b.name, str(b.get_global_rect()), b.mouse_filter])
	
	set_process_input(true)
	set_process_unhandled_input(true)
	_log("MENU READY done")

func _create_debug_label() -> void:
	_debug_label = Label.new()
	_debug_label.name = "DebugLabel"
	_debug_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_debug_label.position = Vector2(10, 10)
	_debug_label.size = Vector2(1260, 300)
	_debug_label.add_theme_font_size_override("font_size", 22)
	_debug_label.add_theme_color_override("font_color", Color.YELLOW)
	_debug_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_debug_label.add_theme_constant_override("outline_size", 4)
	_debug_label.text = "INIT..."
	_debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_debug_label.z_index = 1000
	add_child(_debug_label)

func _log(msg: String) -> void:
	print("[MainMenu] " + msg)
	if _debug_label:
		_debug_label.text = msg

func _input(event: InputEvent) -> void:
	_handle_touch(event)

func _unhandled_input(event: InputEvent) -> void:
	_handle_touch(event)

func _handle_touch(event: InputEvent) -> void:
	var pos: Vector2 = Vector2.ZERO
	var pressed := false
	
	if event is InputEventScreenTouch:
		var t = event as InputEventScreenTouch
		if t.pressed:
			pos = t.position
			pressed = true
	elif event is InputEventMouseButton:
		var m = event as InputEventMouseButton
		if m.pressed:
			pos = m.position
			pressed = true
	
	if not pressed:
		return
	
	_touch_count += 1
	var dbg = "#%d touch@%s vp=%s" % [_touch_count, str(pos), str(get_viewport_rect().size)]
	_log(dbg)
	
	# 兜底命中检测
	if start_btn and _hit(pos, start_btn):
		_log(dbg + " ->START")
		_on_start()
		get_viewport().set_input_as_handled()
	elif level_select_btn and _hit(pos, level_select_btn):
		_log(dbg + " ->LEVEL")
		_on_level_select()
		get_viewport().set_input_as_handled()
	elif settings_btn and _hit(pos, settings_btn):
		_log(dbg + " ->SETTINGS")
		_on_settings()
		get_viewport().set_input_as_handled()
	elif exit_btn and _hit(pos, exit_btn):
		_log(dbg + " ->EXIT")
		_on_exit()
		get_viewport().set_input_as_handled()

func _hit(pos: Vector2, btn: Button) -> bool:
	return btn.get_global_rect().has_point(pos)

func _on_start() -> void:
	_log("START pressed -> loading level 0")
	LevelManager.load_level(0)
	get_tree().change_scene_to_file("res://scenes/GameScene.tscn")

func _on_level_select() -> void:
	_log("LEVEL pressed")
	get_tree().change_scene_to_file("res://scenes/LevelSelect.tscn")

func _on_settings() -> void:
	_log("SETTINGS pressed")
	get_tree().change_scene_to_file("res://scenes/SettingsScene.tscn")

func _on_exit() -> void:
	_log("EXIT pressed")
	get_tree().quit()
