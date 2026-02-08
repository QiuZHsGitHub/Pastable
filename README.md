# Pastable

Pastable 是一个轻量、快速的 macOS 剪贴板管理器，聚焦“随叫随到的面板”和“更聪明的搜索”，帮助你快速回找、筛选、粘贴最近复制的内容。

## 特性

- 悬浮面板：全屏底部浮层展示最近内容，随时呼出
- 快速搜索：支持模糊/精确匹配
- 类型识别：文本、链接、代码、图片、文件自动分类
- 一键粘贴：选中卡片即粘贴到当前应用
- 历史管理：自定义保留条数与保留时长
- 细节设置：开机自启、自动粘贴、去除格式、声音提示
- 快捷键：自定义呼出面板快捷键

## 安装与运行

1. 使用 Xcode 打开 `/Users/qzh/Documents/Projects/Pastable/Pastable.xcodeproj`
2. 按 `/Users/qzh/Documents/Projects/Pastable/DEPENDENCIES.md` 添加 Swift Package 依赖
3. 选择 macOS 目标并运行

## 使用方式

- 呼出面板：使用设置中的快捷键（默认在“快捷键”里配置）
- 搜索：点击搜索框或使用 `Cmd+Shift+F`
- 粘贴：选中卡片后自动粘贴（可在设置中关闭“自动粘贴”）

## 设置项

- 搜索模式：精确 / 模糊
- 自动粘贴
- 去除格式
- 声音提示
- 保存类型：文本 / 图片 / 文件
- 历史上限与保留时间

## 技术栈

- SwiftUI + AppKit
- SwiftData
- 辅助依赖：KeyboardShortcuts、LaunchAtLogin、Sparkle 等

## 参考与致敬

以下优秀项目在体验和方向上提供了启发：

- Raycast
- Alfred
- Pastebot
- Maccy
- Clipy

## 许可证

MIT
