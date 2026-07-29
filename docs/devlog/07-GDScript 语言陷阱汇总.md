# 07 - GDScript 语言陷阱汇总

> 关联：[[03-2026-07-28 P1 自研 Python 解释器与沙箱化]]
> 这一篇汇集 Code Quest 开发中踩到的所有 GDScript 语法/类型陷阱，按主题归类，方便以后查。

## 类型推断陷阱

### `:=` 推断 Variant 报错

项目开启严格模式时（Godot 4.6 比 4.7 更严），`:=` 推断 Variant 值报错。

```gdscript
# 错：函数返回 Variant/Dictionary 时
var r := _interp.execute(code)
# Parse Error: Cannot infer the type of "r" variable because the value doesn't have a set type

# 对：显式类型
var r: Dictionary = _interp.execute(code)
```

**触发场景**：
- 函数返回类型是 `Variant` / 无类型
- 函数返回 `Dictionary`（GDScript 推断不出具体类型）
- `min(a, b)` / `max(a, b)` 等返回 Variant 的内建

### `min` / `max` 返回 Variant

```gdscript
var fade := min(900, dur / 4)
# 报错：Cannot infer the type of "fade" variable

# 对：
var fade: int = min(900, dur / 4)
```

## 关键字冲突

### 方法名 `match` 与 match 语句冲突

```gdscript
# 错：方法名 match
func match(type_: String, value = null) -> bool:
    ...

# 调用时 GDScript 把 match 当语句关键字
match("OP", ":")  # Parse Error: Expected closing ")"
```

**修复**：改名 `_match`。同理避开 `for` / `in` / `if` / `else` / `while` / `return` / `class` / `extends` / `signal` / `enum` / `const` 等。

### 变量名 `in` 冲突

```gdscript
for in in range(10):  # 报错
    ...
```

**避免**用关键字做变量名。

## 不合法的语法

### `_ = expr` 不是合法赋值

Python 习惯用 `_ = func_call()` 丢弃返回值，GDScript 不支持 `_` 作为赋值目标。

```gdscript
# 错：
_ = _eval(node["expr"])
# Parse Error: Expected statement, found "_" instead

# 对：直接调用
_eval(node["expr"])
```

### `-> null` 不是合法返回类型

返回类型注解只能用具体类型或 `void`。

```gdscript
# 错：
func _builtin_print(arg_nodes) -> null:

# 对：
func _builtin_print(arg_nodes) -> void:
```

## API 变更（3.x → 4.x）

### `Color.darker()` / `Color.lighter()` 不存在

Godot 4.x 删了 3.x 的这两个方法。

```gdscript
# 错（3.x）：
hat.color = COLOR_PRIMARY.darker(0.2)

# 对（4.x）：手动算 RGB
hat.color = Color(COLOR_PRIMARY.r * 0.7, COLOR_PRIMARY.g * 0.7, COLOR_PRIMARY.b * 0.7)
```

### `String.isdigit()` 不存在

```gdscript
# 错：
line_text[pos].isdigit()

# 对：
line_text[pos].is_valid_int()
```

## typed array 与 untyped array 不一致

### `String.split()` 返回 `PackedStringArray` 不是 `Array`

```gdscript
var parts = "a,b,c".split(",")  # PackedStringArray
parts[0]  # ✓
parts.size()  # ✓
# 但：
for p in parts: ...  # 类型是 String，OK
# 自定义函数要 Array 类型时：
func handler(arr: Array): ...
handler(parts)  # ✗ 类型不匹配
```

### `Dictionary.keys()` 返回 typed array

```gdscript
var d = {"a": 1}
var keys = d.keys()  # typed Array，不是普通 Array
# 自定义 _py_str(arr: Array) 检查 `arr is Array` 可能失败
```

### 修复：手动转普通 Array

```gdscript
func _string_method(s, method, args):
    match method:
        "split":
            var raw = s.split(args[0])  # PackedStringArray
            var arr: Array = []
            for x in raw: arr.append(x)
            return arr

func _dict_method(d, method, args):
    match method:
        "keys":
            var arr: Array = []
            for k in d.keys(): arr.append(k)
            return arr
```

