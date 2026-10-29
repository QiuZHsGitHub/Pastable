# Pastable · Mac App Store 上架清单

> 版本 1.2.0 (build 4) · Bundle ID `com.qzh.Pastable` · Team `754Q6V2X9B`
> 付费上架 · 目标 macOS 15.5+

---

## 一、还缺的材料(需要你准备/确认)

| # | 材料 | 状态 | 说明 |
|---|---|---|---|
| 1 | **Paid Applications 协议** | ❌ 必须先办 | App Store Connect →「协议、税务和银行业务」→ 申请「付费应用」协议,填写税务表(中国个人/公司)和银行账户。**没签完协议无法设置价格、无法提交审核** |
| 2 | **隐私政策 URL** | ❌ 待发布 | 文案见 [privacy-policy.md](privacy-policy.md),建议挂 GitHub Pages(见该文件末尾说明) |
| 3 | **App Store 截图** | ✅ 已生成 2 张 | `docs/appstore/screenshots/01-dark-2880x1800.png`、`02-light-2880x1800.png`(2880×1800,深/浅色面板);`screenshots/raw/` 里还有全屏备选。**请人眼确认效果后上传** |
| 4 | **技术支持 URL** | ❌ 建议填 | 可用 `https://github.com/QiuZHsGitHub/Pastable/issues` |
| 5 | **SKU** | ❌ 随手定 | 自定义即可,如 `PASTABLE-MAC-001` |
| 6 | **审核联系人信息** | ❌ 表单里填 | 姓名/电话/邮箱,审核人员可能来电确认辅助功能用法 |

## 二、App Store Connect 填写文案(直接复制)

### 基本信息
- **名称**:Pastable(≤30 字符,需全局唯一;若重名可改「Pastable 剪贴板」)
- **副标题**(≤30 字符):`轻巧快速的剪贴板管理器`
- **主语言**:简体中文;可加 English、繁体中文本地化(应用本身已带这三套本地化)
- **套件 ID**:com.qzh.Pastable(下拉选择,勿手填)
- **SKU**:PASTABLE-MAC-001

### 定价与销售范围
- 定价:付费,建议 ¥12 / $1.99 档(自定);销售范围默认全球
- 注意:先签完 Paid Applications 协议才有定价选项

### 类别
- 主要:**工具**(Utilities) — 与 Info.plist 中 `public.app-category.utilities` 一致
- 次要:**效率**(Productivity)

### 关键词(≤100 字符,逗号分隔,勿含 App 名称)
```
剪贴板,复制历史,粘贴,效率工具,快捷键,云同步,搜索,片段管理,生产力
```
英文版关键词:
```
clipboard,paste,history,copy,productivity,shortcut,icloud,sync,snippets
```

### 描述
```
Pastable 是一款轻量、快速的 macOS 剪贴板管理器,专注「随叫随到的浮层」与「更聪明的搜索」,让复制内容回找和粘贴更高效。

【浮层随叫随到】
· 全局快捷键(默认 ⌘⇧V)在任意应用上方唤出浮层,自动贴着屏幕底部,即用即走
· 分类筛选与实时搜索,几秒钟找回任何一条复制记录
· 卡片式历史:文本、代码、链接、图片、文件一目了然

【更聪明的搜索】
· 支持按内容、来源应用、分类检索,并高亮命中原因
· 支持正则与常见数据格式识别(代码、JSON、颜色等)

【优雅与克制】
· 中国潮色「朱砂」主题,自动跟随系统浅色/深色模式
· 历史记录仅保存在你的 Mac 上;可选同步到你自己的 iCloud,开发者无法访问
· 无账号、无广告、无追踪、无统计 SDK

【效率细节】
· 自动粘贴:选中记录直接粘贴到当前应用(需在系统设置中授予辅助功能权限)
· 全局快捷键可自定义;开机自启可选
· 历史数量与保留时长可配置,自动清理可预览后再执行

适用 macOS 15.5 及以上。
```

