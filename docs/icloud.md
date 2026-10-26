# iCloud 同步

Pastable 的可选 iCloud 同步基于 **SwiftData + 私人 CloudKit 数据库**。它不依赖 iCloud Drive 文件同步，也不会把 SQLite 文件直接放进 iCloud Drive。

## 数据范围

开启后，以下内容会写入当前 Apple ID 的私人 CloudKit 数据库：

- 文本、代码、链接
- 图片（作为 CloudKit 资源存储）
- 文件类剪贴板项的文件路径
- 置顶状态、复制次数、首次/最近复制时间、OCR 标题
- 删除操作

剪贴板中的“文件”只同步文件 URL，不会上传文件本身。图片和长文本会占用 iCloud 存储空间。

iCloud 同步**默认关闭**。开启前的历史记录全部只在本机；开启后，SwiftData 会把现有本地记录纳入 CloudKit 存储。

## 使用方式

1. 确认系统已登录 iCloud：**系统设置 → Apple ID**。
2. 打开 **Pastable 设置 → 存储 → iCloud 同步**。
3. 阅读提示后选择 **立即重启** 或 **稍后**。
4. 重启完成后，状态应显示“已连接 iCloud，修改会自动同步”。

关闭同步会保留本地历史，但不会自动删除已经同步到 iCloud 的数据。之后重新开启，会再次合并云端历史。

## 实现要点

- `Storage` 在启动时根据 `Preferences.iCloudSyncEnabled` 选择：
  - 本地：`ModelConfiguration(cloudKitDatabase: .none)`
  - 云同步：`ModelConfiguration(cloudKitDatabase: .private("iCloud.com.qzh.Pastable"))`
- 切换开关必须重启，因为 `ModelContainer` 只在启动时创建。
- 所有模型属性都有默认值或为可选，`contents` 关系也是可选；这是 CloudKit 对 SwiftData 模型的硬性要求。
- `HistoryItemContent.value` 使用 `@Attribute(.externalStorage)`。大图片在本地保存为外部文件，并在 CloudKit 中映射为资源，避免超过单条记录的体积限制。
- 云端没有唯一约束，因此两台 Mac 可能各自上传同一条内容。`Storage.deduplicateHistory()` 会在启动、维护和打开面板时按 `contentHash` 合并重复项，并保留置顶状态、最小首次复制时间和最大最近复制时间。
- `CloudSyncMonitor` 监听 `NSPersistentCloudKitContainer.eventChangedNotification`。初始化、导入或导出失败时，设置页会显示错误，而不是误报“已连接”。

## 开发者配置

CloudKit 容器：`iCloud.com.qzh.Pastable`

- Debug 使用 `Pastable/PastableDebug.entitlements`
  - `com.apple.developer.icloud-container-environment = Development`
- Release 使用 `Pastable/Pastable.entitlements`
  - 不写死环境，由分发 profile 决定；当前直接分发构建会使用 Production

两个文件都声明：

```xml
<key>com.apple.developer.icloud-container-identifiers</key>
<array>
    <string>iCloud.com.qzh.Pastable</string>
</array>
<key>com.apple.developer.icloud-services</key>
<array>
    <string>CloudKit</string>
</array>
<key>com.apple.developer.ubiquity-kvstore-identifier</key>
<string>$(TeamIdentifierPrefix)com.qzh.Pastable</string>
```

首次在新的开发者账号或新 Mac 上签名时，需要允许 Xcode 自动创建/更新 provisioning profile：

```bash
xcodebuild -project Pastable.xcodeproj -scheme Pastable \
  -configuration Debug -destination 'platform=macOS' \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration build
```

### 发布前部署 CloudKit Schema

CloudKit 的 **Development** 环境会随着开发构建自动创建记录类型，但 **Production** 环境不会自动获得这些类型。正式分发前必须：

1. 用 Debug 构建成功同步一次，让 Development 环境生成 Schema。
2. 打开 [CloudKit Console](https://icloud.developer.apple.com/dashboard/)，选择容器 `iCloud.com.qzh.Pastable`。
3. 在 **Schema → Deploy Schema Changes** 中把 Development 的 Schema 部署到 Production。

没有部署 Production Schema 时，Release 构建会打开本地数据库并继续工作，但设置页会显示同步失败。当前签名方式（Apple Development，未公证）在部分网络环境下还可能遇到 CloudKit 服务端 HTTP 500；这是服务端/环境问题，不是本地数据库损坏。

也可以用 `cktool` 导出/导入（需要 CloudKit Dashboard 的 management token）：

```bash
xcrun cktool export-schema \
  --team-id 754Q6V2X9B \
  --container-id iCloud.com.qzh.Pastable \
  --environment development \
  --output-file docs/cloudkit-schema.ckdb
```

## 本地测试

Debug 构建支持环境变量覆盖，不会改动真实偏好：

```bash
open -n --env PASTABLE_STORAGE_DIR=/tmp/PastableCloud \
  --env PASTABLE_ICLOUD_SYNC=1 \
  /tmp/PastableCloudDerived/Build/Products/Debug/Pastable.app
```

用临时数据库测试可以避免污染 `~/Library/Application Support/Pastable`。CloudKit 事件和错误会出现在 Console.app 的 `com.apple.coredata:CloudKit` 与 `com.apple.cloudkit` 分类中。

## 已知限制

- CloudKit 是最终一致同步，不保证实时；两台 Mac 同时在线时通常几秒内可见。
- 同一内容在两台设备上离线复制，仍可能短暂出现两张卡片，打开面板或下次启动时会自动合并。
- 历史上限和保留时间会同步删除操作；如果两台 Mac 使用不同的上限，以各自设备的维护结果为准。
- 大图片会占用 iCloud 配额；可在“存储类型”中关闭图片采集。
- Apple Development 签名、未公证的构建在部分网络/地区可能无法连接 CloudKit。正式发布建议使用 Developer ID 或 Mac App Store 分发，并部署 Production Schema。
