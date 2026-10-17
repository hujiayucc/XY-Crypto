# XY加密

Flutter 三端文本编码与加解密工具，支持 Android、Windows 和 Linux。应用身份统一为“XY加密”，平台标识为 `com.hujiayucc.decode`，版本为 `1.3.1 (180)`。

## 目录

- `lib/`：Flutter 应用与共享业务逻辑。
- `packages/xy_crypto/`：共享算法包。
- `assets/`：法律文档、Emoji 和表情资源。
- `android/`、`windows/`、`linux/`：三端原生工程。
- `test/`：算法、分享协议和界面测试。
- `tool/build_legal_site.cjs`：从法律 Markdown 生成运行时 HTML。
- `.github/workflows/`：代码检查、Preview 和正式 Release 工作流。
- `packaging/`：Windows 安装器和 Linux Debian 打包脚本。

## 本地构建

安装 Flutter `3.35.4` 后执行：

1. `node tool/build_legal_site.cjs`
2. `flutter pub get`
3. `flutter analyze`
4. `flutter test`

各平台 CI 构建和产物说明见 `docs/validation/github_ci_builds.md`。