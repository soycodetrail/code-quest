# 01 - 项目创建与 Godot Skills 安装

> 日期：2026-07-22
> 项目：Code Quest（Python 编程闯关游戏）
> 关联：[[00-索引]] · [[02-2026-07-28 P0 核心体验开发]]

## 需求背景

用户想做一款 App，让中小学生在游戏中学 Python 编程——写代码控制角色闯关，从 print 到算法。考察过几个方向后选定 Godot 4.x（开源免费、跨平台、支持 Android）。

## Godot Skills 安装

### godogen —— AI 游戏开发生成器

来源：https://github.com/htdt/godogen

```bash
# 克隆并安装到 ~/tools/godogen
git clone https://github.com/htdt/godogen ~/tools/godogen
```

godogen 提供：
- 项目脚手架（自动生成 CLAUDE.md / godot.md）
- AI 开发指引（告诉 AI 怎么写 GDScript）
- 资产生成 skill（`~/.claude/skills/asset-gen/`）

### Godot Claude Skills

来源 1：https://github.com/htdt/godogen
来源 2：https://github.com/Randroids-Dojo/Godot-Claude-Skills

安装位置：`~/.claude/skills/godot/`

包含的能力：
- **GdUnit4**：GDScript 单元测试框架（P2-2 用到）
- **PlayGodot**：游戏自动化（类似 Playwright）
- **CI/CD**：GitHub Actions 集成
- **Web/Desktop 导出 + 部署**：Vercel / GitHub Pages / itch.io

SKILL.md 头部快速参考：
```bash
# GdUnit4 单元测试
godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests/ -c

# PlayGodot 自动化（Python）
pytest tests/ -v

# Web 导出
godot --headless --export-release "Web" ./build/index.html
```

## 项目骨架搭建

### Godot 版本选择

最终用 **Godot 4.6.1 stable**（不是 4.7）——因为 GdUnit4 v6.1.3 最高兼容 4.6.x，4.7 会触发 "Class hides a global script class" 错误（详见 [[05-2026-07-28 Godot 4.6 Android 导出踩坑]] 的"GdUnit4 兼容性"一节）。

macOS 上多版本共存：
```bash
curl -L -o /tmp/godot-4.6.1.zip "https://github.com/godotengine/godot/releases/download/4.6.1-stable/Godot_v4.6.1-stable_macos.universal.zip"
unzip /tmp/godot-4.6.1.zip -d ~/tools
ln -sf ~/tools/Godot.app/Contents/MacOS/Godot ~/tools/godot461
```

### 项目结构（初始版）

```
code-quest/
├── project.godot              # Godot 4.6 配置
├── CLAUDE.md                  # AI 开发指引（godogen 生成）
├── godot.md                   # Godot 引擎指南
├── icon.svg                   # 项目图标
├── scenes/
│   ├── MainMenu.tscn          # 主菜单
│   ├── GameScene.tscn         # 游戏场景
│   └── LevelSelect.tscn       # 关卡选择
├── scripts/
│   ├── MainMenu.gd
│   ├── GameScene.gd
│   ├── LevelSelect.gd
│   ├── LevelManager.gd        # Autoload：7 关数据 + 进度持久化
│   └── PythonRunner.gd        # Autoload：调系统 python3
└── levels/                    # 关卡场景（待创建）
```

### 核心配置 project.godot

```ini
config_version=5
[application]
config/name="Code Quest"
run/main_scene="res://scenes/MainMenu.tscn"
config/features=PackedStringArray("4.6", "Forward Plus")

[autoload]
LevelManager="*res://scripts/LevelManager.gd"
PythonRunner="*res://scripts/PythonRunner.gd"

[display]
window/size/viewport_width=1280
window/size/viewport_height=720
```

### 关卡设计（初版 7 关）

| 关 | 章节 | 知识点 | 玩法 |
|---|---|---|---|
| 0 | 第一章 森林入门 | print() | 输出指令让角色前进 |
| 1 | 第一章 森林入门 | 变量、数据类型 | 用变量记住密码 |
| 2 | 第一章 森林入门 | if/else | 根据条件选择岔路 |
| 3 | 第二章 迷宫探险 | for 循环 | 循环收集金币 |
| 4 | 第二章 迷宫探险 | while 循环 | 计数器 |
| 5 | 第三章 宝藏猎人 | 列表 | 遍历宝藏清单 |
| 6 | 第四章 怪物战斗 | 函数定义 | 定义攻击函数 |

### 初始 PythonRunner（P1-3 重写）

最初版本直接调系统 python3：
```gdscript
func execute_code(code: String) -> void:
    var tmp_path = "user://code_quest_player.py"
    var file = FileAccess.open(tmp_path, FileAccess.WRITE)
    file.store_string(code)
    file.close()
    var abs_path = ProjectSettings.globalize_path(tmp_path)
    var output = []
    var exit_code = OS.execute("python3", [abs_path], output, true)
    execution_finished.emit("\n".join(output), exit_code == 0)
```

**这个方案的致命问题**：移动端/Web 没有系统 python3，P1-3 时重写为自研 GDScript Python 解释器（详见 [[03-2026-07-28 P1 自研 Python 解释器与沙箱化]]）。

## 经验总结

1. **Godot 版本与 addon 兼容性**：装 addon 前查清兼容版本，GdUnit4 release notes 明确写"4.6.x"
2. **多版本共存**：用 `~/tools/godot<版本号>` 软链，不覆盖 brew 装的版本
3. **Skills 先装再用**：godogen + Godot Skills 提供了脚手架、测试、导出的完整工作流，省去自己摸索
4. **跨平台预判**：游戏目标平台是 Android，Python 执行方案必须在 P1 就解决沙箱化问题
