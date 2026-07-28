#!/bin/bash
# 一键构建 Android APK
# 用法：./build_apk.sh
#
# 流程：
#   1. Godot 生成 project pck（headless export-pack）
#   2. gradle 把 pck + 资源 + Godot libs 打成 APK
#   3. 可选：自动安装到模拟器
#
# 注意：macOS 沙盒下 godot --headless --export-debug 4.6.1 有 bug，
# 所以分两步走（pck 单独生成 + gradle 单独 build），效果等同。

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

# 探测 Godot
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
if [ ! -d "$JAVA_HOME" ]; then
	echo "❌ 找不到 JDK 17 at $JAVA_HOME"
	echo "   装 JDK 17: brew install --cask temurin@17 或下载到 ~/tools/jdk17"
	exit 1
fi
export PATH="$JAVA_HOME/bin:$PATH"

# Android SDK
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
if [ ! -d "$ANDROID_HOME" ]; then
	echo "❌ 找不到 Android SDK at $ANDROID_HOME"
	exit 1
fi

echo "===== Code Quest Android 构建 ====="
echo "Godot:  $GODOT ($($GODOT --version 2>&1 | head -1))"
echo "JDK:    $JAVA_HOME ($($JAVA_HOME/bin/java -version 2>&1 | head -1))"
echo "SDK:    $ANDROID_HOME"
echo ""

# Step 0: 检查 Godot libs 是否就位（首次运行从 export template 解压）
if [ ! -d android/build/libs ]; then
	echo ">>> Step 0: 解压 Godot Android libs（首次运行）..."
	TEMPLATE_ZIP="$HOME/Library/Application Support/Godot/export_templates/4.6.1.stable/android_source.zip"
	if [ ! -f "$TEMPLATE_ZIP" ]; then
		# 兼容 4.6.0 stable
		TEMPLATE_ZIP="$HOME/Library/Application Support/Godot/export_templates/4.6.stable/android_source.zip"
	fi
	if [ ! -f "$TEMPLATE_ZIP" ]; then
		echo "❌ 找不到 Godot Android export template：$TEMPLATE_ZIP"
		echo "   请在 Godot 编辑器 → 编辑器菜单 → 管理导出模板 中安装 4.6 templates"
		exit 1
	fi
	unzip -o "$TEMPLATE_ZIP" "libs/*" -d android/build/ > /dev/null
	echo "   ✓ android/build/libs/ 就位"
fi

# Step 1: 生成 pck
echo ">>> Step 1: 生成 project pck..."
mkdir -p build
$GODOT --headless --export-pack "Android" build/CodeQuest.pck
if [ ! -f build/CodeQuest.pck ]; then
	echo "❌ pck 生成失败"
	exit 1
fi
echo "   ✓ build/CodeQuest.pck ($(du -h build/CodeQuest.pck | cut -f1))"

# Step 2: gradle build APK
# 把 pck 放到 android assets（gradle 会自动打包）
# Godot 期望 package-name 命名规范，这里直接拷过去
mkdir -p android/build/assets
cp build/CodeQuest.pck android/build/assets/

echo ""
echo ">>> Step 2: gradle 构建 APK（带签名）..."
# 准备 debug keystore（Android 默认 ~/.android/debug.keystore）
KEYSTORE="${DEBUG_KEYSTORE:-$HOME/.android/debug.keystore}"
if [ ! -f "$KEYSTORE" ]; then
	echo "   创建 debug keystore..."
	mkdir -p "$(dirname "$KEYSTORE")"
	keytool -genkey -v -keystore "$KEYSTORE" \
		-storepass android -alias androiddebugkey -keypass android \
		-keyalg RSA -keysize 2048 -validity 10000 \
		-dname "CN=Android Debug,O=Android,C=US"
fi

cd android/build
./gradlew assembleDebug --no-daemon \
	-Pperform_signing=true \
	-Pdebug_keystore_file="$KEYSTORE" \
	-Pdebug_keystore_password=android \
	-Pdebug_keystore_alias=androiddebugkey
cd "$PROJECT_DIR"

APK="android/build/build/outputs/apk/standard/debug/android_debug.apk"
if [ ! -f "$APK" ]; then
	echo "❌ APK build 失败"
	exit 1
fi

# 复制到统一输出目录
cp "$APK" build/CodeQuest-debug.apk
echo "   ✓ build/CodeQuest-debug.apk ($(du -h build/CodeQuest-debug.apk | cut -f1))"
echo ""
echo "✅ APK 构建成功"

# Step 3: 可选安装
if [ "$1" == "--install" ]; then
	ADB="$ANDROID_HOME/platform-tools/adb"
	echo ""
	echo ">>> Step 3: 安装到模拟器..."
	$ADB wait-for-device
	$ADB install -r build/CodeQuest-debug.apk
	echo ">>> 启动..."
	$ADB shell am start -n top.soycodetrail.codequest/org.godotengine.godot.GodotActivity
	echo "✅ 已启动"
fi
