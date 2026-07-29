# Code Quest v1.0.0 全程开发实录——Godot 4.6 Python 编程闯关游戏

> 项目：https://github.com/soycodetrail/code-quest
> 环境：macOS 26.5.1 (Apple Silicon M3 Max) / Godot 4.6.1 stable（手动下载共存，未覆盖 brew 装的 4.7.1）/ JDK Temurin 17.0.13 / Android SDK 36 + NDK 28.2 / GdUnit4 v6.1.3
> 日期：2026-07-28
> 产出：12 关 Python 闯关游戏 + 51 单元测试 + 55.7MB 签名 APK + GitHub Release v1.0.0
> 关键创新：自研 GDScript Python 解释器（MiniPython，1100 行），跨平台零依赖

## 整体里程碑

| 阶段 | 交付 |
|---|---|
| **P0** | Python 语法高亮 / 角色可视化反馈（矢量法师 + 4 种表情 + 弹跳抖动动画）/ 进度条 / 通关庆祝动画（24 颗彩色粒子 + 全屏弹层） |
| **P1** | 音效（AudioStreamGenerator 实时合成）/ LevelSelect 完善（返回 + 重置进度 + 二次确认）/ **代码沙箱化——自研 GDScript Python 解释器** |
| **P2** | 设置页（backend 切换 + 静音 + 关于）/ GdUnit4 单元测试（51 用例）/ 程序化美术（flat design 主题）/ 扩展 MiniPython（dict + str/list/dict 方法 + in 运算符）+ 5 个新关卡 / **Android APK 导出并发布 GitHub Release** |

## 项目维度数据

| 维度 | 数据 |
|---|---|
| 关卡数 | 12 关（4 章 → 7 章） |
| Python 子集 | print / 变量 / if-elif-else / while / for / list / dict / 函数 / 字符串方法 / in |
| 测试 | 51 GdUnit4 用例，0 失败 |
| 代码量 | GDScript ~3500 行（含 1100 行自研 Python 解释器） |
| 美术 | 程序化 flat design 主题 + 矢量法师立绘（零外部资源） |
| 音效 | AudioStreamGenerator 实时合成（无音频文件） |
| APK | 55.7 MB，arm64-v8a / armeabi-v7a / x86 / x86_64 全 ABI |
| 跨平台 | Android ✅ / iOS / macOS / Windows / Linux / Web |

---

## 新开发的功能（按模块）

### 1. 自研 Python 解释器（MiniPython）

**位置**：`scripts/MiniPythonInterpreter.gd`（1100+ 行，`class_name MiniPythonInterpreter`）

**为什么自研**：移动端 / Web 没有系统 python3。三个备选方案的取舍：

| 方案 | 优点 | 缺点 | 决策 |
|---|---|---|---|
| Pyodide (WASM) | 完整 Python | APK 增 8MB，首次加载慢 | ✗ |
| 服务端执行 | 可扩展（多语言/评测） | 依赖网络 + 维护安全沙箱 | ✗ |
| **GDScript 子集解释器** | 零依赖、跨平台一致、离线可用 | 只支持教学子集 | ✓ |

**架构**：双 backend，自动按平台选择
- 桌面（macOS/Windows/Linux）：优先系统 `python3`，失败回退 MiniPython
- 移动/Web：直接用 MiniPython

**实现分层**：
- Lexer：每行首插 BOLO token 携带 indent → 转 INDENT/DEDENT
- Parser：递归下降，优先级 `or < and < not < 比较 < +- < */%// < 一元 < ** < 后缀`
- Interpreter：AST 树遍历，globals Dictionary 做环境，函数调用栈切换保存

**覆盖的语法**：
- 字面量：int / float / string（含转义）/ bool / None / list / dict
- 运算符：`+ - * / // % **`、比较、`and/or/not`、一元 `-`、字符串拼接/重复
- 索引/切片：负索引、`s[a:b]`、`s[:b]`、`s[a:]`
- 控制流：`if/elif/else`、`while`、`for x in <list|range|string|dict>`、`break/continue/pass`
- 函数：`def`、`return`、嵌套调用、参数栈隔离
- 内建：`print/input/len/range/int/str/float/abs/min/max/sum`
- 方法：`str.upper/lower/strip/replace/split/startswith/endswith/find/count/join` 等
- 方法：`list.append/pop/remove/sort/reverse/count/index/extend/insert/copy`
- 方法：`dict.keys/values/get/pop`
- `in / not in` 运算符

