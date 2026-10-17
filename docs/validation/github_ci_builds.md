# GitHub Actions CI 构建

工作流：`.github/workflows/ci.yml`、`.github/workflows/release.yml`

触发方式：`code-check.yml` 响应所有分支 push、Pull Request 和手动触发，只做代码检查；`ci.yml` 仅支持手动触发并发布 Preview；`release.yml` 响应 `v*` 标签或手动指定发布标签并发布正式版。代码检查、Preview 和正式 Release 三者独立。

## 产物

CI Preview 与正式 Release 统一使用 `XY加密-平台-架构.文件扩展名`。文件名不附加版本、portable、setup、unsigned 或 release；安装包和便携包以扩展名区分，签名状态仍见下方说明。

架构字段遵循各平台原有命名：Android 使用 ABI `armeabi-v7a`、`arm64-v8a`、`x86_64`（通用包为 `all`）；Windows/Linux 保留现有 `amd64`、`arm64`。构建矩阵内部的 Flutter 参数保持原值，仅调整发布文件名。

- Android：`XY加密-Android-armeabi-v7a.apk`、`XY加密-Android-arm64-v8a.apk`、`XY加密-Android-x86_64.apk`、`XY加密-Android-all.apk`（all 为通用 APK）。
- Windows amd64/arm64：`XY加密-Windows-<架构>.zip`（便携版）与 `XY加密-Windows-<架构>.exe`（安装程序）。
- Linux amd64/arm64：`XY加密-Linux-<架构>.deb`、`.rpm`、`.pkg.tar.zst`，以及便携版 `.tar.gz`、`.tar.xz`。


Windows 和 Linux 的架构使用矩阵分别构建，不把不同架构混入同一个包。Windows amd64 使用 x64 runner，Windows ARM64 使用 `windows-11-arm` runner；两者均直接运行对应架构的 Flutter Release 构建。Windows 绿色版解压后直接运行 `xy_encrypt_app.exe`。Linux amd64/arm64 使用对应 GitHub runner；portable 包解压后运行 bundle 内的 `xy_encrypt_app`，Debian/RPM/Arch 包分别负责对应发行版的安装入口、desktop 文件和图标注册。

## Android 签名 Secrets

可选配置以下 Repository Secrets：

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

没有这些 Secrets 时，CI 仍会构建 Release 变体 APK，并使用工程内的 Gradle debug 密钥签名；配置后自动改用 JKS 签名。签名类型不影响构建变体，CI 产物始终使用 `--release`。



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


## 安装界面语言

- Windows 安装版固定使用简体中文，包括安装向导、下一步/返回/取消按钮、路径选择、快捷方式、完成页与卸载提示；英文系统也使用中文。脚本仅启用 `chinesesimplified`，关闭语言选择和旧安装语言继承。
- Inno Setup 编译器锁定 6.7.1，中文语言文件随仓库保存于 `packaging/windows/Languages/ChineseSimplified.isl`；语言资源完整性已与该版本默认消息表逐项核对。`.iss` 与 `.isl` 使用 UTF-8 BOM，避免英文 runner 误读中文。
- Windows 安装程序属性和应用版本资源使用中文名称/说明；Linux Debian、RPM、Arch 包的应用简介及 desktop 说明使用中文。
- 便携 ZIP、tar.gz、tar.xz 直接解压运行，无安装向导。协议注册、既定产物命名和架构保持一致。
