# Paste 对标分析：Pastable 可借鉴的交互与性能做法

> 说明：本机沙箱无法访问外网（pasteapp.io / Wikipedia / GitHub 均被拦截），
> 文中对 Paste 的描述基于对其现版本产品的既有了解，未逐条核对最新 changelog，
> 落地前请以官方信息为准。对 Pastable 的所有结论均来自源码实读，附代码位置。

## 1. Paste 的核心做法

### 1.1 交互模型

| 能力 | Paste 的做法 | 价值 |
|------|-------------|------|
| 底部 Shelf | 全宽浮层从屏幕底部滑出，卡片横向排列，永远贴底 | 与当前 App 共存、不打断工作流 |
| 呼出 | 全局快捷键（默认 ⇧⌘V）+ 触控板手势/热角 | 「随叫随到」是这类产品的核心承诺 |
| 一键回贴 | 点卡片 = 写回剪贴板 + 回到原 App + 自动 ⌘V，Shelf 自动收起 | 全程零思考成本 |
| 搜索 | 打开即聚焦、即时搜索、类型过滤（文本/链接/图片/颜色/文件）、命中高亮 | 大历史量下仍能秒定位 |
| Pinboard | 常用片段钉到独立面板（分组/标签页），拖拽卡片进 Pinboard | 把「历史」升级为「素材库」 |
| 多选连贴 | 选中多张卡按顺序依次粘贴（粘贴队列） | 写邮件、填表等场景效率翻倍 |
| 拖拽输出 | 从 Shelf 直接拖卡片到任意 App | 不需要「复制-切换-粘贴」 |
| 粘贴格式控制 | 单次操作选择「粘贴为纯文本 / 去格式」 | 比全局开关更贴合实际场景 |
| 快捷键覆盖 | 数字键快贴前 N 项、方向键选择、Esc 关闭、键入即搜索 | 键盘流全程不碰鼠标 |
| 来源与元信息 | 卡片上标注来源 App、类型、时间 | 快速回忆「这是哪来的」 |
| 排除规则 | 按 App 排除（密码管理器等） | 隐私与噪音控制 |
| 生态 | iPhone/iPad 同步 + iOS 键盘扩展 + Widget | 跨设备粘贴是付费点 |

### 1.2 性能做法（从产品表现反推 + 同类实现常识）

- 面板常驻复用，呼出不重建窗口，接近零延迟出现。
- 卡片内容懒加载 + 预渲染缩略图；大图不解码原图，只画小尺寸 preview。
- 搜索有索引/预热，历史量到万级仍能跟手。
- 动画以弹簧/短时长为主，滚动惯性平滑；卡片 hover 只做轻量视觉反馈。
- 同步、索引、缩略图生成全部在后台，主线程只做展示。

## 2. Pastable 现状盘点：已经做得好的（保持）

这些是同类产品里也不落后的点，不要在重构中丢掉：

1. **采集流水线防御到位**：0.3s 轮询 + `.common` runloop mode + tolerance
   （`Pastable/Core/Clipboard.swift:46`）；多段写入的 120ms 稳定期 + generation 防错
   （`Pastable/Core/Clipboard.swift:61`）；忽略 transient/concealed/自身写入
   （`Pastable/Core/Clipboard.swift:25`）。
2. **采集时预渲染缩略图**，卡片渲染永不接触原图
   （`Pastable/Core/Clipboard.swift:92`、`Pastable/Models/HistoryItem.swift:704`），
   与 Paste 的思路一致，甚至更彻底（连 560px JPEG preview 都入库）。
3. **缓存有成本边界**：缩略图缓存按条数 + 解码字节数双限制
   （`Pastable/Core/ImageCache.swift:16`）。
4. **搜索预热字段**：`normalizedSearchTitle/Body` 每条缓存、折叠大小写/变音/全半角
   （`Pastable/Models/HistoryItem.swift:345`），搜索打分带 recency/frequency 加权
   （`Pastable/Core/SearchService.swift:53`）——这是 Paste 也有的「常用内容上浮」。
5. **展示元数据入库**（字数/体积/文件数）而不是每帧计算
   （`Pastable/Models/HistoryItem.swift:118`）。
6. **按键体系完整**：数字快贴、方向键选择、⌘⌫ 删除、Esc 关闭
   （`Pastable/ContentView.swift:148`）。
7. **维护策略有人情味**：超限历史先询问「清理/保留/稍后」，不偷偷删数据
   （`Pastable/Core/AppDelegate.swift:115`）。

## 3. 值得借鉴的地方（按优先级）

### P0 · 高价值 / 低成本

