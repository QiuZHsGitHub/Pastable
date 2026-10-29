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

App Store Connect 的「隐私政策 URL」已由 GitHub Pages 站点提供:

- **公网地址**:<https://qiuzhsgithub.github.io/Pastable/privacy.html>
- **英文锚点**:<https://qiuzhsgithub.github.io/Pastable/privacy.html#english>
- **页面源码**:`docs/privacy.html`(中文与 English 同页)
- **开启 Pages 的步骤**:[github-pages.md](github-pages.md)

本 Markdown 保留为文案源。修改隐私政策时,请同步更新 `docs/privacy.html` 的中文与 English 两段,
并更新页面顶部的「最后更新」日期与 `docs/sitemap.xml` 的 `lastmod`。
