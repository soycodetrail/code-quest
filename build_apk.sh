#!/bin/bash
# 一键构建 Android APK（non-gradle 模式，使用 Godot 内置模板）
# 用法：./build_apk.sh [--install]

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

# 探测 Godot 4.6.x
GODOT=""
for candidate in "$HOME/tools/godot461" "godot461" "godot"; do
	if command -v "$candidate" >/dev/null 2>&1 || [ -x "$candidate" ]; then
		GODOT="$candidate"
		break
	fi
done
if [ -z "$GODOT" ]; then
	echo "❌ 找不到 Godot 4.6.x，请装到 ~/tools/godot461 或加 PATH"
	exit 1
fi

# JDK
export JAVA_HOME="${JAVA_HOME:-$HOME/tools/jdk17/Contents/Home}"
export PATH="$JAVA_HOME/bin:$PATH"

# Android SDK
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"

echo "===== Code Quest Android 构建 ====="
echo "Godot:  $GODOT ($($GODOT --version 2>&1 | head -1))"
echo "JDK:    $JAVA_HOME"
echo "SDK:    $ANDROID_HOME"
echo ""

# 必须先创建 build 目录（Godot 不会自动创建）
mkdir -p build

echo ">>> 构建 APK..."
$GODOT --headless --export-debug "Android" build/CodeQuest-debug.apk

if [ ! -f build/CodeQuest-debug.apk ]; then
	echo "❌ APK 构建失败"
	exit 1
fi

SIZE=$(du -h build/CodeQuest-debug.apk | cut -f1)
echo "✅ build/CodeQuest-debug.apk ($SIZE)"

# 可选安装
if [ "$1" == "--install" ]; then
	ADB="$ANDROID_HOME/platform-tools/adb"
	echo ""
	echo ">>> 安装到设备..."
	$ADB devices
	$ADB install -r build/CodeQuest-debug.apk
	echo ">>> 启动..."
	$ADB shell am start -n top.soycodetrail.codequest/com.godot.game.GodotAppLauncher
	echo "✅ 已启动"
fi
