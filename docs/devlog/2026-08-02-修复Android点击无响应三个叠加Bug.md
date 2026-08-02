# 2026-08-02 修复 Android 点击无响应——三个叠加 Bug

> 日期：2026-08-02
> 项目：Code Quest（Godot 4.6 Python 编程闯关游戏）
> 关联：[[06-2026-07-29 修复点击无响应与图标设计]]（之前的错误诊断）

## 问题现象

APK 装到荣耀手机和模拟器上，MainMenu 的"开始闯关"按钮点击无反应。之前（07-29）尝试了渲染器切换、EditText patch 等方案都没解决。

## 真正的根因（三个叠加 Bug）

这不是单一问题，是三个独立的 bug 叠加，每个都会导致点击失败：

### Bug 1：MainMenu.tscn 根节点缺 script 绑定（最根本）

**现象**：`_ready` 从未执行，按钮的 `pressed` 信号从未连接。

**诊断过程**：
1. 在 `_ready` 开头加 `push_warning` + 写文件到 `user://debug.log`
2. Mac headless 跑，发现 warning 没输出 + debug.log 没创建
3. 检查 MainMenu.tscn，发现根节点声明了 `[ext_resource type="Script" path="..." id="1"]` 但**没有 `script = ExtResource("1")`**

```diff
 [node name="MainMenu" type="Control"]
 layout_mode = 3
 anchors_preset = 15
 ...
+script = ExtResource("1")
```

**修复**：加回 `script = ExtResource("1")`。

**验证**：Mac headless 跑后看到 `[MainMenu] MENU READY start` + `[CodeQuest] MainMenu _ready executed`。

### Bug 2：VBoxContainer 布局未完成，4 个按钮全堆在同一位置

**现象**：`_ready` 执行了，日志显示所有按钮的 `get_global_rect()` 完全相同：
```
StartBtn       rect=[P: (500.0, 200.0), S: (240.0, 50.0)]
LevelSelectBtn rect=[P: (500.0, 200.0), S: (240.0, 50.0)]
SettingsBtn    rect=[P: (500.0, 200.0), S: (240.0, 50.0)]
ExitBtn        rect=[P: (500.0, 200.0), S: (240.0, 50.0)]
```

**根因**：VBoxContainer 在 `_ready` 时刻还没完成子节点排列。

**修复**：`call_deferred("_force_layout")` + `vbox.queue_sort()` 强制重排：
```gdscript
func _force_layout() -> void:
    var vbox = get_node_or_null("VBox")
    if vbox:
        vbox.queue_sort()
```

重排后按钮位置正确分开：
```
StartBtn       final rect=[P: (500.0, 200.0), S: (280.0, 50.0)]
LevelSelectBtn final rect=[P: (500.0, 266.0), S: (280.0, 50.0)]
SettingsBtn    final rect=[P: (500.0, 332.0), S: (280.0, 50.0)]
ExitBtn        final rect=[P: (500.0, 398.0), S: (280.0, 50.0)]
```

### Bug 3：stretch/mode="canvas_items" 下 Android 触摸坐标映射错误

**现象**：触摸事件进了 Godot（`_input` 被调用），但坐标映射错误：
- 物理点击 `(960, 337)` → Godot 收到 `(640.0, 224.6667)`（偏了）
- 改成 `viewport` 模式后：物理 `(960, 337)` → Godot `(640, 224.67)` ✓ 正确命中按钮

**修复**：`project.godot` 改 `window/stretch/mode="viewport"`。

## 最终验证

```bash
adb shell input tap 960 337
# logcat:
# [MainMenu] #1 touch@(640.0, 224.6667) vp=(1280.0, 720.0) ->START
# [MainMenu] START pressed -> loading level 0
```

**点击成功 → 场景切换到 GameScene → 进入第 1 关。**

## 锁定的配置

```ini
[display]
window/stretch/mode="viewport"

[input_devices]
pointing/emulate_mouse_from_touch=true
pointing/emulate_touch_from_mouse=true

[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
```

## 之前的错误诊断（反面教材）

07-29 花了 3+ 小时在错误方向上：
- ✗ 怀疑渲染器（mobile vs gl_compatibility）—— 不是主因
- ✗ 怀疑 EditText 拦截触摸 —— 不是主因
- ✗ patch GodotEditText smali setClickable(false) —— 没生效
- ✗ 怀疑荣耀 MagicOS ROM 特有问题 —— 不是

**根本错误**：没做最基本的验证（`_ready` 执行了没？script 绑定了没？），直接跳到高级排查。

## 经验总结

### 正确的排查顺序

```
脚本绑定了？→ _ready 执行了？→ 信号连了？→ 布局对吗？→ 坐标映射对吗？
```

从第 1 步开始查，不要跳到第 5 步。

### 具体教训

1. **tscn 根节点必须有 `script = ExtResource("id")`**——声明 ext_resource 不等于绑定
2. **VBoxContainer 在 `_ready` 时布局可能未完成**——需要 `call_deferred` + `queue_sort`
3. **`canvas_items` stretch mode 在 Android 上坐标映射可能错误**——`viewport` 模式更稳
4. **`emulate_mouse_from_touch` 在 Android 上必须开启**——否则触摸不产生 InputEventMouseButton
5. **调试时先验证 `_ready` 有没有执行**（push_warning / 写文件），再查别的