**安全**：1M 步上限 + 1M while 上限，防玩家死循环
**错误**：未定义变量、语法、缩进、越界都给中文 + 行号

### 2. 程序化美术系统（ThemeBuilder + AppTheme）

**为什么程序化**：参考 LightBot / CodeCombat / Swift Playgrounds 的 flat design 风格，零外部资源、跨平台渲染一致、无版权风险。

**ThemeBuilder.gd**（`class_name`）：
- 配色系统：冒险者蓝紫 `#5B7FFF` / 通关金 `#FFB347` / 危险红 / 成功绿 / 警告橙
- 8 个颜色常量通过 `theme.set_meta` 暴露
- StyleBoxFlat 程序化构建：Button / Panel / CheckBox / LineEdit / CodeEdit / ProgressBar / Scrollbar / Dialog
- `make_character_sprite()`：Polygon2D 组合的法师立绘
  - 长袍梯形 + 圆头（14 边形近似圆）+ 三角帽 + 帽尖五角星
  - 双眼 + 嘴 + 法杖（细矩形 + 法球）
  - 4 种 mood（normal/think/error/win）通过 orb 颜色 + 整体 modulate 切换

**AppTheme.gd**（Autoload）：
- `_ready` 构建 Theme，监听 `tree_changed` 信号捕获场景切换自动套用
- 给每个进入 SceneTree 的 Control 根节点设 theme + 背景设 COLOR_BG
- `is_inside_tree()` null guard 避免 Autoload 早于 SceneTree 就绪

### 3. 音效系统（SoundManager）

**位置**：`scripts/SoundManager.gd`（Autoload）

**为什么实时合成**：零音频文件、跨平台一致、APK 不膨胀。

**实现**：用 `AudioStreamGenerator` 推送 PackedVector2Array 正弦波采样
- 4 个 `AudioStreamPlayer` 轮询，避免短音效互相打断
- 每次播放新建 `AudioStreamGenerator` 作为 stream，分段 push_buffer 写采样
- 频率/时长/音量通过 `_t(freq, duration, volume)` 工厂方法构造

**对外 API**：
- `play_click()`：880Hz × 40ms（按钮通用）
- `play_step()`：660Hz × 50ms（代码执行启动）
- `play_success()`：C5-E5-G5-C6 升调琶音（通关）
- `play_error()`：330→220Hz 下降 + 100ms 噪声（出错）
- `toggle_mute()` / `set_muted(v)` / `is_muted()`

### 4. 设置页（SettingsScene）

- Python backend 单选（MiniPython / 系统 python3，移动端自动禁用后者）
- 静音 CheckBox + 试听按钮（直接播 `play_success`）
- 关于信息（版本 / 平台 / 当前 backend 状态 / Godot 版本）

### 5. GdUnit4 单元测试体系

**测试套件**（`tests/` 目录，51 用例）：
- `test_mini_python.gd`：26 用例（7 关回归 + 表达式语义 + 控制流 + 错误处理）
- `test_mini_python_v2.gd`：16 用例（dict + str method + list method + 综合算法）
- `test_level_manager.gd`：6 用例（关卡数据完整性 + 进度逻辑）
- `test_all_levels.gd`：3 用例（端到端验证 12 关示例答案全部能跑出 expected_output）

**入口**：`./run_tests.sh`（自动用 `~/tools/godot461` 或系统 godot）

### 6. 12 关内容设计

