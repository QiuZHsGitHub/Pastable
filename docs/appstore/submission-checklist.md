# Pastable · Mac App Store 上架清单

> 版本 1.2.0 (build 4) 已提交审核 · 1.2.1 待提交（评分请求 + 新首图 + 新副标题）
> Bundle ID `com.qzh.Pastable` · Team `754Q6V2X9B` · 付费上架 · 目标 macOS 15.5+

---

## 一、还缺的材料(需要你准备/确认)

| # | 材料 | 状态 | 说明 |
|---|---|---|---|
| 1 | **Paid Applications 协议** | ❌ 必须先办 | App Store Connect →「协议、税务和银行业务」→ 申请「付费应用」协议,填写税务表(中国个人/公司)和银行账户。**没签完协议无法设置价格、无法提交审核** |
| 2 | **隐私政策 URL** | ✅ 已上线 | `https://qiuzhsgithub.github.io/Pastable/privacy.html`(中英同页) |
| 3 | **App Store 截图** | ✅ 新版 2 张已生成 | `docs/appstore/screenshots/01-hero-2880x1800.png`(首图,3 秒讲清底部浮层 + 不打断)、`02-collection-2880x1800.png`(内容分类 + 搜索);旧的 `01-dark`/`02-light` 仅作备份。**首图请先做 3 秒测试再上传** |
| 4 | **技术支持 URL** | ✅ 已上线 | `https://qiuzhsgithub.github.io/Pastable/support.html`(含 FAQ、权限、退款、中英);也可继续用 GitHub Issues |
| 5 | **SKU** | ❌ 随手定 | 自定义即可,如 `PASTABLE-MAC-001` |
| 6 | **审核联系人信息** | ❌ 表单里填 | 姓名/电话/邮箱,审核人员可能来电确认辅助功能用法 |

## 二、App Store Connect 填写文案(直接复制)

### 基本信息
- **名称**:Pastable(≤30 字符,需全局唯一;若重名可改「Pastable 剪贴板」)
- **副标题**(≤30 字符):`呼出即贴，不打断手头工作`
  - 这是 1.2.1 的新文案。1.2.0 已提交的副标题仍是「轻巧快速的剪贴板管理器」,不要在审核中改;审核通过后随 1.2.1 更新
- **主语言**:简体中文;可加 English、繁體中文、日本語、한국어、Français、Deutsch、Español、Português (Brasil)、Italiano、Русский(应用内已带这 11 套本地化,App Store 的商店文案仍需在 ASC 里逐语言填写)
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
剪贴板,粘贴板,复制历史,剪贴板管理,浮层,快捷键,不打断,效率,搜索,片段
```
英文版关键词:
```
clipboard,paste,history,copy,menu bar,shortcut,focus,productivity,snippets
```

### 描述
```
Pastable 是 macOS 的全屏底部剪贴板浮层：呼出即贴，不打断手头工作。

【不抢焦点，才是真的不打断】
· 快捷键（默认 Command-Shift-V）在任意 App 上方唤出全屏宽的底部浮层
· 打开面板时不抢键盘焦点：光标和输入仍留在你正在写的文档里
· 选中卡片或按 Return，内容直接贴回当前 App，面板随即收起
· 切换桌面空间、进入全屏，面板也不会突然消失

【3 秒找回任何一条】
· 精确 / 模糊搜索标题与全文，多关键词同时匹配
· 文本、代码、链接、图片、文件自动分类，命中原因高亮
· 卡片直接预览；图片预生成缩略图，滚动不卡

【有分寸的存储】
· 历史仅保存在本机；可选同步到你自己 iCloud 的私有 CloudKit
· 保留时长与容量上限可设；首次超限先问「清理 / 全部保留 / 稍后」
· 无账号、无广告、无追踪、无统计 SDK

【效率细节】
· 自动粘贴（需辅助功能权限；未授权时退回仅复制）
· Command-1…9 / Fn-1…9 数字快贴；全局快捷键可自定义
· 中国潮色「朱砂」主题，自动跟随系统浅色 / 深色
· 开机自启可选

