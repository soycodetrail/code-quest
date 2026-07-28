class_name ThemeBuilder
extends Node

## ThemeBuilder
## 程序化构建 Code Quest 的 flat design 主题
## 调用 build() 返回 Theme 资源，供所有场景共用
##
## 配色（深色冒险者主题）：
##   主色（冒险者蓝紫）：#5B7FFF
##   通关金：              #FFB347
##   危险红：              #E5484D
##   成功绿：              #46A758
##   背景：                #13141A
##   卡片：                #1C1E26
##   文字主：              #E4E4E7
##   文字次：              #8B8D93

const COLOR_PRIMARY := Color("#5B7FFF")
const COLOR_ACCENT := Color("#FFB347")
const COLOR_DANGER := Color("#E5484D")
const COLOR_SUCCESS := Color("#46A758")
const COLOR_WARNING := Color("#F5A623")
const COLOR_BG := Color("#13141A")
const COLOR_CARD := Color("#1C1E26")
const COLOR_CARD_HOVER := Color("#262833")
const COLOR_TEXT := Color("#E4E4E7")
const COLOR_TEXT_DIM := Color("#8B8D93")
const COLOR_BORDER := Color("#2D2F38")

static func build() -> Theme:
	var theme := Theme.new()

	# === 颜色 ===
	theme.set_color("font_color", "Label", COLOR_TEXT)
	theme.set_color("font_color", "Button", COLOR_TEXT)
	theme.set_color("font_color", "LineEdit", COLOR_TEXT)
	theme.set_color("font_color", "CodeEdit", COLOR_TEXT)
	theme.set_color("font_color", "RichTextLabel", COLOR_TEXT)
	theme.set_color("font_color", "CheckBox", COLOR_TEXT)
	theme.set_color("font_hover_color", "Button", COLOR_TEXT)
	theme.set_color("font_pressed_color", "Button", COLOR_TEXT)
	theme.set_color("font_focus_color", "Button", COLOR_PRIMARY)
	theme.set_color("font_disabled_color", "Button", COLOR_TEXT_DIM)

	# === 字体大小 ===
	theme.set_font_size("font_size", "Label", 15)
	theme.set_font_size("font_size", "Button", 16)
	theme.set_font_size("font_size", "LineEdit", 15)
	theme.set_font_size("font_size", "CodeEdit", 15)
	theme.set_font_size("font_size", "CheckBox", 15)
	theme.set_font_size("font_size", "RichTextLabel", 15)

	# === Button：flat style ===
	var btn_normal := _make_flat_style(COLOR_CARD, COLOR_BORDER, 1)
	var btn_hover := _make_flat_style(COLOR_CARD_HOVER, COLOR_PRIMARY, 1)
	var btn_pressed := _make_flat_style(COLOR_PRIMARY, COLOR_PRIMARY, 1)
	var btn_disabled := _make_flat_style(COLOR_CARD, COLOR_BORDER, 0)
	var btn_focus := _make_flat_style(COLOR_CARD, COLOR_PRIMARY, 2)
	theme.set_stylebox("normal", "Button", btn_normal)
	theme.set_stylebox("hover", "Button", btn_hover)
	theme.set_stylebox("pressed", "Button", btn_pressed)
	theme.set_stylebox("disabled", "Button", btn_disabled)
	theme.set_stylebox("focus", "Button", btn_focus)

	# === Panel ===
	var panel_style := _make_flat_style(COLOR_CARD, COLOR_BORDER, 1, 8)
	theme.set_stylebox("panel", "Panel", panel_style)

	# === CheckBox ===
	theme.set_color("font_color", "CheckBox", COLOR_TEXT)
	theme.set_color("font_hover_color", "CheckBox", COLOR_TEXT)
	var cb_normal := _make_flat_style(Color(0, 0, 0, 0), COLOR_BORDER, 1, 3)
	var cb_checked := _make_flat_style(COLOR_PRIMARY, COLOR_PRIMARY, 1, 3)
	theme.set_stylebox("normal", "CheckBox", cb_normal)
	theme.set_stylebox("hover", "CheckBox", cb_normal)
	theme.set_stylebox("pressed", "CheckBox", cb_normal)
	theme.set_stylebox("checked", "CheckBox", cb_checked)
	theme.set_stylebox("checked_hover", "CheckBox", cb_checked)

	# === LineEdit / CodeEdit ===
	var edit_normal := _make_flat_style(COLOR_CARD, COLOR_BORDER, 1, 4)
	var edit_focus := _make_flat_style(COLOR_CARD, COLOR_PRIMARY, 2, 4)
	theme.set_stylebox("normal", "LineEdit", edit_normal)
	theme.set_stylebox("focus", "LineEdit", edit_focus)
	theme.set_stylebox("normal", "CodeEdit", edit_normal)
	theme.set_stylebox("focus", "CodeEdit", edit_focus)
	theme.set_stylebox("read_only", "CodeEdit", _make_flat_style(Color(0.08, 0.09, 0.12), COLOR_BORDER, 1, 4))

	# === ProgressBar ===
	var pb_bg := _make_flat_style(COLOR_CARD, COLOR_BORDER, 1, 8)
	var pb_fill := _make_flat_style(COLOR_SUCCESS, COLOR_SUCCESS, 0, 8)
	theme.set_stylebox("background", "ProgressBar", pb_bg)
	theme.set_stylebox("fill", "ProgressBar", pb_fill)
	theme.set_color("font_color", "ProgressBar", COLOR_TEXT)

	# === ScrollContainer / Scrollbar ===
	var sb_bg := _make_flat_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0)
	theme.set_stylebox("panel", "ScrollContainer", sb_bg)
	var sb_normal := _make_flat_style(COLOR_BORDER, Color(0, 0, 0, 0), 0, 4)
	var sb_hover := _make_flat_style(COLOR_TEXT_DIM, Color(0, 0, 0, 0), 0, 4)
	theme.set_stylebox("scroll", "VScrollBar", sb_normal)
	theme.set_stylebox("scroll", "HScrollBar", sb_normal)
	theme.set_stylebox("hover", "VScrollBar", sb_hover)
	theme.set_stylebox("hover", "HScrollBar", sb_hover)
	theme.set_stylebox("grabber", "VScrollBar", _make_flat_style(COLOR_TEXT_DIM, Color(0, 0, 0, 0), 0, 4))
	theme.set_stylebox("grabber_highlight", "VScrollBar", _make_flat_style(COLOR_PRIMARY, Color(0, 0, 0, 0), 0, 4))

	# === ConfirmationDialog ===
	theme.set_color("font_color", "Dialog", COLOR_TEXT)
	theme.set_stylebox("panel", "Window", _make_flat_style(COLOR_CARD, COLOR_BORDER, 1, 8))

	# === 颜色常量对外暴露 ===
	theme.set_meta("primary", COLOR_PRIMARY)
	theme.set_meta("accent", COLOR_ACCENT)
	theme.set_meta("danger", COLOR_DANGER)
	theme.set_meta("success", COLOR_SUCCESS)
	theme.set_meta("warning", COLOR_WARNING)
	theme.set_meta("bg", COLOR_BG)
	theme.set_meta("card", COLOR_CARD)
	theme.set_meta("text", COLOR_TEXT)
	theme.set_meta("text_dim", COLOR_TEXT_DIM)
	theme.set_meta("border", COLOR_BORDER)

	return theme

