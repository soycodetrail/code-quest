extends Node

## 关卡管理器（Autoload 单例）
## 管理关卡数据、加载/切换关卡、通关状态

# 关卡数据结构
class LevelData:
	var id: int
	var chapter: String       # 章节名
	var title: String         # 关卡标题
	var description: String   # 关卡描述
	var python_knowledge: String  # 编程知识点
	var prompt: String        # 关卡任务描述
	var starter_code: String  # 初始代码模板
	var expected_output: String  # 期望输出（用于验证）
	var hint: String          # 提示
	var scene_path: String    # 场景文件路径

# 全部关卡定义
var levels: Array[LevelData] = []
var current_level: int = 0
var completed_levels: Array[int] = []  # 已通关的关卡 ID

func _ready() -> void:
	_init_levels()
	_load_progress()

## 初始化所有关卡数据
func _init_levels() -> void:
	# 第一章：森林入门（基础语法）
	_add_level(0, "第一章 森林入门", "第一步", 
		"让冒险者走到终点。用 print() 输出指令。",
		"print() 函数、基础语法",
		"你的角色站在森林入口，前方有一扇门。\n用 print 函数输出指令让角色前进：\n\nprint(\"前进\")",
		"# 在下面写代码，让角色前进\n\n",
		"前进",
		"提示：print() 是 Python 最基础的函数，括号里放要输出的内容。",
		"res://scenes/levels/Level0.tscn")
	
	_add_level(1, "第一章 森林入门", "变量之门",
		"门上写着密码，你需要用变量记住密码并输出。",
		"变量、数据类型、字符串",
		"石门上刻着数字 42。\n创建一个变量 password 存储这个数字，然后 print 出来。",
		"# 创建变量 password，赋值为 42\n# 然后 print(password)\n\n",
		"42",
		"提示：变量名 = 值，比如 age = 18",
		"res://scenes/levels/Level1.tscn")
	
	_add_level(2, "第一章 森林入门", "岔路口",
		"前面有两条路，左边安全右边有陷阱。根据条件选择正确的路。",
		"if/else 条件判断",
		"变量 road = \"左\" 表示左边安全。\n用 if 判断：如果 road 等于 \"左\"，print(\"走左边\")，否则 print(\"走右边\")。",
		'road = "左"\n# 用 if/else 判断走哪边\n\n',
		"走左边",
		'提示：if 条件:  注意冒号和缩进',
		"res://scenes/levels/Level2.tscn")
	
	# 第二章：迷宫探险（循环）
	_add_level(3, "第二章 迷宫探险", "金币收集",
		"地上有 5 个金币，用循环一个一个捡起来。",
		"for 循环",
		"用 for 循环 5 次，每次 print(\"捡金币\")",
		"# 用 for 循环捡 5 个金币\n\n",
		"捡金币\n捡金币\n捡金币\n捡金币\n捡金币",
		"提示：for i in range(5):",
		"res://scenes/levels/Level3.tscn")
	
	_add_level(4, "第二章 迷宫探险", "计数器",
		"数一数迷宫有多少步，用变量计数。",
		"while 循环、计数器",
		"用 while 循环从 1 数到 10，每步 print 出当前数字。",
		"# 用 while 循环从 1 打印到 10\n\n",
		"1\n2\n3\n4\n5\n6\n7\n8\n9\n10",
		"提示：count = 1\\nwhile count <= 10:",
		"res://scenes/levels/Level4.tscn")
	
	# 第三章：宝藏猎人（数据结构）
	_add_level(5, "第三章 宝藏猎人", "宝藏清单",
		"用列表存储宝藏，遍历输出每个宝藏。",
		"列表（list）",
		"创建一个列表 treasures = [\"金币\", \"宝石\", \"钥匙\"]\n用 for 遍历并 print 每个元素。",
		'# 创建列表并遍历\n\n',
		"金币\n宝石\n钥匙",
		"提示：for item in treasures:",
		"res://scenes/levels/Level5.tscn")
	
	# 第四章：怪物战斗（函数）
	_add_level(6, "第四章 怪物战斗", "攻击函数",
		"定义一个攻击函数，反复调用击败怪物。",
		"函数定义、参数",
		"定义函数 attack(power)，print 出 \"造成 X 点伤害\"\n调用 attack(10) 三次。",
		"# 定义 attack 函数并调用三次\n\n",
		"造成 10 点伤害\n造成 10 点伤害\n造成 10 点伤害",
		"提示：def attack(power):",
		"res://scenes/levels/Level6.tscn")

## 添加关卡
func _add_level(id: int, chapter: String, title: String, description: String, 
		python_knowledge: String, prompt: String, starter_code: String,
		expected_output: String, hint: String, scene_path: String) -> void:
	var ld = LevelData.new()
	ld.id = id
	ld.chapter = chapter
	ld.title = title
	ld.description = description
	ld.python_knowledge = python_knowledge
	ld.prompt = prompt
	ld.starter_code = starter_code
	ld.expected_output = expected_output
	ld.hint = hint
	ld.scene_path = scene_path
	levels.append(ld)

## 加载关卡
func load_level(level_id: int) -> void:
	if level_id < 0 or level_id >= levels.size():
		push_error("无效的关卡 ID: " + str(level_id))
		return
	current_level = level_id

## 关卡完成
func complete_level(level_id: int) -> void:
	if level_id not in completed_levels:
		completed_levels.append(level_id)
	_save_progress()
	print("关卡 " + str(level_id) + " 完成！")

## 获取总关卡数
func get_total_levels() -> int:
	return levels.size()

## 获取完成数
func get_completed_count() -> int:
	return completed_levels.size()

## 保存进度
func _save_progress() -> void:
	var save_data = {
		"completed_levels": completed_levels,
		"current_level": current_level
	}
	var file = FileAccess.open("user://progress.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()

## 读取进度
func _load_progress() -> void:
	var file = FileAccess.open("user://progress.json", FileAccess.READ)
	if file:
		var text = file.get_as_text()
		file.close()
		var data = JSON.parse_string(text)
		if data:
			completed_levels = data.get("completed_levels", [])
			current_level = data.get("current_level", 0)
