#!/bin/bash
# 跑全部 GdUnit4 单元测试
# 用法：./run_tests.sh
# 退出码：0 全过 / 非0 有失败

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

# 优先用项目内 godot461，否则回退系统 godot
GODOT=""
if [ -x "$HOME/tools/godot461" ]; then
	GODOT="$HOME/tools/godot461"
elif command -v godot461 >/dev/null 2>&1; then
	GODOT="godot461"
else
	GODOT="godot"
fi

echo "Using: $GODOT ($($GODOT --version 2>&1 | head -1))"
echo "Running GdUnit4 tests..."
echo ""

# 退出码 0 = 全过；100+ = 有失败
$GODOT --headless --path . \
	-s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
	-a tests/ -c --ignoreHeadlessMode

EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
	echo ""
	echo "✅ All tests passed"
else
	echo ""
	echo "❌ Some tests failed (exit code $EXIT_CODE)"
fi
exit $EXIT_CODE