1. **把 Pin（置顶收藏）补完** —— 数据层已经就绪一半：模型有 `pin` 字段
   （`Pastable/Models/HistoryItem.swift:104`），Storage 的清理逻辑也已经跳过 pin 项
   （`Pastable/Persistence/Storage.swift:281` 等 5 处谓词），**但 UI 完全没有入口**。
   这是现成的「半成品功能」：先做「卡片 hover 显示 📌 / ⌘P 置顶」，
   置顶项排在列表最前且不受保留时长限制，就追平了 Paste 的核心差异化之一。
   进一步演进为 Pinboard（多个命名分组 + 顶部标签页）。

2. **搜索命中高亮 + 命中原因可见** —— 现在搜索会匹配完整内容
   （`Pastable/Core/SearchService.swift:12`），但卡片只显示截断预览
   （`Pastable/UI/Components/CardCell.swift:352`），
   用户经常「搜到了但看不出为什么匹配」。Paste 会标出命中片段。
   做法：命中 token 命中时滚动/切换卡片预览到命中窗口，并高亮 token。

3. **方向键导航放开限制** —— 目前搜索框非空时 ←/→ 不工作
   （`Pastable/ContentView.swift:178`），而搜索恰恰是用键盘找东西的主路径。
   Paste 在搜索结果里也能全键盘选择。改为：搜索中也允许 ←/→/↑/↓ 移动选中。

4. **数字角标** —— 前 9 张卡显示 `1`–`9` 角标，与 ⌘/Fn + 数字快贴
   （`Pastable/ContentView.swift:186`）形成可视化的快捷键映射。Paste 有类似的暗示设计。

### P1 · 明显提升体验

5. **单次粘贴格式控制** —— 现在「去除格式」是全局开关（`Preferences`）。
   增加 `⌥Enter = 以纯文本粘贴`、`⇧Enter = 仅复制不粘贴` 之类的按次覆盖，
   比全局开关实用得多（Paste 的粘贴变体逻辑）。

6. **拖拽输出** —— 卡片目前是纯 Button（`Pastable/UI/Components/CardList.swift:57`）。
   支持把卡片拖到任意 App（NSDraggingSource，把 contents 写到 dragging pasteboard），
   也顺带支持拖到 Pinboard 分组。这是「不打断工作流」承诺的自然延伸。

7. **面板呼出动效** —— 目前 openPanel 是 `orderFrontRegardless` + 事后定位
   （`Pastable/Core/AppDelegate.swift:193`），`setFrame(animate:)` 只是窗口级动画。
   Paste 是「Shelf 从底部弹上来」的滑入 + 轻微弹簧感，感知上的响应速度差别很大：
   先显示后定位（或 alpha + 轴向位移动画）会让面板「出现得更快」。

8. **多选连贴** —— ⌘Click 多选，按顺序依次粘贴（Paste 的粘贴队列）。
   当前数据流是「单选 → copy → 120ms → ⌘V」（`Pastable/ContentView.swift:92`），
   扩展成队列即可复用现有管线。

9. **按 App 排除列表** —— 现在只按 pasteboard 类型过滤 transient/concealed
   （`Pastable/Core/Clipboard.swift:25`），但密码管理器、银行 App 等未必都标 concealed。
   增加「永不记录这些 App」的排除表，采集处一行判断即可
   （`checkForChangesInPasteboard` 已经取了 frontApp）。

10. **分类过滤拆分** —— 目前「Others」把图片和文件混在一起
    （`Pastable/ContentView.swift:12`），Paste 按内容类型细分。
    图片和文件的使用场景完全不同，拆开后过滤才真正有用。

### P2 · 中长期

11. **Pinboard / 片段库**：命名分组 + 拖拽整理 + 长期保存，把产品定位从
    「历史记录」推向「素材库」（Paste 最大的留存抓手）。
12. **多设备生态**：Paste 的护城河是 iPhone/iPad + iOS 键盘扩展 + Widget。
    Pastable 已有 CloudKit 同步和 Universal Clipboard 类型识别
    （`Pastable/Models/HistoryItem.swift:457`），是做 iOS 伴侣端的基础。
13. **轻量片段（Snippet）+ 动态占位符**：与剪贴板历史同 UI 承载，边际成本低。
14. **触控板手势 / 热角呼出**：快捷键之外的第二条呼出通道。

## 4. 性能专项建议

已做得好（见第 2 节）之外，有四个可量化的隐患：

