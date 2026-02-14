<div align="center">
  <img src="./Pastable/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png" alt="Pastable Logo" width="96" />
  <h1>Pastable</h1>
  <p><strong>轻量、快速的 macOS 剪贴板管理器</strong></p>
  <p>专注「随叫随到的浮层」与「更聪明的搜索」，让复制内容回找和粘贴更高效。</p>
  <p>
    <a href="./README.md">简体中文</a> ·
    <a href="./README.en.md">English</a>
  </p>
  <p>
    <img alt="Platform" src="https://img.shields.io/badge/Platform-macOS-111111?logo=apple" />
    <img alt="Swift" src="https://img.shields.io/badge/Swift-SwiftUI%20%2B%20AppKit-F05138?logo=swift" />
    <img alt="Data" src="https://img.shields.io/badge/Data-SwiftData-0A84FF" />
    <a href="https://github.com/QiuZHsGitHub/Pastable/releases/latest"><img alt="Release" src="https://img.shields.io/github/v/release/QiuZHsGitHub/Pastable?display_name=tag" /></a>
    <img alt="License" src="https://img.shields.io/github/license/QiuZHsGitHub/Pastable" />
  </p>
</div>

<p align="center">
  <img src="./docs/assets/pastable-preview.png" alt="Pastable Preview" width="100%" />
</p>

## 目录

- [功能亮点](#功能亮点)
- [快速开始](#快速开始)
- [下载安装](#下载安装)
- [使用方式](#使用方式)
- [设置项](#设置项)
- [项目结构](#项目结构)
- [灵感来源](#灵感来源)
- [许可证](#许可证)

## 功能亮点

- **全屏底部浮层**：一键呼出最近复制历史，不打断当前工作流
- **搜索体验优化**：支持精确匹配和模糊匹配，快速定位目标内容
- **内容类型识别**：自动识别文本、代码、链接、图片、文件
- **一键回贴**：选中卡片即可写回剪贴板并自动执行粘贴
- **历史管理**：支持保留时长、容量限制与手动清空
- **快捷键体系**：支持自定义全局唤起快捷键

## 快速开始

### 1) 克隆项目

```bash
git clone https://github.com/QiuZHsGitHub/Pastable.git
cd Pastable
```

### 2) 安装依赖

按 `./DEPENDENCIES.md` 在 Xcode 中添加 Swift Package 依赖。

### 3) 运行项目

1. 打开 `./Pastable.xcodeproj`
2. 选择 `Pastable` scheme
3. 选择 macOS 目标后运行

## 下载安装

- 最新版本：<https://github.com/QiuZHsGitHub/Pastable/releases/latest>
- 进入 Release 页面后下载 `.dmg` 安装包即可

## 使用方式

- **呼出面板**：使用你在设置中配置的快捷键（默认 `Cmd + Shift + V`）
- **聚焦搜索**：`Cmd + Shift + F`
- **快速粘贴**：点击卡片即可粘贴到当前应用
- **删除卡片**：悬停目标卡片后按 `Cmd + Delete`

## 设置项

- 搜索模式：精确 / 模糊
- 自动粘贴
- 去除格式
- 音效反馈
- 保存类型：文本 / 图片 / 文件
- 历史上限与保留时间

## 项目结构

```text
Pastable/
├── Core/          # 应用生命周期、剪贴板监听、搜索、主题
├── Models/        # 历史数据模型与内容解析
├── Persistence/   # SwiftData 持久化与去重逻辑
├── UI/            # 浮层、卡片列表、设置页
└── Extensions/    # 通用扩展与 Pasteboard 类型定义
```

## 灵感来源

- Raycast
- Alfred
- Pastebot
- Maccy
- Clipy

## 许可证

本项目基于 [MIT License](./LICENSE) 开源。