## JSON 反序列化 typed array

```gdscript
var completed_levels: Array[int] = []
var data = JSON.parse_string(text)
# 错：
completed_levels = data.get("completed_levels", [])
# Trying to assign an array of type "Array" to a variable of type "Array[int]"

# 对：循环显式 cast
var loaded = data.get("completed_levels", [])
completed_levels.clear()
for v in loaded:
    completed_levels.append(int(v))
```

## Autoload 生命周期

### Autoload `_ready` 时 SceneTree 还没就绪

```gdscript
# 错：
func _ready() -> void:
    get_tree().tree_changed.connect(...)  # get_tree() 返回 null
    _apply_theme_to_current_scene()  # current_scene 是 null

# 对：延迟 + null guard
func _ready() -> void:
    theme = ThemeBuilder.build()
    call_deferred("_bootstrap")

func _bootstrap() -> void:
    var tree := get_tree()
    if tree == null:
        call_deferred("_bootstrap")  # 下一帧重试
        return
    tree.tree_changed.connect(_apply_theme_to_current_scene)
    _apply_theme_to_current_scene()

func _apply_theme_to_current_scene() -> void:
    if is_inside_tree() == false: return  # 关键 null guard
    var scene := get_tree().current_scene
    if scene == null: return
    ...
```

## class_name 全局类

### `class_name` 必须在头一行

```gdscript
# 错：其他脚本引用 ThemeBuilder 报 "Identifier not declared"
extends Node
class_name ThemeBuilder

# 对：
class_name ThemeBuilder
extends Node
```

### 加了 class_name 后要重新 import

Godot 缓存全局类名，新增/修改 class_name 后必须 `rm -rf .godot && godot --headless --import` 让 Godot 重新扫描，否则报 "Identifier not found"。

## 编辑器 API（仅编辑器内）

### `EditorInterface.get_export_preset_count()` 在 4.6 不存在

我尝试用 EditorPlugin 脚本调 export API，结果：
```
Invalid call. Nonexistent function 'get_export_preset_count' in base 'EditorInterface'
```

Godot 4.6 的 `EditorInterface` 没有 export preset 操作 API。要做自动化 export，必须用 CLI `godot --export-debug`，不能通过脚本。

## Godot 内建函数行为

### `pow()` 总返回 float

```gdscript
print(pow(2, 10))  # 1024.0（不是 1024）
```

Python 整数幂应返回 int。如果实现 Python 解释器，整数底 + 整数指数要手动走循环乘法。

### `fmod()` 行为与 Python `%` 不同

Python 的 `%` 结果与被除数同号，GDScript 的 `fmod` 不：
```gdscript
# Python: -7 % 3 == 2
# GDScript: fmod(-7, 3) == -1

# 对齐 Python：
func _py_mod(l, r):
    var m = fmod(l, r)
    if (m < 0 and r > 0) or (m > 0 and r < 0):
        m += r
    return int(m) if (l is int and r is int) else m
```

## 编辑器与 headless 行为差异

### `--headless` 不写 godot.log

`~/Library/Application Support/Godot/app_userdata/<项目>/logs/godot.log` 在 headless 模式下**不更新**。排查 headless 问题要看 stdout/stderr，不能依赖 godot.log。

### `--headless` 跳过 `tree_changed` 信号的部分行为

某些信号在 headless 下不触发，Autoload 自动套主题的逻辑可能失效。验证 UI 时要用 GUI 模式跑 `--quit-after N`。

## 经验总结

1. **严格模式开启时 `:=` 推断 Variant 必报错**，函数返回 Variant 一律显式类型
2. **方法名避开所有 GDScript 关键字**（match/for/in/if 等）
3. **`String.split` / `Dictionary.keys` 返回 typed array**，跨函数边界要转普通 Array
4. **`class_name` 加在头一行 + 改完重新 import**
5. **Autoload `_ready` 不能直接 `get_tree()`**，用 `call_deferred` + null guard
6. **Godot 4.x 删了不少 3.x API**（`Color.darker` / `String.isdigit`），迁移要查文档