### 更新说明(What's New)
```
1.2.0
· 面板布局与搜索框优化,更紧凑顺手
· 修复浮层定位与跨桌面显示的若干问题
· 主题微调与性能改进
```
(如实际改动不同,以 git log 为准替换)

### 版权
```
Copyright © 2026 Qiu ZH
```

### 审核备注(App Review Notes,重要)
```
Thank you for reviewing Pastable, a local-first macOS clipboard manager.

1. No account or login is required. All history is stored locally (SwiftData);
   optional iCloud sync uses the reviewer-visible private CloudKit database of
   the user's own iCloud account, which we cannot access.
2. "Auto Paste" simulates ⌘V into the frontmost app and therefore needs the
   Accessibility permission. The app guides the user to System Settings →
   Privacy & Security → Accessibility. If it is not granted, the app still
   works normally (copy to clipboard instead). This is not a private API; it
   uses CGEvent + AXIsProcessTrusted, which is standard for MAS clipboard
   managers.
3. No private APIs, no analytics, no third-party SDKs, no adult content.

If you need any help, please contact us at the phone/email below.
```

### App 隐私(隐私营养标签)
- 选「**不收集数据**」(Data Not Collected)
- 理由:无统计/崩溃上报/账号;剪贴板历史存本机;iCloud 同步走用户自己的私有 CloudKit,开发者不可访问,不构成「收集」
- 若想保守申报:可申报「用户内容(剪贴板内容)→ 仅用于 App 功能 → 不与身份关联 → 不追踪」;两种都常见,推荐前者

### 年龄分级
- 问卷全部选「无/否」→ 结果 **4+**

### 出口合规(加密问题)
- 「是否使用加密?」→ 选 **仅使用操作系统内置加密(iCloud/HTTPS),不含自定义加密** → 免于提供加密文档
- (CryptoKit 只用于内容去重哈希,不属于加密功能)

## 三、上传与提交流程

1. **[网页]** App Store Connect →「协议、税务和银行业务」→ 签署 Paid Applications
2. **[网页]** 「我的 App」→ ➕ → 新建 macOS App → 名称/主语言/套件 ID/SKU
3. **[本地]** 归档 + 导出 `.pkg`(由我完成);上传方式二选一:
   - 我用 `xcrun altool --upload-app` 命令行上传(需要你创建 App Store Connect API 密钥)
   - 或 Xcode → Window → Organizer → Distribute App → App Store Connect
4. **[网页]** 在版本页选择 build 4,填写上面的文案、截图、隐私、分级、定价、审核备注
5. **[网页]** 「添加以供审核」→「提交审核」
6. 等待审核(付费应用首次提交常需 1–3 天,可能有电话回访)

## 四、工程侧改动记录(本次为过审做的修改)

| 文件 | 改动 | 原因 |
|---|---|---|
| `Pastable/Pastable.entitlements` | `com.apple.security.app-sandbox` → `true` | Mac App Store 强制 App Sandbox(ITMS-90296) |
| `Pastable.xcodeproj/project.pbxproj` | 新增 `INFOPLIST_KEY_LSApplicationCategoryType = public.app-category.utilities` | MAS 要求应用类别 |
| `Pastable/Core/CloudSyncMonitor.swift` | 重启自身由 `/usr/bin/open` 改为 `NSWorkspace` | 沙盒下不能 spawn 系统二进制 |
| `Pastable/PastableDebug.entitlements` | 保持沙盒关闭 | Debug 构建继续方便本地调试;行为以 Release 为准 |

## 五、上架后记得验证

- [ ] 从 App Store 安装的包:iCloud 同步可用(容器 `iCloud.com.qzh.Pastable`)
- [ ] 自动粘贴:辅助功能授权引导正常弹出
- [ ] 从其他 App 复制的**文件缩略图**在沙盒下能正常生成(macOS 对剪贴板文件 URL 有临时授权,预期可用;若失败会退化为文件图标,不影响过审)