| 关 | 章节 | 知识点 | 玩法 |
|---|---|---|---|
| 1-3 | 第一章 森林入门 | print / 变量 / if-else | 控制角色走岔路 |
| 4-5 | 第二章 迷宫探险 | for / while | 循环收集金币 |
| 6 | 第三章 宝藏猎人 | 列表 | 遍历宝藏清单 |
| 7 | 第四章 怪物战斗 | 函数 | 定义攻击函数 |
| 8-9 | 第五章 古堡谜题 | 字典 / dict.get | 怪物属性管理 |
| 10-11 | 第六章 龙之挑战 | 字符串 upper/split | 标准化咒语 |
| 12 | 第七章 终极挑战 | 综合算法 | 词频统计 |

### 7. Android 导出 + 发布

- `export_presets.cfg`：Android preset（gradle build 关闭，用 Godot 内置 APK 模板；min_sdk 24，package=`top.soycodetrail.codequest`）
- `build_apk.sh`：一键构建（`godot --headless --export-debug "Android"`）
- `docs/android-export.md`：完整导出文档（环境/配置/三种方法/签名/移动端验证要点）
- GitHub Release v1.0.0：APK 直链 https://github.com/soycodetrail/code-quest/releases/download/v1.0.0/CodeQuest-v1.0.0-android.apk

---

## 遇到的问题与修复（按踩坑顺序）

### 问题 1：GDScript `match()` 方法名与 `match` 语句关键字冲突

**现象**：MiniPythonInterpreter 编译报 `Parse Error: Expected closing ")" after grouping expression`

**根因**：我给 Parser 类写了个辅助方法 `func match(...)`，但 GDScript 把 `match` 当成 match 语句关键字，调用 `match("OP", ":")` 时解析器懵了。

**修复**：全部改名 `_match()`。perl 批量替换：
```bash
perl -i -pe 's/\bfunc match\b/func _match/g; s/(?<![a-zA-Z_])match\(/_match(/g' scripts/MiniPythonInterpreter.gd
```

**教训**：GDScript 方法命名要避开关键字（`match`、`for`、`in`、`if` 等）。

### 问题 2：GDScript `_ = expr` 不是合法赋值

**现象**：`Parse Error: Expected statement, found "_" instead`

**根因**：Python 习惯用 `_ = func_call()` 丢弃返回值，GDScript 不支持 `_` 作为赋值目标。

**修复**：直接调用，不接收返回值：
```gdscript
# 错：_ = _eval(node["expr"])
# 对：
_eval(node["expr"])
```

### 问题 3：GDScript `-> null` 不是合法返回类型

**现象**：`Parse Error: Expected return type or "void" after "->"`

**根因**：返回类型注解只能用具体类型或 `void`，不能用 `null`。

**修复**：`-> null` 改成 `-> void`。

### 问题 4：GDScript 严格模式 `var x := func_call()` 推断失败

**现象**：`Cannot infer the type of "r" variable because the value doesn't have a set type`

**根因**：项目开启了严格模式（4.6 比 4.7 更严），`:=` 推断 Variant 值报错。当函数返回 `Variant` / 无类型 / `Dictionary` 时都会触发。

**修复**：所有 `var x := ...` 改成显式类型：
```gdscript
# 错：var r := _interp.execute(...)
# 对：
var r: Dictionary = _interp.execute(...)
```

**教训**：Godot 4 项目开启严格模式时，`:=` 推断要小心，函数返回 Variant 必须显式类型。

### 问题 5：GDScript `Color.darker()` 方法不存在

**现象**：`Parse Error: Cannot find member "darker" in base "Color"`

**根因**：Godot 4 的 `Color` 类没有 `.darker()` / `.lighter()` 方法（这是 Godot 3 的 API，4.x 删了）。

**修复**：手动算 RGB：
```gdscript
# 错：hat.color = COLOR_PRIMARY.darker(0.2)
# 对：
hat.color = Color(COLOR_PRIMARY.r * 0.7, COLOR_PRIMARY.g * 0.7, COLOR_PRIMARY.b * 0.7)
```

### 问题 6：Autoload `_ready()` 时 SceneTree 还没就绪

**现象**：`ERROR: Parameter "data.tree" is null. at: get_tree` + `Invalid access to property 'current_scene' on a base object of type 'null instance'`

