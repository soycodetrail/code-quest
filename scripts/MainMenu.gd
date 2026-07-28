extends Control

## 主菜单
## Code Quest - Python 编程闯关游戏

@onready var start_btn: Button = $VBox/StartBtn
@onready var level_select_btn: Button = $VBox/LevelSelectBtn
@onready var exit_btn: Button = $VBox/ExitBtn

func _ready() -> void:
	start_btn.pressed.connect(_on_start)
	level_select_btn.pressed.connect(_on_level_select)
	exit_btn.pressed.connect(_on_exit)
	# 全局按钮 hover/press 提示音
	for b in [start_btn, level_select_btn, exit_btn]:
		b.pressed.connect(SoundManager.play_click)

func _on_start() -> void:
	# 从第一关开始
	LevelManager.load_level(0)
	get_tree().change_scene_to_file("res://scenes/GameScene.tscn")

func _on_level_select() -> void:
	get_tree().change_scene_to_file("res://scenes/LevelSelect.tscn")

func _on_exit() -> void:
	get_tree().quit()