适用 macOS 15.5 及以上。
```

### 推广文本(≤170 字符)
```
全屏底部浮层，快捷键随时呼出。打开时不抢键盘焦点，输入继续留给手头的文档；选中卡片立即贴回，工作流不断。
```
> ASC 的推广文本对 `⌘⇧` 等特殊符号会报「无效字符」,这里已改成纯文字;可随时修改,不需要新版本。

### 更新说明(What's New)

1.2.0(已提交):
```
1.2.0
· 面板布局与搜索框优化，更紧凑顺手
· 修复浮层定位与跨桌面显示的若干问题
· 主题微调与性能改进
```

1.2.1(待提交):
```
1.2.1
· 新增「在 Mac App Store 评分」入口
· 细节优化与稳定性改进
```

### 截图:第一张的 3 秒法则

- 首图:`docs/appstore/screenshots/01-hero-2880x1800.png`
  - 左侧大字:「呼出即贴，不打断手头工作。」+「全屏宽的底部浮层 / 打开时不抢键盘焦点」
  - 右侧:真实工作文档、正在闪的光标,以及标注「键盘焦点还在这里」
  - 底部:实际面板(不是只截面板)
- 第二张:`docs/appstore/screenshots/02-collection-2880x1800.png`,讲 5 类内容 + 搜索
- **3 秒测试**:给一个没看过的人看 3 秒,让他复述。能说出「底部浮层 + 不打断 / 不抢焦点」才算过;只说「这是个剪贴板截图」就重做。
- 尺寸:2880×1800(16:10),RGB 无透明通道;已按 ASC macOS 截图规格导出。
- 旧图 `01-dark-2880x1800.png` / `02-light-2880x1800.png` 仅作备份,不再作为首图。

### 截图上传顺序

1. `01-hero-2880x1800.png`
2. `02-collection-2880x1800.png`

(评分积累到 20–50 个、有真实好评后,再加「评分/媒体评价」截图;现在不要伪造。)

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

## 六、评分策略(1.2.1)

> 付费 App 的搜索排序和转化率高度依赖评分数量。目标:**首月 20–50 个真实评分**,把 4.5+ 的评分基础打起来,再考虑加大投放。

### 代码实现(已完成,单测覆盖)

- 启动时**绝不**请求评分。
- 只有 `Clipboard.paste` 真正 post 了 Cmd+V 才计数;只复制、没粘贴不算。
- 第 1 次成功粘贴后标记;下一次打开面板时,由 StoreKit 系统弹窗请求。**不在粘贴瞬间弹**,避免把焦点从用户文档里抢走。
- 第 20 / 80 次成功粘贴,且距上次请求 ≥90 天,才进入下一轮;一年最多 3 次,符合 Apple 的 `AppStore.requestReview` 限制。
- 设置 → 关于 → **在 Mac App Store 评分**:常驻入口,直接打开写评价页,给主动想评价的用户一条路。
- 实现:`Pastable/Core/ReviewPrompt.swift`;决策单测:`Tests/PastableTests/ReviewPromptTests.swift`。

### 运营节奏

1. 1.2.0 审核通过后,先让 10–20 位真实用户用一周,不群发、不催评。
2. 1.2.1 发布后观察 2 周:评分入口点击、系统弹窗出现率、低分内容。
3. 首月目标 20–50 个评分;到 20 个后再评估关键词和投放。
4. 只在支持页/感谢邮件放写评价链接;**不诱导、不奖励、不刷评**。
5. 每周看 ASC「评分与评论」;有低分先回复、再改产品,不删评。

### 反例(不要做)

- ❌ 一启动就弹评分 → 大概率 1 星。
- ❌ 第一次打开 App 就弹 → 用户还没成功粘贴过。
- ❌ 每次启动都弹 → StoreKit 会抑制,用户也烦。
- ❌ 用「好评解锁功能」换评分 → 违反 App Store 规则。

## 七、官网与 README 的转化路径

### 官网首屏(已改)

`docs/index.html` / `docs/en/index.html` 首屏现在同时具备:

1. **一句话卖点**:「呼出即贴，不打断手头工作。」/「Paste without breaking your flow.」
2. **一键跳转 App Store**:首屏 App Store 官方徽章 + 顶部导航徽章 + 底部 CTA。
3. **15 秒 GIF 演示**:`docs/assets/site/demo-zh.gif` / `demo-en.gif`,展示呼出 → 选中 → 回贴,键盘焦点不离开文档。
4. 辅助说明:首屏 lede、功能区和截图都明确写「不抢键盘焦点」。

### README(已改)

`README.md` / `README.en.md`:

- 顶部第一屏就是 **App Store 徽章**(深色模式自动换白色徽章)+ 15 秒 GIF。
- 新增「下载」区,明确两条路径:
  - **普通用户 → Mac App Store(推荐)**:付费、完整版、自动更新、iCloud 同步。
  - **开发者 → GitHub 源码 / Release**:免费、ad-hoc 未公证、不含 iCloud;适合审计/自行编译,不是 App Store 的免费替代。
- 顶部不再放 GitHub Release 徽章/链接,避免把付费用户拦截到需要自己编译的页面。
- 旧 README 的 Figma/主题细节移到后部,不再挡在下载路径前面。

### 验收

- [ ] 手机上打开 `https://qiuzhsgithub.github.io/Pastable/`,首屏能看到卖点、App Store 按钮、GIF(或静态 poster)。
- [ ] README 在 GitHub 深色/浅色模式下,徽章都可见。
- [ ] 从 README 顶部徽章能一步跳到 App Store;从「开发者」区能一步跳到源码/Release。
- [ ] GIF ≤ 2 MB,首屏不阻塞文字与按钮渲染。

## 八、App Store Connect 当前进度(2026-10-30 更新)

> 网页操作由 agent 通过独立配置 Chrome 完成,工具与用法见 [tools/asc-browser/README.md](../../tools/asc-browser/README.md)。