**根因**：AppTheme Autoload 在 `_ready()` 里调 `get_tree().tree_changed.connect(...)`，但此时 SceneTree 还没完全初始化。`tree_changed` 信号在 SceneTree 就绪前就被触发。

**修复**：
1. 用 `call_deferred("_bootstrap")` 延迟到下一帧
2. `_apply_theme_to_current_scene()` 加 `is_inside_tree()` null guard

```gdscript
func _ready() -> void:
    theme = ThemeBuilder.build()
    call_deferred("_bootstrap")

func _apply_theme_to_current_scene() -> void:
    if is_inside_tree() == false:
        return
    var tree := get_tree()
    if tree == null: return
    ...
```

### 问题 7：LevelManager JSON 反序列化 typed array 不兼容

**现象**：`Trying to assign an array of type "Array" to a variable of type "Array[int]"`

**根因**：`completed_levels` 声明为 `Array[int]`，但 `JSON.parse_string` 返回的是无类型 `Array`，直接赋值类型不匹配。

**修复**：循环显式 cast：
```gdscript
var loaded = data.get("completed_levels", [])
completed_levels.clear()
for v in loaded:
    completed_levels.append(int(v))
```

### 问题 8：GdUnit4 v6.1.3 与 Godot 4.7 不兼容

**现象**：`Parse Error: Class "GdUnitAssertImpl" hides a global script class`，所有 assert 类加载失败。

**根因**：GdUnit4 v6.1.3 最高兼容 Godot 4.6.x。Godot 4.7 收紧了重名 `class_name` 检查，GdUnit4 的 `addons/src/` 和 `addons/gdUnit4/src/` 两份重复代码触发冲突。

**修复**：降级 Godot 4.7 → 4.6.1（手动下载共存，不覆盖 brew 装的 4.7.1）：
```bash
mkdir -p ~/tools
curl -L -o /tmp/godot-4.6.1.zip "https://github.com/godotengine/godot/releases/download/4.6.1-stable/Godot_v4.6.1-stable_macos.universal.zip"
unzip /tmp/godot-4.6.1.zip -d ~/tools
ln -sf ~/tools/Godot.app/Contents/MacOS/Godot ~/tools/godot461
```

同时清理 addons 根下重复的 src/test 目录（之前 `cp -R` 整个 addons 把根目录的也带进来了）。

**教训**：装 addon 前查清兼容版本。GdUnit4 release notes 明确写"4.6.x"，但 4.7 收紧了规则就直接挂。

### 问题 9：GdUnit4 headless 模式默认拒绝运行

**现象**：`Abnormal exit with 103` + `Headless mode is not supported!`

**修复**：加 `--ignoreHeadlessMode` 参数：
```bash
godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests/ -c --ignoreHeadlessMode
```

### 问题 10：GdUnit4 v6 API 改名 `begins_with` → `starts_with`

**现象**：`Nonexistent function 'begins_with' in base 'RefCounted (GdUnitStringAssertImpl.gd)'`

**修复**：测试用例改 `assert_str(...).starts_with(...)`。

### 问题 11：MiniPython 整数幂返回 float

**现象**：测试 `print(2 ** 10)` 输出 `1024.0`，期望 `1024`

**根因**：GDScript 的 `pow()` 总返回 float，但 Python 整数幂应返回 int。

**修复**：整数底 + 整数指数走循环乘法，负指数才退回 float：
```gdscript
if op == "**":
    if l3 is int and r is int:
        var result: int = 1
        var exp_v: int = int(r)
        if exp_v < 0:
            return pow(l3, r)
        for i in range(exp_v):
            result *= int(l3)
        return result
    return pow(l3, r)
```

### 问题 12：String.split / dict.keys 返回 typed array 导致 `_py_str` 走 GDScript 原生格式

**现象**：`print("a,b,c".split(","))` 输出 `["a", "b", "c"]`（双引号 + 空格），期望 `['a', 'b', 'c']`（Python 单引号）

**根因**：Godot 的 `String.split()` 返回 `PackedStringArray`，`Dictionary.keys()` 返回 typed array。我的 `_py_str` 只处理 `Array/Dictionary`，typed array 走 GDScript 原生 `str()` 就成了双引号格式。

