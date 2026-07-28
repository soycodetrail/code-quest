# 单元测试

用 [GdUnit4](https://github.com/godot-gdunit-labs/gdUnit4) v6.1.3，需要 Godot 4.6.x。

## 跑测试

```bash
./run_tests.sh
```

或直接调 GdUnit4 CLI：

```bash
godot --headless --path . \
    -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
    -a tests/ -c --ignoreHeadlessMode
```

## 测试套件

| 文件 | 覆盖 |
|---|---|
| `test_mini_python.gd` | MiniPython 解释器（7 关回归 + 表达式语义 + 控制流 + 错误处理） |
| `test_level_manager.gd` | 关卡数据完整性、通关进度、reset 逻辑 |

## 写新测试

1. 在 `tests/` 下新建 `test_xxx.gd`
2. 头两行必须是：

```gdscript
class_name TestXxx
extends GdUnitTestSuite
```

3. 每个 `func test_xxx()` 是一个独立用例，用 `assert_int/assert_str/assert_bool/assert_array/assert_dict` 等断言
4. `before_test()` / `after_test()` 钩子做 setup/teardown

参考：[GdUnit4 Asserts 文档](https://mikeschulze.github.io/gdUnit4/)

## 注意

- Godot 4.7 与 GdUnit4 v6.1.3 有 `Class hides a global script class` 兼容问题，固定用 **4.6.1**
- `--ignoreHeadlessMode` 必须加，否则 GdUnit4 拒绝在 headless 下跑（即使没有 UI 测试）
- 测试产物：`reports/report_N/index.html`（HTML 报告）
