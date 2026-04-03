# CodeRelay

[English](README.md)

CodeRelay 是一个面向 macOS 的 Codex 辅助应用，适合需要管理多个 Codex 账号的用户。它会为每个账号维护独立的 `CODEX_HOME`，避免凭据互相污染，基于最近一次使用量快照展示哪些账号当前更适合切换过去使用，并在当前账号接近耗尽时主动预警。

## 当前状态

当前代码已经可以用于“账号纳管 + 使用量可见性 + 阈值预警”，但还不是完整的账号切换器。

已实现：

- 在 CodeRelay 管理的独立目录中执行 `codex login` 来添加账号
- 列出、重新认证、删除托管账号
- 在本地将某个托管账号标记为当前选中的 active 账号
- 从托管账号的 `auth.json` 中读取身份信息
- 检测账号凭据是 `file`、`keyring` 还是未验证状态
- 刷新全部托管账号的使用量快照，并在 UI 中显示 readiness 信息
- 按可配置的频率在后台仅刷新当前 active 托管账号
- 配置统一的低用量预警阈值与本地通知开关
- 当当前账号任一窗口低于阈值时，每个耗尽周期只发送一次预警
- 在管理窗口和菜单栏中显示 `stale` / `error` / `unknown` 监控风险
- 提供英文和简体中文的应用外壳与主要交互文案
- 将账号元数据和使用量快照持久化到 `~/Library/Application Support/CodeRelay`

尚未实现：

- 替换线上生效的 `~/.codex/auth.json` 和 `~/.codex/config.toml`
- 切换后自动恢复 Codex 会话或重建 CLI / App 工作流

## 运行要求

- macOS 15.0+
- 支持 SwiftPM 的 Swift 工具链
- `PATH` 中可用的 `codex`

点击 `Add Account` 时，CodeRelay 实际执行的是：

```bash
codex -c 'cli_auth_credentials_store="file"' login
```

这意味着当前版本最适合 file-backed 的 Codex 凭据。对于 keyring-backed 账号，CodeRelay 会识别出来，并在 UI 中标记为不适合做基于文件隔离的安全切换。

## 构建与运行

本地开发可直接执行：

```bash
swift build
swift test
swift run CodeRelayApp
```

## 打包发布

如果只是构建本地 ad-hoc 包：

```bash
zsh ./scripts/package_macos_release.sh
```

如果要构建正式分发用的 Developer ID 签名 + notarization 版本：

```bash
NOTARYTOOL_PROFILE=CodeRelayNotary \
zsh ./scripts/sign_and_notarize_macos_release.sh
```

这个正式发布脚本默认只产出适合 GitHub Release 的 `zip + dmg`。如果你还需要签名安装包，再显式覆盖 `PACKAGE_FORMATS=\"zip pkg dmg\"`。

产物会输出到 `dist/`：

- `CodeRelay.app`
- `CodeRelay-<VERSION>-macOS.zip`
- `CodeRelay-<VERSION>.pkg`
- `CodeRelay-<VERSION>.dmg`

正式发布前需要准备：

- 登录钥匙串里的 `Developer ID Application` 证书
- 登录钥匙串里的 `Developer ID Installer` 证书
- `xcrun notarytool` 的 keychain profile，例如 `CodeRelayNotary`

安全说明：

- 发布脚本只会从本机钥匙串读取签名证书，并从已经存在的 `notarytool` keychain profile 读取 notarization 凭据
- 仓库和 GitHub Release 中不会保存 Apple 私钥、`.p8` 文件、导出的证书或账号密钥材料

默认的本地打包脚本仍然使用 ad-hoc 签名。notarized 包装脚本会自动切到 Developer ID 签名，并把 app/pkg/dmg 提交给 Apple、staple ticket，最后再用 `codesign` 和 `spctl` 验证最终 app。

## 工作方式

1. 每个托管账号都会分配一个独立目录：`~/Library/Application Support/CodeRelay/managed-codex-homes/<uuid>/`
2. CodeRelay 将 `CODEX_HOME` 指向该目录后执行 `codex login`
3. 它从托管目录中的 `auth.json` 读取身份信息，并把账号元数据保存到本地 JSON 注册表
4. 刷新使用量时，会读取托管账号 token，调用 Codex 使用量接口，然后把快照写回本地
5. UI 会用这些快照展示当前 active 账号的使用情况，以及其他账号的 readiness
6. 运行时调度器会按配置在后台刷新当前 active 托管账号，并在每次刷新后重新评估预警状态
7. 预警状态按“耗尽周期”去重，当前账号在持续低于阈值期间不会重复弹通知

当前的 `Set Active` 只会修改 CodeRelay 内部保存的选中状态，并不会真正改写线上生效的 `~/.codex` 文件。

## 本地数据位置

当前版本会把数据写到以下位置：

- `~/Library/Application Support/CodeRelay/managed-codex-accounts.json`
- `~/Library/Application Support/CodeRelay/usage-snapshots.json`
- `~/Library/Application Support/CodeRelay/managed-codex-homes/<uuid>/`

在 macOS 上，JSON 存储文件会采用原子写入，并设置为 `0600` 权限。

## 项目结构

- `Sources/CodeRelayApp`：SwiftUI 应用壳与账号管理界面
- `Sources/CodeRelayCore`：账号模型、投影逻辑、持久化与文件安全校验
- `Sources/CodeRelayCodex`：Codex 登录、身份读取、凭据模式检测、使用量刷新
- `Tests/CodeRelayAppTests`：面向 UI 功能的测试
- `Tests/CodeRelayCoreTests`：核心模型与存储测试
- `Tests/CodeRelayCodexTests`：Codex 集成单元测试

## 当前限制

- 仅支持 macOS
- 依赖本机已安装的 `codex` CLI
- 还不能真正切换到线上 `~/.codex`
- 当前阶段的后台刷新只覆盖 active 托管账号
- 还没有自动恢复会话能力