**修复**：方法返回前转成普通 Array：
```gdscript
"split":
    var raw = s.split(args[0])
    var arr: Array = []
    for x in raw: arr.append(x)
    return arr

"keys":
    var arr: Array = []
    for k in d.keys(): arr.append(k)
    return arr
```

### 问题 13：MiniPython `for k in dict` 不支持字典迭代

**现象**：`for 不能迭代该类型`

**修复**：`_exec_for` 加 Dictionary 分支（Python 默认迭代 keys）：
```gdscript
elif iter_val is Dictionary:
    for k in iter_val:
        seq.append(k)
```

### 问题 14：`len(dict)` 不支持字典

**现象**：`len: 类型错误`

**修复**：`_call_builtin` 的 BUILTIN_LEN 分支加 Dictionary：
```gdscript
if bi == "BUILTIN_LEN":
    var v: Variant = _eval(arg_nodes[0])
    if v is String: return v.length()
    if v is Array:  return v.size()
    if v is Dictionary: return v.size()  # 新增
```

### 问题 15：Godot 4.6.1 macOS headless 模式 Android export 报"配置错误"且描述为空

**这是本次最难的一个问题。**

**现象**：
```
ERROR: Cannot export project with preset "Android" due to configuration errors:
                                                                              ← 这里应该是错误详情，但是空的
   at: _fs_changed (editor/editor_node.cpp:1332)
```

**排查过程**：
1. 用 `--verbose` / `-e`（editor 模式）/ GUI 模式都试过，错误描述都是空
2. 写 EditorPlugin 脚本调 `EditorInterface.export_project()`——结果 `get_export_preset_count` API 在 4.6 不存在
3. gradle 直接 build 能成功，但 APK 是空 Godot 模板（pck 没注入）