### 已完成

- **App 记录已建**:Pastable · macOS · `com.qzh.Pastable` · SKU `PASTABLE-MAC-001` · ASC App ID `6828470287`
- **版本页 1.2.0**:描述、关键词、技术支持 URL、版权、审核备注、2 张旧截图(2880×1800 深/浅)已填;「需要登录」已取消;「自动发布」保留
  - 以上是 1.2.0 提交时的状态。**新副标题、新描述、新首图不要直接改 1.2.0**;审核通过后随 1.2.1 提交。
  - 技术支持 URL 可替换为站点版:`https://qiuzhsgithub.github.io/Pastable/support.html`
- **App 信息**:副标题「轻巧快速的剪贴板管理器」(1.2.0 旧文案)、类别 工具/效率、内容版权「不包含第三方内容」
- **年龄分级**:4+(172 个国家或地区)
- **App 隐私**:「未收集数据」已发布
- **审核联系人**:已在 App Store Connect 填写(不写入仓库)
- **DSA 交易商信息**:已提交并通过,27 个国家或地区,状态「有效」
- **付费 App 协议**:已签署(生效 2026-10-29),状态「正在处理」
- **银行账户**:已添加,状态「正在处理」(约 24 小时)
- **报税表**:U.S. W-8BEN 与 U.S. Certificate of Foreign Status 均于 2026-10-29 提交,状态「使用中」
- **相关合规信息**:已提交,状态「有效」
- **定价**:美国 $1.99 / 中国大陆 ¥12.00(已保存;等协议生效后对用户生效)
- **隐私政策 URL**:`https://qiuzhsgithub.github.io/Pastable/privacy.html` 已填入「App 隐私」
- **技术支持 / 营销网址**:已更新为站点版(`support.html` / 站点首页)
- **推广文本**:已填(去掉 `⌘⇧` 等特殊符号,ASC 会报「无效字符」)
- **构建**:1.2.0 (4) 已上传(2026-10-29 23:41,含 App 图标)
- **提交审核**:2026-10-29 23:51 已提交,状态「正在等待审核」(审核最多 48 小时,结果邮件通知)

### 1.2.1 已准备(代码/素材完成,待构建上传)

- **评分请求**:`Pastable/Core/ReviewPrompt.swift`;首次成功粘贴后标记,下一次打开面板时请求;20/80 次、90 天间隔;设置 → 关于新增评分入口;6 个决策单测通过。
- **新副标题**:`呼出即贴，不打断手头工作`(≤30 字符)。
- **新描述 / 推广文本 / 关键词**:见本文第二节,直接复制。
- **新截图**:`01-hero-2880x1800.png`、`02-collection-2880x1800.png`;首图已按 3 秒法则重做。
- **官网**:首屏卖点 + App Store 按钮 + 15 秒 GIF(中英),`docs/index.html`、`docs/en/index.html`。
- **README**:顶部 App Store 徽章 + 15 秒 GIF + 双渠道定位,`README.md`、`README.en.md`。
- **演示素材**:`docs/assets/site/demo-{zh,en}.gif`(各约 1.7–1.8 MB)、`demo-{zh,en}-poster.webp`。
- **工程版本**:当前 `MARKETING_VERSION = 1.2.0` / build 5;提交 1.2.1 前改为 `1.2.1` / build 6,再 Archive 上传。

### 待办(按依赖顺序)

1. **[等]** 银行账户与付费协议处理完成(约 24 小时)后,协议转「有效」,定价正式生效
2. **[等]** Apple 审核结果(通常 1–3 天;付费应用首审可能有电话回访,备注里已写明协助方式)
3. **[我]** 若审核被拒:按拒审理由改元数据/构建后重新提交
4. **[等]** 1.2.0 审核通过后:确认 App Store 页面(图标、价格、隐私标签)显示正常
5. **[我]** 创建 1.2.1 版本 → 改 bundle 版本为 1.2.1 (6) → Archive/上传 → 填新副标题/描述/推广文本/关键词 → 上传 2 张新截图 → 提交
6. **[等]** 1.2.1 上线后:按「评分策略」观察首月 20–50 个评分,目标 4.5+;再评估投放


## 九、GitHub Pages 站点(2026-10-29 新增)

官网与上架所需的隐私/支持页面已经生成在 `docs/`,纯静态、无统计、无第三方请求:

| 用途 | URL |
|---|---|
| 官网(中文) | <https://qiuzhsgithub.github.io/Pastable/> |
| 官网(English) | <https://qiuzhsgithub.github.io/Pastable/en/> |
| 隐私政策 | <https://qiuzhsgithub.github.io/Pastable/privacy.html> |
| 技术支持 | <https://qiuzhsgithub.github.io/Pastable/support.html> |

**已上线**:仓库 Settings → Pages 当前为「Deploy from a branch」→ `main` / `/docs`。
完整说明、日常更新对照表与检查清单见 [github-pages.md](github-pages.md)。