## flat StyleBox：bg_color + 边框 + 圆角
static func _make_flat_style(bg: Color, border: Color, border_w: int, radius: int = 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_width_left = border_w
	s.border_width_top = border_w
	s.border_width_right = border_w
	s.border_width_bottom = border_w
	s.border_color = border
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	s.content_margin_left = 12
	s.content_margin_top = 8
	s.content_margin_right = 12
	s.content_margin_bottom = 8
	return s

## 角色立绘：用矢量绘制一个像素感小法师（圆头 + 三角帽 + 长袍）
## 返回一个 Node2D，可 add_child 到任意 Control 下
static func make_character_sprite() -> Node2D:
	var root := Node2D.new()
	root.name = "Character"

	# 长袍（梯形）
	var robe := Polygon2D.new()
	robe.polygon = PackedVector2Array([
		Vector2(-18, 12), Vector2(18, 12),
		Vector2(14, 38), Vector2(-14, 38),
	])
	robe.color = COLOR_PRIMARY
	robe.name = "Robe"
	root.add_child(robe)

	# 头部（圆）
	var head := Polygon2D.new()
	var head_pts := PackedVector2Array()
	for i in 14:
		var a := TAU * float(i) / 14.0
		head_pts.append(Vector2(cos(a) * 14, sin(a) * 14 - 6))
	head.polygon = head_pts
	head.color = Color("#FFD8B5")  # 肤色
	head.name = "Head"
	root.add_child(head)

	# 帽子（三角形）
	var hat := Polygon2D.new()
	hat.polygon = PackedVector2Array([
		Vector2(-16, -10), Vector2(16, -10), Vector2(0, -34),
	])
	hat.color = Color(COLOR_PRIMARY.r * 0.7, COLOR_PRIMARY.g * 0.7, COLOR_PRIMARY.b * 0.7)
	hat.name = "Hat"
	root.add_child(hat)

	# 帽尖星星
	var star := Polygon2D.new()
	star.polygon = _make_star_shape(Vector2(0, -34), 5, 5, 2)
	star.color = COLOR_ACCENT
	star.name = "HatStar"
	root.add_child(star)

	# 眼睛
	var eye_l := Polygon2D.new()
	eye_l.polygon = PackedVector2Array([
		Vector2(-7, -8), Vector2(-3, -8), Vector2(-3, -4), Vector2(-7, -4),
	])
	eye_l.color = Color("#1A1A1A")
	eye_l.name = "EyeL"
	root.add_child(eye_l)
	var eye_r := Polygon2D.new()
	eye_r.polygon = PackedVector2Array([
		Vector2(3, -8), Vector2(7, -8), Vector2(7, -4), Vector2(3, -4),
	])
	eye_r.color = Color("#1A1A1A")
	eye_r.name = "EyeR"
	root.add_child(eye_r)

	# 表情（默认隐藏，由 GameScene 按 mood 切换）
	var mood := Polygon2D.new()
	mood.polygon = PackedVector2Array([
		Vector2(-4, 2), Vector2(4, 2), Vector2(0, 4),
	])
	mood.color = Color("#1A1A1A")
	mood.name = "Mouth"
	mood.visible = true
	root.add_child(mood)

	# 法杖（细矩形 + 顶端球）
	var staff := Polygon2D.new()
	staff.polygon = PackedVector2Array([
		Vector2(20, -10), Vector2(23, -10), Vector2(23, 30), Vector2(20, 30),
	])
	staff.color = Color("#8B6F3F")
	staff.name = "Staff"
	root.add_child(staff)
	var orb := Polygon2D.new()
	var orb_pts := PackedVector2Array()
	for i in 10:
		var a := TAU * float(i) / 10.0
		orb_pts.append(Vector2(cos(a) * 4 + 21.5, sin(a) * 4 - 12))
	orb.polygon = orb_pts
	orb.color = COLOR_ACCENT
	orb.name = "Orb"
	root.add_child(orb)

	return root

## 程序化生成五角星 Polygon2D 顶点
static func _make_star_shape(center: Vector2, points: int, outer_r: float, inner_r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(points * 2):
		var r := outer_r if i % 2 == 0 else inner_r
		var a := TAU * float(i) / float(points * 2) - PI / 2.0
		pts.append(Vector2(center.x + cos(a) * r, center.y + sin(a) * r))
	return pts
