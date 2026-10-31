# 依赖说明

项目只依赖一个第三方库：

| 包名 | URL | 版本 |
|------|-----|------|
| KeyboardShortcuts | `https://github.com/sindresorhus/KeyboardShortcuts.git` | 2.4.0 |

依赖已经写入 `Pastable.xcodeproj` 和 `Package.swift`，Xcode 打开工程时会自动解析，**不需要手动添加**。

```bash
# 需要时手动解析/更新
xcodebuild -project Pastable.xcodeproj -scheme Pastable -resolvePackageDependencies
```

## 命令与测试

```bash
# 逻辑层单元测试（238 个用例，使用内存 SwiftData，不会碰真实数据库）
swift test

# 全量回归 + Xcode 构建 + 启动冒烟 + 112 项端到端体验（详见 docs/testing/自动化测试方案.md）
./tools/testing/run-tests.sh --smoke --e2e

# 构建 macOS App
xcodebuild -project Pastable.xcodeproj -scheme Pastable \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath /tmp/PastableDerived CODE_SIGNING_ALLOWED=NO build
```

端到端调试时可以用环境变量把数据库重定向到临时目录，避免污染真实历史：

```bash
PASTABLE_STORAGE_DIR=/tmp/PastableTest \
  /tmp/PastableDerived/Build/Products/Debug/Pastable.app/Contents/MacOS/Pastable
```
