# Godot 4.6 Android 导出踩坑实录与发布流程规范

> 环境：Godot 4.6.1 stable / macOS 26.5.1 / JDK Temurin 17.0.13 / Android SDK 36 + NDK 28.2
> 日期：2026-07-28
> 关联项目：Code Quest v1.0.0
> 关联长文：[[Code Quest v1.0.0 全程开发实录——Godot 4.6 Python 编程闯关游戏]]

## TL;DR

Godot 4.6 在 macOS headless 模式 export Android 报 "Cannot export project with preset Android due to configuration errors:" **错误描述为空**——这是 Godot 真实 bug（[issue #119895](https://github.com/godotengine/godot/issues/119895)），根因是 **ETC2/ASTC 纹理压缩没启用**。修一行配置即可。

## 完整环境依赖清单

发布 Godot Android APK 需要的全部依赖（一次性配置）：

| 组件 | 版本 | 安装路径 |
|---|---|---|
| Godot | **4.6.x**（不能用 4.7，GdUnit4 不兼容） | `~/tools/Godot.app` + 软链 `~/tools/godot461` |
| JDK | Temurin **17.x**（不能 21，Godot 4 要 17） | `~/tools/jdk17/Contents/Home` |
| Android SDK | API 30/34/35/36 | `~/Library/Android/sdk` |
| Android NDK | 28.x | `~/Library/Android/sdk/ndk` |
| Build Tools | 35.0.1 或更高 | `~/Library/Android/sdk/build-tools` |
| Godot Android Templates | 与 Godot 版本完全一致 | `~/Library/Application Support/Godot/export_templates/<版本>.stable/` |
| AVD（可选） | arm64-v8a | `pixel_dev` / `aosp_pixel` |

### JDK 安装（绕开 sudo）

brew cask 装 JDK 需要 sudo 密码，沙盒环境给不了。改用 tar 包：

```bash
mkdir -p ~/tools/jdk17
curl -sL -o /tmp/jdk17.tar.gz "https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.13%2B11/OpenJDK17U-jdk_aarch64_mac_hotspot_17.0.13_11.tar.gz"
tar xzf /tmp/jdk17.tar.gz -C ~/tools/jdk17 --strip-components=1
```

### Godot 多版本共存

brew 装的是 4.7.1，但 GdUnit4 要 4.6.x。手动下载 4.6.1 共存：

```bash
curl -L -o /tmp/godot-4.6.1.zip "https://github.com/godotengine/godot/releases/download/4.6.1-stable/Godot_v4.6.1-stable_macos.universal.zip"
unzip /tmp/godot-4.6.1.zip -d ~/tools
ln -sf ~/tools/Godot.app/Contents/MacOS/Godot ~/tools/godot461
chmod +x ~/tools/godot461
```

### Godot Android Templates 安装

```bash
# 下载与 Godot 版本完全一致的 templates（4.6.1 对应 4.6.1.stable 目录）
curl -sL -o /tmp/templates.tpz "https://github.com/godotengine/godot/releases/download/4.6.1-stable/Godot_v4.6.1-stable_export_templates.tpz"
mkdir -p ~/Library/Application\ Support/Godot/export_templates/4.6.1.stable
unzip -j /tmp/templates.tpz "templates/android_*" -d ~/Library/Application\ Support/Godot/export_templates/4.6.1.stable/
```

⚠️ **关键**：版本目录名必须**完全等于 Godot 版本字符串**（`4.6.1.stable`，不是 `4.6.stable`），否则 Godot 找不到。

### Godot editor settings 配 SDK 路径

`~/Library/Application Support/Godot/editor_settings-4.6.tres`：

```ini
export/android/java_sdk_path = "/Users/<你>/tools/jdk17/Contents/Home"
export/android/android_sdk_path = "/Users/<你>/Library/Android/sdk"
```

## 踩坑与修复（按顺序）

### 坑 1：Godot 4.7 + GdUnit4 v6.1.3 不兼容

报 `Class "GdUnitAssertImpl" hides a global script class`。GdUnit4 最高兼容 4.6.x。**降级到 Godot 4.6.1**。

### 坑 2：GdUnit4 headless 模式默认拒绝

报 `Headless mode is not supported! Abnormal exit with 103`。加 `--ignoreHeadlessMode` 参数。

### 坑 3：min_sdk 低于 24

报 `最小 SDK 不能低于 24，这是 Godot 库所需要的版本`。`export_presets.cfg` 改 `gradle_build/min_sdk=24`。

### 坑 4：Gradle build Template 版本不匹配

报 `尝试从自定义构建模板构建，但是它所使用的版本信息不存在。请从"项目"菜单中重新安装`。

**修复**：删 `android/build/`，关闭 gradle build（用 Godot 内置 APK 模板）：
```ini
# export_presets.cfg
gradle_build/use_gradle_build=false
```
注意：关 gradle 后 `min_sdk` / `target_sdk` 字段不能用（会报"只有启用 Gradle 构建时才能覆盖"），删掉这两行。

### 坑 5：export 路径目录不存在

报 `目标文件夹不存在或无法访问："build"`。Godot 不会自动创建输出目录，**必须提前 `mkdir -p build/`**。

### 坑 6（最难）：Android export 报"配置错误"且描述为空

报：
```
ERROR: Cannot export project with preset "Android" due to configuration errors:
                                                                              ← 空
```

**根因**：[GitHub issue #119895](https://github.com/godotengine/godot/issues/119895)。Godot 4.6 在 `platform/android/export/export_plugin.cpp` 的 `should_import_etc2_astc()` 里把 `valid` 改 false 但**没 log 错误信息**。实际原因是项目默认纹理压缩 S3TC_BPTC，但 **Android preset 要求 ETC2/ASTC**。

**修复**（一行配置）：

`project.godot` 加：
```ini
[rendering]
renderer/rendering_method="mobile"
textures/vram_compression/import_etc2_astc=true
```

加完后 Godot 才能给出真正的错误（坑 5 等），逐个解决就 build 出完整 APK。

**经验**：Godot 错误描述为空 ≠ 没错误。Google 搜英文错误原文 + 看 GitHub issue。

### 坑 7：APK 装到模拟器后启动 Activity 名找不到

报 `Activity class {pkg/org.godotengine.godot.GodotActivity} does not exist`。

**根因**：non-gradle 模式下 LAUNCHER activity 名是 `com.godot.game.GodotAppLauncher`（不是 `org.godotengine.godot.GodotActivity`）。

**正确启动命令**：
```bash
adb shell am start -n top.soycodetrail.codequest/com.godot.game.GodotAppLauncher
```

查实际 activity 名：
```bash
adb shell dumpsys package top.soycodetrail.codequest | grep -A 2 "android.intent.action.MAIN"
# 或
aapt dump xmltree app.apk AndroidManifest.xml | grep -E "activity|name="
```

### 坑 8：GitHub Release 上传 58MB APK 卡死

详见 [[#发布流程规范]]。

## 完整 export 命令

修完所有坑后，一行命令出 APK：

```bash
mkdir -p build
export JAVA_HOME=~/tools/jdk17/Contents/Home
export PATH=$JAVA_HOME/bin:$PATH
export ANDROID_HOME=~/Library/Android/sdk

~/tools/godot461 --headless --export-debug "Android" build/CodeQuest-debug.apk
```

成功标志：
```
[ 97% ] export | 正在对齐 APK……
[ 98% ] export | 正在签名调试 APK……
Signed
[ 99% ] export | 正在校验 APK……
[ DONE ] export
```

## 模拟器验证链路

```bash
# 启动模拟器
emulator -avd pixel_dev -no-snapshot -no-audio -no-boot-anim &

# 等就绪
adb wait-for-device

# 装
adb install -r build/CodeQuest-debug.apk

# 启动（注意 activity 名）
adb shell am start -n top.soycodetrail.codequest/com.godot.game.GodotAppLauncher

# 看是否真起来了
adb shell dumpsys window | grep mCurrentFocus
# 应看到：mCurrentFocus=Window{xxx u0 top.soycodetrail.codequest/...}

# 看 Godot 启动日志
adb logcat -d | grep -iE "godot |codequest"
# 应看到：I godot : Godot Engine v4.6.1.stable...
#         I godot : Vulkan 1.3.0 - Forward Mobile - Using Device #0...

# 截图
adb exec-out screencap -p > screenshot.png
```

## 发布流程规范（避免再卡死）

### 规则 1：大文件上传必须带超时 + 重试

```bash
upload_with_retry() {
    local file=$1 max_attempts=3
    for i in $(seq 1 $max_attempts); do
        if timeout 180 gh release upload v1.0.0 "$file" --clobber; then
            return 0
        fi
        echo "attempt $i failed, retrying..."
        sleep 5
    done
    return 1
}
```

### 规则 2：release 流程拆成幂等步骤

不要用一条 `gh release create` 同时做"建 tag + 建 release + 上传 asset"。拆开：

```bash
# 1. 确保 tag 存在（幂等）
git tag v1.0.0
git push origin v1.0.0

# 2. 确保 release 存在（幂等，存在就 edit）
gh release create v1.0.0 --notes-file NOTES.md || \
    gh release edit v1.0.0 --notes-file NOTES.md

# 3. 单独上传 asset（可重试）
gh release upload v1.0.0 file.apk --clobber
```

### 规则 3：上传期间不要动文件

```bash
# 先 cp 到独立稳定路径
mkdir -p /tmp/release
cp build/CodeQuest-debug.apk /tmp/release/CodeQuest-v1.0.0-android.apk

# 上传期间不再碰 /tmp/release/
gh release upload v1.0.0 /tmp/release/CodeQuest-v1.0.0-android.apk --clobber

# 上传成功后再清理
rm -rf /tmp/release/
```

### 规则 4：国内 >20MB 文件优先走 COS

GitHub release 上传域名 `uploads.github.com` 国内访问质量差，58MB 文件常卡 5-10 分钟。

替代方案：
- **首选**：腾讯云 COS / 阿里云 OSS 上传 + 直链，release notes 里贴外链
- **次选**：分卷上传到 release（split 成多个小文件）
- **兜底**：写好 release notes，APK 让用户自己 build（提供 `build_apk.sh`）

考虑到 hk-server (43.128.23.122) 有腾讯云 COS 接入能力，APK 放 COS 比 GitHub release 快 10 倍以上。

### 规则 5：监控上传进度

```bash
gh release upload ... &
PID=$!
for i in $(seq 1 30); do
    sleep 10
    if ! kill -0 $PID 2>/dev/null; then break; fi
    if gh release view v1.0.0 --json assets | grep -q '"state":"uploaded"'; then
        kill $PID; break
    fi
done
```

## 一键构建脚本

项目根目录 `build_apk.sh`：

```bash
#!/bin/bash
set -e
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

GODOT="${GODOT:-$HOME/tools/godot461}"
export JAVA_HOME="${JAVA_HOME:-$HOME/tools/jdk17/Contents/Home}"
export PATH="$JAVA_HOME/bin:$PATH"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"

mkdir -p build  # 关键：Godot 不会自动建
$GODOT --headless --export-debug "Android" build/CodeQuest-debug.apk

if [ "$1" == "--install" ]; then
    adb install -r build/CodeQuest-debug.apk
    adb shell am start -n top.soycodetrail.codequest/com.godot.game.GodotAppLauncher
fi
```

## 排查清单（按顺序）

export 失败时，逐项排查：

- [ ] Godot 版本与 export_templates 目录名**完全一致**（`4.6.1.stable`）
- [ ] JDK 路径在 `editor_settings-4.6.tres` 配置正确
- [ ] Android SDK 路径配置正确，含 platform-tools / build-tools / NDK
- [ ] `project.godot` 有 `[rendering] textures/vram_compression/import_etc2_astc=true`
- [ ] 输出目录 `build/` 已 `mkdir -p` 创建
- [ ] 如果关了 gradle build，`export_presets.cfg` 不要写 `min_sdk` / `target_sdk`
- [ ] 如果开了 gradle build，`android/build/` 是从同版本 `android_source.zip` 解压的
- [ ] APK 装上后启动用 `com.godot.game.GodotAppLauncher`（不是 `org.godotengine.godot.GodotActivity`）

## 参考

- Godot Android 导出文档：https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html
- ETC2/ASTC 空错误 issue：https://github.com/godotengine/godot/issues/119895
- GdUnit4：https://github.com/godot-gdunit-labs/gdUnit4
- 关联长文：[[Code Quest v1.0.0 全程开发实录——Godot 4.6 Python 编程闯关游戏]]
