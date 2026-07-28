extends Control

## 设置页
## - Python backend 切换（桌面可选系统 python3，移动端固定 MiniPython）
## - 音效开关
## - 关于信息

@onready var back_btn: Button = $TopBar/BackBtn
@onready var title: Label = $TopBar/Title

@onready var backend_radio_minipy: CheckBox = $Content/BackendBox/MiniPythonCheck
@onready var backend_radio_python3: CheckBox = $Content/BackendBox/Python3Check
@onready var backend_status: Label = $Content/BackendBox/BackendStatus

@onready var mute_check: CheckBox = $Content/SoundBox/MuteCheck
@onready var test_sound_btn: Button = $Content/SoundBox/TestSoundBtn

@onready var about_text: RichTextLabel = $Content/AboutBox/AboutText

const VERSION := "1.0.0"

func _ready() -> void:
	back_btn.pressed.connect(_on_back)
	back_btn.pressed.connect(SoundManager.play_click)
	test_sound_btn.pressed.connect(_on_test_sound)
	test_sound_btn.pressed.connect(SoundManager.play_click)

	backend_radio_minipy.toggled.connect(_on_minipy_toggled)
	backend_radio_python3.toggled.connect(_on_python3_toggled)

	mute_check.toggled.connect(_on_mute_toggled)
	mute_check.button_pressed = SoundManager.is_muted()

	_init_backend_ui()
	_init_about()

func _init_backend_ui() -> void:
	var real_available: bool = PythonRunner.is_real_python_available()
	var using_real: bool = PythonRunner.is_using_real_python()
	if real_available:
		backend_radio_python3.disabled = false
		backend_status.text = "已检测到系统 python3，桌面端可选用"
		backend_status.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
	else:
		backend_radio_python3.disabled = true
		backend_status.text = "未检测到系统 python3（移动端/Web 默认内置解释器）"
		backend_status.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	# 当前选择
	backend_radio_minipy.set_block_signals(true)
	backend_radio_python3.set_block_signals(true)
	backend_radio_minipy.button_pressed = not using_real
	backend_radio_python3.button_pressed = using_real and real_available
	backend_radio_minipy.set_block_signals(false)
	backend_radio_python3.set_block_signals(false)

func _init_about() -> void:
	var backend := "系统 python3" if PythonRunner.is_using_real_python() else "MiniPython（内置）"
	var platform := OS.get_name()
	about_text.text = "[color=gray]Code Quest[/color] v" + VERSION + "\n\n" \
		+ "在游戏中学 Python——写代码控制角色闯关。\n\n" \
		+ "[color=gray]平台：[/color]" + platform + "\n" \
		+ "[color=gray]Python backend：[/color]" + backend + "\n" \
		+ "[color=gray]引擎：[/color]Godot 4.7"

func _on_minipy_toggled(pressed: bool) -> void:
	if pressed:
		PythonRunner.set_use_real_python(false)
		# 单选互斥
		backend_radio_python3.set_block_signals(true)
		backend_radio_python3.button_pressed = false
		backend_radio_python3.set_block_signals(false)
		SoundManager.play_click()

func _on_python3_toggled(pressed: bool) -> void:
	if pressed:
		if not PythonRunner.is_real_python_available():
			# 不可用，弹回
			backend_radio_python3.set_block_signals(true)
			backend_radio_python3.button_pressed = false
			backend_radio_python3.set_block_signals(false)
			backend_radio_minipy.set_block_signals(true)
			backend_radio_minipy.button_pressed = true
			backend_radio_minipy.set_block_signals(false)
			return
		PythonRunner.set_use_real_python(true)
		backend_radio_minipy.set_block_signals(true)
		backend_radio_minipy.button_pressed = false
		backend_radio_minipy.set_block_signals(false)
		SoundManager.play_click()

func _on_mute_toggled(pressed: bool) -> void:
	# pressed == true 表示用户勾选了静音
	SoundManager.set_muted(pressed)
	if not pressed:
		SoundManager.play_click()

func _on_test_sound() -> void:
	if not SoundManager.is_muted():
		SoundManager.play_success()

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
