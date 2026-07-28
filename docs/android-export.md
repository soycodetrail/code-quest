# Android 导出指南

Code Quest 的 Android APK 导出流程。

## 环境依赖（已安装到本机）

| 组件 | 版本 | 路径 |
|---|---|---|
| Godot | 4.6.1 stable | `~/tools/Godot.app` (软链 `~/tools/godot461`) |
| JDK | Temurin 17.0.13 | `~/tools/jdk17/Contents/Home` |
| Android SDK | API 30/34/35/36 | `~/Library/Android/sdk` |
| Android NDK | 28.2 / 30.0 | `~/Library/Android/sdk/ndk` |
| Build Tools | 36.0.0 / 36.1.0 / 37.0.0 | `~/Library/Android/sdk/build-tools` |
| Android Emulator | AVD: `pixel_dev`、`aosp_pixel` | `~/Library/Android/sdk/emulator` |
| Godot Android Templates | 4.6.1 | `~/Library/Application Support/Godot/export_templates/4.6.1.stable/` |
| Gradle Build Template | 项目内 | `android/build/` |

## 已配置

- `project.godot`: features=4.6
- `export_presets.cfg`: Android preset，package=`top.soycodetrail.codequest`，min_sdk=24，target_sdk=34，gradle build=true
- Godot editor settings: `export/android/java_sdk_path` / `android_sdk_path`
- `android/build/local.properties`: sdk.dir

## 导出 APK

### 方法 1（推荐）：Godot 编辑器 GUI

```bash
~/tools/godot461 -p
# 编辑器内：项目 → 导出 → 选 Android → 导出项目
```

### 方法 2：CLI（注意 macOS headless 4.6.1 已知问题）

```bash
export JAVA_HOME=~/tools/jdk17/Contents/Home
export PATH=$JAVA_HOME/bin:$PATH
export ANDROID_HOME=~/Library/Android/sdk
~/tools/godot461 --headless --export-debug "Android" build/CodeQuest-debug.apk
```

> macOS 11+ 沙盒下，Godot 4.6.1 headless 模式 Android export 会报
> "Cannot export project with preset Android due to configuration errors:"
> 且错误描述为空（dialog 文本未传到 stdout）。
> 这是已知 Godot bug，GUI 模式可正常 export。

### 方法 3：仅导出 pck（验证项目可导出）

```bash
~/tools/godot461 --headless --export-pack "Android" build/test.pck
# 成功生成 2.2MB 的 test.pck 说明项目本身无问题
```

## 安装到模拟器

```bash
# 启动模拟器
~/Library/Android/sdk/emulator/emulator -avd pixel_dev -no-snapshot -no-audio -no-boot-anim &

# 等待启动
~/Library/Android/sdk/platform-tools/adb wait-for-device

# 安装 APK
~/Library/Android/sdk/platform-tools/adb install -r build/CodeQuest-debug.apk

# 启动
~/Library/Android/sdk/platform-tools/adb shell am start -n top.soycodetrail.codequest/org.godotengine.godot.GodotActivity
```

## 签名

debug APK 自动用 `~/.android/debug.keystore` 签名。
release 需要：

```bash
keytool -genkey -v -keystore release.keystore -alias codequest -keyalg RSA -keysize 2048 -validity 10000
# 然后在 export_presets.cfg 填 keystore/release 路径
```

## 移动端验证要点

Code Quest 跑在 Android 时：
- Python backend 自动选 **MiniPython**（系统 python3 在 Android 不存在）
- 字体走 Godot 默认（系统 Noto Sans CJK）
- 音效通过 AudioStreamGenerator 实时合成，无外部资源
- 触摸操作由 Control 节点的 `gui_input` 自动处理（mouse_button == touch）