**根因**（最终 Google + GitHub issue 找到）：
- GitHub issue [godotengine/godot#119895](https://github.com/godotengine/godot/issues/119895)
- 项目默认纹理压缩是 S3TC_BPTC，但 **Android preset 要求 ETC2/ASTC**
- `platform/android/export/export_plugin.cpp` 的 `should_import_etc2_astc()` 函数把 `valid` 改成 false 但**没 log 错误信息**——这就是为什么错误描述为空
- 这是 Godot 4.6 的真实 bug

**修复**：`project.godot` 加：
```ini
[rendering]
renderer/rendering_method="mobile"
textures/vram_compression/import_etc2_astc=true
```

加完后 export 立刻给出真正的错误（"目标文件夹不存在"），逐个解决后就 build 出完整 APK。

**教训**：
1. Godot 报错描述为空 ≠ 真的没错误，去 GitHub issue 搜英文错误原文
2. Android export 必须配 ETC2/ASTC 纹理压缩
3. `mkdir -p build/` 提前建目录（Godot 不会自动建）

### 问题 16：GitHub Release 上传大文件在国内网络下卡死

**这是工程教训最重的一条。**

**现象**：`gh release upload` 上传 58MB APK，跑 5-10 分钟仍未完成，assets 一直空。

**根因**（多重叠加）：
1. **大文件 + 国内网络访问 GitHub release 上传域名慢**：`gh` 走 `uploads.github.com`，国内对这个域名访问质量差
2. **`gh` CLI 没有 `--timeout` 参数**：内部 Go http client 默认无超时，弱网下无限等待
3. **我自己制造的死循环**：
   - 第一次 upload 卡住 → kill → 直接重建没等 GitHub 清理 draft
   - 同时 `rm -rf build/` 删了 APK → 后续 upload 找不到文件 → 又是空 asset
   - 状态在并发变化（release 状态、APK 文件、tag），每步不是幂等的

**修复（最终成功）**：
1. 重新 build APK（`godot --headless --export-debug`）
2. `cp` 到独立稳定路径
3. 拆步骤：先 `gh release create`（无 asset）→ 再单独 `gh release upload --clobber`
4. 后台跑 + 耐心等 5 分钟

**总结的避免规则**：
1. **大文件上传必须带超时 + 重试**：`timeout 180 gh release upload ...` 包重试循环
2. **release 流程拆成幂等步骤**：tag → release → upload asset，每步可单独重跑
3. **上传期间不要动文件**：先 `cp` 到 `/tmp/release/`，上传完再清理
4. **国内 >20MB 文件优先走 COS**：腾讯云 COS / 阿里云 OSS 直链比 GitHub release 快 10 倍
5. **监控上传进度**：超 5 分钟主动报错退出，别无限等

---

## 关键工程实践

### 实践 1：headless 验证流程

每个功能做完，三层验证：
```bash
# 1. 编译通过
godot --headless --quit

# 2. 主场景跑 2 帧无错
cp project.godot project.godot.bak
sed -i '' 's|MainMenu.tscn|GameScene.tscn|' project.godot
godot --headless --quit-after 2
mv project.godot.bak project.godot

# 3. GdUnit4 回归
godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests/ -c --ignoreHeadlessMode
```

### 实践 2：临时测试脚本固化

P1-3 时用 `/tmp/test_mini_python.gd` 验证 7 关，跑通后固化成 `tests/test_mini_python.gd` GdUnit4 套件。这种"先用一次性脚本验证、再固化成正式测试"的模式很有效。

### 实践 3：APK 验证链路

```
godot --export-debug → APK 58MB
  ↓
adb install -r → 模拟器 Success
  ↓
adb shell am start -n <pkg>/<activity> → mFocusedApp 指向我们的包
  ↓
adb logcat -d | grep godot → 看到 Godot Engine 启动 + Vulkan 渲染初始化
  ↓
adb exec-out screencap -p > screenshot.png
```

---

## 文件清单

```
code-quest/
├── project.godot                 # features=4.6, autoloads, ETC2/ASTC 配置
├── export_presets.cfg            # Android preset (non-gradle)
├── build_apk.sh                  # 一键构建 APK
├── run_tests.sh                  # 一键跑 GdUnit4
├── scenes/
│   ├── MainMenu.tscn             # 主菜单（+ 设置入口）
│   ├── GameScene.tscn            # 游戏场景（角色 Node2D 立绘）
│   ├── LevelSelect.tscn          # 关卡选择（+ 重置进度）
│   └── SettingsScene.tscn        # 设置页
├── scripts/
│   ├── MainMenu.gd / GameScene.gd / LevelSelect.gd / SettingsScene.gd
│   ├── LevelManager.gd           # Autoload，12 关数据 + 进度持久化
│   ├── PythonRunner.gd           # Autoload，双 backend 调度
│   ├── MiniPythonInterpreter.gd  # 1100 行自研 Python 解释器
│   ├── SoundManager.gd           # Autoload，AudioStreamGenerator 合成
│   ├── ThemeBuilder.gd           # class_name，flat design 主题 + 矢量法师
│   ├── AppTheme.gd               # Autoload，场景切换自动套主题
│   └── PythonSyntaxHighlighter.gd
├── tests/                        # 51 个 GdUnit4 用例
├── addons/gdUnit4/               # 测试框架
└── docs/android-export.md        # 导出文档
```

## 后续可做的方向

1. **真机测试**：装到你手机（A22C015929000089）实测触控 + 中文输入
2. **P3：GitHub Actions CI**：自动跑 GdUnit4 + 自动构建 APK release
3. **更多关卡**：异常处理 / 文件 IO（需要扩 MiniPython）
4. **Web 导出 + 嵌入网站**：用 MiniPython backend，浏览器直接玩
5. **APK 体积优化**：现在 58MB（全 ABI），可只保留 arm64-v8a 降到 ~30MB
6. **release 发布流程脚本化**：按本文"避免规则"封装 `release.sh`

---

## 参考链接

- 项目仓库：https://github.com/soycodetrail/code-quest
- Release v1.0.0：https://github.com/soycodetrail/code-quest/releases/tag/v1.0.0
- Godot 4.6 Android export 空错误 issue：https://github.com/godotengine/godot/issues/119895
- GdUnit4：https://github.com/godot-gdunit-labs/gdUnit4
