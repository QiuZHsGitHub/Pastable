# Pastable · GitHub Pages 发布说明

站点是纯静态 HTML/CSS/JS，位于仓库的 `docs/` 目录，无构建步骤、无第三方脚本、无统计代码。
GitHub Pages 选「Deploy from a branch → main → `/docs`」即可发布。

## 一、发布后的地址

| 用途 | URL |
|---|---|
| 官网首页（中文） | <https://qiuzhsgithub.github.io/Pastable/> |
| 官网首页（English） | <https://qiuzhsgithub.github.io/Pastable/en/> |
| **隐私政策** | <https://qiuzhsgithub.github.io/Pastable/privacy.html> |
| **技术支持** | <https://qiuzhsgithub.github.io/Pastable/support.html> |
| 英文隐私政策锚点 | <https://qiuzhsgithub.github.io/Pastable/privacy.html#english> |
| 英文支持锚点 | <https://qiuzhsgithub.github.io/Pastable/support.html#english> |
| 404 | <https://qiuzhsgithub.github.io/Pastable/404.html> |

> 这些 URL 由「用户名 `qiuzhsgithub` + 仓库名 `Pastable`」决定。如果以后改仓库名或绑自定义域名，
> 需要同步修改各页 `<link rel="canonical">`、`og:url`、`sitemap.xml`、`robots.txt` 与 `404.html` 里的绝对路径。

> 旧文档里写的 `/appstore/privacy-policy.html` 已保留跳转页，会跳到 `/privacy.html`。
> 如果 App Store Connect 已经填了旧地址，可以先继续用；建议最终改成上面的新地址。

## 二、首次开启（只需一次）

1. 打开仓库 **Settings → Pages**。
2. **Build and deployment → Source** 选 **Deploy from a branch**。
3. **Branch** 选 `main`，**Folder** 选 `/docs`，点 **Save**。
4. 等 1–2 分钟，访问上面的首页地址。首次部署完成前可能显示 404。
5. 打开 `privacy.html`、`support.html`、`en/`、`404.html` 各确认一遍。

不要选 `GitHub Actions` 作为 Source，本仓库没有配置 Pages 工作流；选错会导致 404。

## 三、App Store Connect 对应字段

| 字段 | 建议值 |
|---|---|
| 隐私政策网址 | `https://qiuzhsgithub.github.io/Pastable/privacy.html` |
| 技术支持网址 | `https://qiuzhsgithub.github.io/Pastable/support.html` |
| 营销网址（可选） | `https://qiuzhsgithub.github.io/Pastable/` |
| 英文支持网址（如可本地化） | `https://qiuzhsgithub.github.io/Pastable/support.html#english` |

页面内已经包含：产品介绍、功能、快捷键、定价、隐私政策全文（中英）、技术支持与 FAQ（中英）、
退款说明、App Store 官方徽章、版权与 Apple 商标声明。

## 四、本地预览

```bash
# 在仓库根目录
python3 -m http.server 8000 --directory docs
# 打开 http://localhost:8000/
```

必须用 HTTP 服务预览（`file://` 下相对路径与 `en/` 目录会不正常）。

## 五、日常修改对照表

| 要改的内容 | 位置 |
|---|---|
| 版本号 `1.2.0` | `docs/index.html`、`docs/en/index.html` 的 hero 与 JSON-LD；`docs/privacy.html`、`docs/support.html` 的「适用版本」 |
| 价格（中文 ¥12） | `docs/index.html` hero-meta、定价卡片、JSON-LD |
| 价格（英文 $1.99） | `docs/en/index.html` hero-meta、定价卡片、JSON-LD |
| App Store 链接 | 全站搜索 `id6828470287` |
| 联系邮箱 | 全站搜索 `h593526370@gmail.com` |
| 隐私政策正文 | `docs/privacy.html`（中文 + English 两份，注意同步修改） |
| 支持 FAQ | `docs/support.html`（中文 + English 两份，注意同步修改） |
| 截图与图标 | `docs/assets/site/`，由 `tools/site/build_assets.py` 生成 |
| 社交预览图 | `docs/assets/site/og-cover.png`（中文）/ `og-cover-en.png`（英文），1200×630 |
| 更新日期 | `sitemap.xml` 的 `lastmod`、隐私页「最后更新」、支持页「更新时间」 |

