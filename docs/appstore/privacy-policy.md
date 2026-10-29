# 隐私政策 / Privacy Policy

**Pastable for macOS**

最后更新 / Last updated:2026-10-29

---

## 中文

**Pastable 是一款本地优先的剪贴板管理器。我们不收集、不传输、不出售任何个人信息。**

### 我们收集什么?

**什么都不收集。** Pastable 没有账号系统、没有统计分析、没有崩溃上报、没有广告 SDK、没有任何第三方追踪代码。应用不包含向开发者服务器发起的网络请求。

### 剪贴板历史存在哪里?

- 默认保存在**你的 Mac 本地**(应用沙盒内的数据库)。
- 如果你主动开启「iCloud 同步」,历史记录会通过 **CloudKit 私有数据库**同步到**你自己的 iCloud** 账户。该数据只有你的 Apple ID 可以访问,**开发者无法查看、无法获取**。

### 权限说明

- **辅助功能(Accessibility)**:仅在你使用「自动粘贴」功能时申请,用于向当前应用模拟 ⌘V 粘贴。不授予该权限时,应用的其余功能不受影响。
- **用户选择的文件**:仅当你通过系统文件选择器选择文件时读取。

### 数据删除

所有历史记录可随时在应用内删除或设置自动清理。删除应用即删除本地数据;iCloud 数据由你的 Apple ID 管理。

### 联系我们

如有任何隐私相关问题,请通过 GitHub Issues 联系:<https://github.com/QiuZHsGitHub/Pastable/issues>

---

## English

**Pastable is a local-first clipboard manager. We do not collect, transmit, or sell any personal information.**

### What do we collect?

**Nothing.** Pastable has no accounts, no analytics, no crash reporting, no ad SDKs, and no third-party trackers. The app makes no network requests to developer-operated servers.

### Where is clipboard history stored?

- By default it stays **on your Mac** (inside the app sandbox).
- If you opt into **iCloud Sync**, history is synced through the **CloudKit private database of your own iCloud account**. Only your Apple ID can access it; **the developer cannot view or retrieve it**.

### Permissions

- **Accessibility**: requested only when you use "Auto Paste", used solely to simulate ⌘V into the frontmost app. The app works normally without it.
- **User-selected files**: read only when you pick files through the system file picker.

### Deleting your data

History can be deleted at any time in-app, with optional automatic cleanup. Deleting the app removes local data; iCloud data is managed by your Apple ID.

### Contact

Privacy questions: <https://github.com/QiuZHsGitHub/Pastable/issues>

---

## 如何发布这个页面(给上架用)

App Store Connect 的「隐私政策 URL」需要一个**公网可访问**的链接。最简单的方式是 GitHub Pages:

1. 打开仓库 `QiuZHsGitHub/Pastable` → Settings → Pages
2. Source 选 `Deploy from a branch`,分支 `main`,目录 `/docs`,保存
3. 等 1–2 分钟,访问 `https://qiuzhsgithub.github.io/Pastable/appstore/privacy-policy.html`
   (GitHub Pages 会自动把 Markdown 渲染为页面;若你的 Pages 版本不渲染 .md,把本文件复制为 `docs/appstore/privacy-policy.html`,用纯 HTML 也可以)
4. 把最终可访问的 URL 填进 App Store Connect 的「隐私政策网址」

如果不想用 GitHub Pages,任何能公开访问的托管(个人网站、Notion 公开页、腾讯文档分享链接等)都可以,保证审核期间可打开即可。
