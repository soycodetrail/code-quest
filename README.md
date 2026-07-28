# 🎮 Code Quest - Python 编程闯关游戏

> 在游戏中学 Python——写代码控制角色闯关，从基础语法到算法实战。

## 游戏概念

玩家扮演一个冒险者，在奇幻世界中通过编写 Python 代码来解决谜题、击败怪物、收集宝藏。

## 技术架构

- 引擎：Godot 4.7
- 语言：GDScript（游戏逻辑）+ Python（玩家输入的代码）
- Python 执行：通过 OS.execute 调用系统 python3（user:// 临时文件 + globalize_path）
- 进度保存：JSON 文件（user://progress.json）

## 项目结构

```
code-quest/
├── project.godot                # Godot 项目配置
├── CLAUDE.md                    # AI 开发指引
├── godot.md                     # Godot 引擎指南
├── scenes/
│   ├── MainMenu.tscn            # 主菜单
│   ├── GameScene.tscn           # 游戏场景（代码编辑器 + 角色 + 庆祝动画）
│   └── LevelSelect.tscn         # 关卡选择
├── scripts/
│   ├── MainMenu.gd              # 主菜单逻辑
│   ├── GameScene.gd             # 游戏场景逻辑
│   ├── LevelSelect.gd           # 关卡选择逻辑
│   ├── LevelManager.gd          # 关卡管理器（Autoload 单例）
│   ├── PythonRunner.gd          # Python 代码执行器（Autoload 单例）
│   └── PythonSyntaxHighlighter.gd  # Python 语法高亮
├── levels/                      # 关卡场景（待创建）
└── assets/                      # 美术资源
```

## 关卡设计（7 关，渐进式）

| 章节 | 关卡 | 编程知识点 | 玩法 |
|------|------|-----------|------|
| 第一章 森林入门 | 第一步 | print() | 输出指令让角色前进 |
| 第一章 森林入门 | 变量之门 | 变量、数据类型 | 用变量记住密码 |
| 第一章 森林入门 | 岔路口 | if/else | 根据条件选择岔路 |
| 第二章 迷宫探险 | 金币收集 | for 循环 | 循环收集金币 |
| 第二章 迷宫探险 | 计数器 | while 循环 | 计数器从 1 到 10 |
| 第三章 宝藏猎人 | 宝藏清单 | 列表（list） | 遍历宝藏清单 |
| 第四章 怪物战斗 | 攻击函数 | 函数定义 | 定义攻击函数 |

## P0 已完成的核心体验

- **Python 语法高亮**：关键字（蓝）/字符串（绿）/注释（灰）/数字（橙）/内置函数（紫）
- **角色可视化反馈**：🧙 法师精灵，等待/出错/思考/通关四种表情 + 弹跳/抖动动画
- **进度条**：顶部实时显示 X/7 通关进度
- **通关庆祝动画**：彩色粒子向上迸发 + 全屏通关弹层

## 平台

- Android（手机/平板）
- Windows（桌面）
- macOS（桌面）