### 重新生成图片资源

```bash
python3 tools/site/build_assets.py
```

脚本使用 Pillow，读取：

- `docs/appstore/screenshots/raw/panel-dark.png`
- `docs/appstore/screenshots/raw/panel-light.png`
- `Pastable/Assets.xcassets/AppIcon.appiconset/icon_1024x1024.png`

生成面板 WebP、各尺寸图标和 OG 封面。改完截图后重跑一次即可。

## 六、文件结构

```text
docs/
├── index.html                 # 中文官网
├── en/index.html              # English site
├── privacy.html               # 隐私政策（中英同页，App Store 用这个 URL）
├── support.html               # 技术支持 + FAQ（中英同页）
├── 404.html                   # 自定义 404（绝对路径 /Pastable/）
├── styles.css                 # 全站样式
├── app.js                     # 主题预览、滚动显现、页头深色适配
├── .nojekyll                  # 关闭 Jekyll，按原样发布
├── robots.txt
├── sitemap.xml
└── assets/site/
    ├── panel-dark.webp / panel-light.webp
    ├── icon-32.png / icon-64.png / icon-192.png / icon-512.png
    ├── apple-touch-icon.png
    ├── og-cover.png / og-cover-en.png
    └── badge/                 # Apple 官方 Mac App Store 徽章（中/英，黑/白）
```

## 七、注意事项

- **`docs/` 整个目录都会公开**。GitHub Pages 会把 `docs/` 原样发布到公网，包括 `appstore/`、`modules/` 等未在导航中链接的文件。
  仓库本身也是公开的，因此不要在 `docs/` 里放密钥、手机号、税务信息等敏感内容；审核联系人等信息应只保留在 App Store Connect。
- **`.nojekyll` 不要删**。它会阻止 GitHub 用 Jekyll 处理 `docs/`，否则以 `_` 开头的文件可能被忽略。
- **`404.html` 用的是绝对路径 `/Pastable/`**。改仓库名或绑定自定义域名后要同步改。
- 邮箱 `h593526370@gmail.com` 是全站公开的。如果不想公开，可改成只保留 GitHub Issues，
  并在 App Store Connect 里另填审核联系人邮箱。
- 站点没有 Cookie、统计或第三方请求；字体全部使用系统的 Songti / PingFang / 系统无衬线，
  不依赖 Google Fonts。
- 图片使用 WebP（Safari 14+、macOS 15 均支持），并带 `width`/`height`，避免布局跳动。
- App Store 徽章来自 Apple Media Services 官方接口，请保持原始比例与配色，不要自行改色或拉伸。
- 发布后可在 <https://qiuzhsgithub.github.io/Pastable/sitemap.xml> 检查站点地图是否可访问；
  若长期不更新，可忽略 Google Search Console 的提交。
- GitHub Pages 自身属于 GitHub 的服务，访问日志由 GitHub 按其隐私声明处理，与本 App 的隐私承诺无关。

## 八、发布检查清单

- [ ] Settings → Pages 已设为 `main` / `/docs`
- [ ] 首页、`en/`、`privacy.html`、`support.html` 均返回 200
- [ ] 隐私页中文与 English 两段都能正常滚动、锚点跳转
- [ ] 支持页 FAQ 可展开；GitHub Issues 与新窗口链接可用
- [ ] App Store 徽章点击后打开 `https://apps.apple.com/app/id6828470287`
- [ ] 手机宽度（375 / 390）无横向滚动
- [ ] App Store Connect 已填入隐私政策与技术支持 URL
