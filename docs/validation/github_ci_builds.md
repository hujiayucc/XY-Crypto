# GitHub Actions CI 构建

工作流：`.github/workflows/ci.yml`、`.github/workflows/release.yml`

触发方式：`code-check.yml` 响应所有分支 push、Pull Request 和手动触发，只做代码检查；`ci.yml` 仅支持手动触发并发布 Preview；`release.yml` 响应 `v*` 标签或手动指定发布标签并发布正式版。代码检查、Preview 和正式 Release 三者独立。

## 产物

- Android：`android-arm32-apk`、`android-arm64-apk`、`android-x86_64-apk`、`android-all-apk`
- Windows amd64/arm64：绿色版 `*-portable.zip` 与 Inno Setup `*-setup.exe`
- Linux amd64/arm64：可直接运行的 `*-portable.tar.gz`、`*-portable.tar.xz`，以及 Debian `*.deb`、RPM `*.rpm`、Arch `*.pkg.tar.zst`
- iOS：未签名 `XY-Crypto-ios-unsigned.tar.gz`
- macOS：未签名 `XY-Crypto-macos-unsigned.zip`

Windows 和 Linux 的架构使用矩阵分别构建，不把不同架构混入同一个包。Windows amd64 使用 x64 runner，Windows ARM64 使用 `windows-11-arm` runner；两者均直接运行对应架构的 Flutter Release 构建。Windows 绿色版解压后直接运行 `xy_encrypt_app.exe`。Linux amd64/arm64 使用对应 GitHub runner；portable 包解压后运行 bundle 内的 `xy_encrypt_app`，Debian/RPM/Arch 包分别负责对应发行版的安装入口、desktop 文件和图标注册。

## Android 签名 Secrets

可选配置以下 Repository Secrets：

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

没有这些 Secrets 时，CI 仍会构建 Release 变体 APK，并使用工程内的 Gradle debug 密钥签名；配置后自动改用 JKS 签名。签名类型不影响构建变体，CI 产物始终使用 `--release`。

## Apple 签名

当前 Apple job 产出未签名 CI 归档。正式签名需要在 `macos-14` runner 中增加 Apple Distribution/Developer ID 证书、Provisioning Profile、临时 Keychain 和 notarization 配置；Bundle ID 必须是 `com.hujiayucc.decode`。

## Windows 签名

当前 Windows job 产出未签名 portable ZIP 和 setup.exe。正式发布可在打包后用 `.pfx`、`signtool` 和时间戳服务签署 EXE、DLL 与安装程序。

## Linux 签名

当前 Linux job 为 amd64/arm64 分别产出可直接运行的 `.tar.gz`、`.tar.xz`，以及 Debian `.deb`、RPM `.rpm` 和 Arch `.pkg.tar.zst`。正式发布可在产物生成后使用 GPG detached signature 或 Sigstore/Cosign 签署，并把公钥或透明日志链接一并发布。

`code-check.yml` 不上传 Release；`ci.yml` 手动触发后把矩阵产物发布到 `preview-ci-*` 且标记为 Preview；`release.yml` 在 `v*` 标签或手动指定标签时把所有矩阵产物汇总到正式 GitHub Release，不标记为 Preview。
## 工具链兼容修复

- 默认 Flutter 3.35.4 / Dart 3.9.2；Windows ARM64 单独锁定 Flutter 3.47.7 / Dart 3.13.5。3.35.4 对应 engine 的 `windows-arm64/artifacts.zip` 返回 404，3.47.7 的 ARM64 主机工具、C++ wrapper 和 Release engine 已通过官方存储端点核验。
- Windows 共用 `tool/setup_flutter_windows.ps1`，3.35.4 补入 VS 2026 CMake 生成器映射，已有该映射的新 SDK 保持其映射；打包前检查 EXE 的 PE Machine（amd64 `0x8664`，arm64 `0xAA64`）。
- Linux/Windows ARM64 源码 SDK 显式建立 `bin/cache`、原生 Dart SDK 链接及 engine 标记；CMake 与命令行使用相同的 SDK 内 Flutter 入口。PowerShell 对原生命令检查退出码。
- Debian 控制目录和 control 文件分别设置为 755 和 644，兼容严格的 umask。
- 运行 `37898146213` 已验证 Linux 两架构与 Apple，并上传 Windows amd64 产物；Windows ARM64 当时仍使用旧 SDK，404 后按上述版本配对继续验证。完整 CI 成功与 Preview 发布以最新运行最终结论为准。