1. **RTF 解析结果没有跨实例缓存**。
   `cachedAttributedText` 是 `CardCell` 的 `@State`
   （`Pastable/UI/Components/CardCell.swift:313`），
   LazyHStack 复用/滚出可视区后 cell 重建，同一条 RTF 会反复解析
   （`Pastable/UI/Components/CardCell.swift:291`）。
   缩略图已经有 `ImageCache`，RTF 的 `AttributedString` 应同样进入一个
   按 contentHash 键控的共享缓存，或干脆在采集时预解析（与缩略图同路径）。
   只持久化了背景色（`cachedRTFBackgroundHexColor`），解析出来的正文却每次重算。

2. **每张卡最多 4 个 detached Task + 3 层 shadow**
   （`Pastable/UI/Components/CardCell.swift:205`、`CardCell.swift:191`）。
   单卡没问题，快速滚动 + 40 张以上可见卡时是可测的开销。
   建议：(a) 图标类查询合并为一次 task；(b) shadow 合并或用预渲染背景；
   (c) 用 Instruments 的 Core Animation / SwiftUI 模板实测滚动帧率再决定是否 `drawingGroup()`。

3. **全量加载 + 全量扫描的搜索路径**。
   `@Query` 拉全表（`Pastable/ContentView.swift:6`），
   每次 `onChange(of: items)` 全量去重 + 排序（`Pastable/Core/AppState.swift:73`），
   搜索 O(n) 全扫（`Pastable/Core/SearchService.swift:26`）。
   目前上限默认值下无压力；如果要向 Paste 的「无限历史」靠拢，
   需要：(a) 首屏 fetch 限量 + 滚动加载；(b) 搜索索引（token → item）或至少
   启动后空闲时预热 `normalizedSearchBody`（现在首次搜索才折叠，大文本历史首搜会顿）。

4. **粘贴延迟是固定 sleep**（`Pastable/ContentView.swift:112` 的 120ms）。
   可改为轮询 `changeCount` 就绪即发 ⌘V（通常 <30ms），慢机器上更稳，
   快机器上体感更快。同一思路也适用于采集侧的 120ms 稳定期
   （`Pastable/Core/Clipboard.swift:75`——这处保持保守是合理的，不建议动）。

## 5. 不建议照搬

- **无限历史默认值**：Paste 商业产品可以默认无限 + 云同步兜底；
  Pastable 是本地 SQLite，无限历史直接转化为磁盘与内存压力。
  现有的「超限先询问」策略反而更好，保留。
- **复杂的主题商店 / 多套皮肤**：现有「中国潮色 · 朱砂」单一主题 + 跟随系统
  已形成辨识度，主题系统继续围绕 token 演进即可。
- **iOS 键盘扩展先行**：投入大且与 Mac 主战场关系弱，等 Mac 版交互补齐后再说。

## 6. 一句话总结

Pastable 的**采集与渲染管线（缩略图预渲染、缓存边界、搜索预热）已经达到甚至局部超过
Paste 的水准**；真正的差距在**交互层的「第二眼功能」**：置顶/Pinboard（数据层已有半成品）、
搜索命中可视化、拖拽输出、粘贴格式按次控制、呼出动效。
优先补 P0 四项，性价比最高。

## 7. 落地记录

- 2026-10-27 · 性能专项（第 4 节）四项已全部实现：
  1. RTF 解析结果进共享缓存 `PreviewCache`（按 contentHash 键控，条数 + 字符数双限），
     卡片滚出可视区后不再重复解析同一 RTF。
  2. 单卡片最多 4 个 detached task 合并为 1 个（`CardAssets.load`），状态一次写入；
     阴影从 3 层降为 1~2 层（选中态光晕按需叠加），合并后阴影透明度微调以保持视觉深度。
  3. 首屏显示窗口（120 条/批，滚动或方向键到末端自动扩展）+ 空闲时分片预热搜索索引
     （`HistoryItem.warmUpSearchIndex`），避免首搜折叠全部历史。
  4. 粘贴改为「就绪即发」：轮询目标 App 获得焦点且写剪贴板落定后立即发 ⌘V
     （12ms 步进、400ms 超时兜底），替代固定 120ms 等待。
- 2026-10-27 · 搜索反馈（P0-2）与搜索框聚焦策略已实现：
  - 命中片段高亮：卡片标题与正文预览中所有命中以主题色底纹标出；当首个命中
    落在预览可见区之外时，预览自动切换到命中位置前后窗口（`SearchHighlight`），
    「搜到但看不出为什么匹配」的问题消除。RTF 内容在不丢样式的前提下就地高亮。
  - 搜索框聚焦策略：面板打开（任何触发方式）不再自动聚焦搜索框，仅 `⌘⇧F`
    或点击搜索框时聚焦；打开时显式清除残留焦点。

