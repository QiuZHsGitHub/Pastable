# Pastable · 繁體中文（台灣）App Store 文案

> 可直接貼進 App Store Connect 的繁體中文（台灣）localization。
> 主語言仍是簡體中文；英文版見 [en-metadata.md](en-metadata.md)。

---

## 欄位

### 名稱
```
Pastable
```

### 副標題（≤30 字元）
```
呼出即貼，不打斷手邊工作
```
12 字元。

### 推廣文字（≤170 字元）
```
全螢幕寬的底部浮層，快捷鍵隨時呼出。開啟時不搶鍵盤焦點，輸入繼續留給手邊的文件；選中卡片立即貼回，工作流不中斷。
```

### 關鍵字（≤100 字元，逗號分隔，不含 App 名稱）
```
剪貼簿,貼上,複製歷史,剪貼簿管理,浮層,快捷鍵,不打斷,效率,搜尋,片段
```

### 描述
```
Pastable 是 macOS 的全螢幕底部剪貼簿浮層：呼出即貼，不打斷手邊工作。

【不搶焦點，才是真的不打斷】
· 快捷鍵（預設 Command-Shift-V）在任意 App 上方喚出全螢幕寬的底部浮層
· 開啟面板時不搶鍵盤焦點：游標和輸入仍留在你正在寫的文件裡
· 選中卡片或按 Return，內容直接貼回目前的 App，面板隨即收起
· 切換桌面空間、進入全螢幕，面板也不會突然消失

【3 秒找回任何一條】
· 精確 / 模糊搜尋標題與全文，多關鍵字同時符合
· 文字、程式碼、連結、圖片、檔案自動分類，命中原因高亮
· 卡片直接預覽；圖片預先產生縮圖，捲動不卡

【有分寸的儲存】
· 歷史僅保存在本機；可選同步到你自己的 iCloud 私有 CloudKit
· 保留時間與容量上限可設；首次超過上限先問「清理 / 全部保留 / 稍後」
· 無帳號、無廣告、無追蹤、無統計 SDK

【效率細節】
· 自動貼上（需輔助使用權限；未授權時退回僅複製）
· Command-1…9 / Fn-1…9 數字快貼；全域快捷鍵可自訂
· 中國潮色「朱砂」主題，自動跟隨系統淺色 / 深色
· 開機時啟動可選

適用於 macOS 15.5 以上。
```

### 新功能

1.2.0：
```
1.2.0
· 面板版面與搜尋框最佳化，更緊湊順手
· 修正浮層定位與跨桌面顯示的若干問題
· 主題微調與效能改進
```

1.2.1：
```
1.2.1
· 新增「在 Mac App Store 評分」入口
· 細節最佳化與穩定性改進
```

### 版權
```
Copyright © 2026 Qiu ZH
```

---

## 截圖

依序上傳到繁體中文 localization：

1. `docs/appstore/screenshots/01-hero-hant-2880x1800.png`
2. `docs/appstore/screenshots/02-collection-hant-2880x1800.png`

首圖的 3 秒訊息：**全螢幕寬底部浮層 + 開啟時不搶鍵盤焦點、游標留在文件**。面板是實際 App 繁體中文介面，文件與標註是行銷合成。

## URL 與其他欄位

| 欄位 | 值 |
|---|---|
| 技術支援 URL | `https://qiuzhsgithub.github.io/Pastable/support.html` |
| 行銷 URL | `https://qiuzhsgithub.github.io/Pastable/` |
| 分類 | 工具 / 效率 |
| 年齡分級 | 4+ |
| App 隱私 | 未收集資料 |
| 價格 | 美國 $1.99 / 中國大陸 ¥12 |

### App Review Notes
```
Thank you for reviewing Pastable, a local-first macOS clipboard manager.

1. No account or login is required. All history is stored locally (SwiftData);
   optional iCloud sync uses the private CloudKit database of the user's own
   iCloud account, which we cannot access.
2. "Auto Paste" simulates Command-V into the frontmost app and therefore needs
   the Accessibility permission. The app guides the user to System Settings →
   Privacy & Security → Accessibility. If it is not granted, the app still
   works normally (copy to clipboard instead). This is not a private API; it
   uses CGEvent + AXIsProcessTrusted, which is standard for MAS clipboard
   managers.
3. No private APIs, no analytics, no third-party SDKs, no adult content.
```
