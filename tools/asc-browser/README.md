# asc-browser · App Store Connect 自动化浏览器

给 agent 用的网页操作工具:**独立配置的 Chrome**(登录态只存在本地专用 profile),
你手动登录一次 App Store Connect(含两步验证),之后新建 App 记录、填表单、传截图、
提交审核这些点击工作都由 agent 通过 CDP 完成。

## 使用流程

### 1. 打开浏览器(新会话里对 agent 说一句「打开浏览器」即可)

```bash
tools/asc-browser/open.sh
```

会弹出一个独立配置的 Chrome 窗口(专属 profile,不污染你日常的 Chrome),
并停在 App Store Connect。脚本幂等:已经在跑就直接复用,不会开第二个实例。

### 2. 你登录一次

在弹出的窗口里正常登录 App Store Connect,两步验证照常走一遍。
登录态保存在专用 profile 里,**之后不用再登录**。

> Profile 位置:`~/.pastable-asc-profile`(含登录 Cookie,不要打包/提交/分享)
> 调试端口:`127.0.0.1:9223`(仅本机),可用 `ASC_CDP_PORT` / `ASC_PROFILE_DIR` 覆盖

### 3. 之后由 agent 替你点网页

agent 连接 CDP 后用 `drive.mjs` 操作:

```bash
cd tools/asc-browser
node drive.mjs pages                 # 看看现在开着哪些页
node drive.mjs snapshot              # 页面元素清单(@序号 + 选择器 + 当前值)
node drive.mjs shot build/asc/s.png  # 截图(供人眼核对关键步骤)
node drive.mjs fill 'input[name="name"]' 'Pastable'
node drive.mjs click 'text=继续'
node drive.mjs upload 'input[type=file]' ../docs/appstore/screenshots/01-dark-2880x1800.png
node drive.mjs eval 'document.body.innerText.slice(0,500)'
```

典型自动化顺序(对应 [submission-checklist.md](../../docs/appstore/submission-checklist.md)):

1. 「我的 App」→ ➕ → 新建 macOS App(名称/主语言/套件 ID/SKU)
2. 版本页:选择 build、粘贴文案、传 2 张截图、App 隐私、年龄分级、出口合规、定价、审核备注
3. 「添加以供审核」→「提交审核」—— **提交前先 `shot` 截图给你确认**

## 注意

- 两步验证、协议/税务/银行等涉密或涉钱步骤永远由**你本人**操作;agent 只做表单填写与提交前的准备。
- 关掉 Chrome 窗口即结束;下次 `open.sh` 会用同一 profile 重新打开,依旧免登录。
- 想彻底登出/换账号:删掉 `~/.pastable-asc-profile` 重新登录。
- 驱动脚本清单见 [drive.mjs](drive.mjs) 头部注释;`@序号` 来自 `snapshot`,页面刷新后需重新 `snapshot`。
