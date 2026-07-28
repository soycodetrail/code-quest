extends Node

## AppTheme（Autoload）
## 持有项目全局 Theme 资源；场景进入 tree 时自动套用
## 通过监听 tree_changed 信号捕获场景切换

var theme: Theme
var _initialized: bool = false

func _ready() -> void:
	theme = ThemeBuilder.build()
	_initialized = true
	# 延迟到 SceneTree 就绪，再连接信号 + 应用一次
	call_deferred("_bootstrap")

func _bootstrap() -> void:
	if not _initialized:
		return
	var tree := get_tree()
	if tree == null:
		# 还没就绪，下一帧重试
		call_deferred("_bootstrap")
		return
	tree.tree_changed.connect(_apply_theme_to_current_scene)
	_apply_theme_to_current_scene()

func _apply_theme_to_current_scene() -> void:
	if is_inside_tree() == false:
		return
	var tree := get_tree()
	if tree == null:
		return
	var scene := tree.current_scene
	if scene == null:
		return
	if scene is Control:
		(scene as Control).theme = theme
	if scene.has_node("Background"):
		var bg := scene.get_node("Background")
		if bg is ColorRect:
			(bg as ColorRect).color = ThemeBuilder.COLOR_BG

## 暴露颜色常量给场景用
func color(name: String) -> Color:
	if theme == null:
		return Color.WHITE
	return theme.get_meta(name)
