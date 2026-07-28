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

func _on_start() -> void:
	# 从第一关开始
	LevelManager.load_level(0)

func _on_level_select() -> void:
	# TODO: 关卡选择界面
	print("关卡选择（待实现）")

func _on_exit() -> void:
	get_tree().quit()
