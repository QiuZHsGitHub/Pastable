# Swift Package Manager 依赖安装指南

## 在 Xcode 中添加依赖

1. 打开 `Pastable.xcodeproj`
2. 选择项目（Project Navigator 顶部的蓝色图标）
3. 选择 **Package Dependencies** 标签页
4. 点击 **+** 按钮添加依赖

## 需要添加的依赖

| 包名 | URL | 版本 |
|------|-----|------|
| Defaults | `https://github.com/sindresorhus/Defaults.git` | 8.2.0 |
| Fuse | `https://github.com/krisk/fuse-swift.git` | 1.4.0 |
| KeyboardShortcuts | `https://github.com/sindresorhus/KeyboardShortcuts.git` | 2.0.2 |
| LaunchAtLogin | `https://github.com/sindresorhus/LaunchAtLogin.git` | 1.1.0 |
| Sauce | `https://github.com/Clipy/Sauce.git` | 2.4.1 |
| Settings | `https://github.com/sindresorhus/Settings.git` | 3.1.1 |
| Sparkle | `https://github.com/sparkle-project/Sparkle.git` | 2.6.4 |
| swift-log | `https://github.com/apple/swift-log.git` | 1.6.4 |
| SwiftHEXColors | `https://github.com/thii/SwiftHEXColors.git` | 1.4.1 |

## 添加步骤

对于每个依赖：
1. 点击 **+** 按钮
2. 在搜索框中粘贴 URL
3. 选择 **Exact Version** 并输入版本号
4. 点击 **Add Package**
5. 勾选需要添加到 Target 的产品
