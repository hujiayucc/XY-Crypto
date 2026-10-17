# 多平台应用身份对齐

基准应用：`/sdcard/MT2/mcp/XY加密_1.3.1.apk`

统一身份值：应用名 `XY加密`；版本 `1.3.1`；版本号 `180`；基准图标源为 Android `co.png`，SHA-256 `d980c008fbcaa8bd551f1bff7d48a3c15c6560c4cdd63f86dce616c0b29a3dae`。

| 平台 | 平台标识 | 版本 | 应用名称与图标 |
| --- | --- | --- | --- |
| Android | `com.hujiayucc.decode` | `1.3.1 (180)` | Manifest 标签 `XY加密`；`res/drawable/co.png` |
| Windows | AppUserModelID `com.hujiayucc.decode` | `1.3.1 (180)`；文件版本 `1.3.1.180` | 窗口标题、版本资源为 `XY加密`；多尺寸 `app_icon.ico` |
| Linux | GTK application ID `com.hujiayucc.decode` | `1.3.1`（Flutter 构建版本） | desktop 名称为 `XY加密`；hicolor 16–256 PNG 图标 |

## 配置位置

- Windows：`windows/runner/main.cpp`、`windows/runner/Runner.rc`、`windows/runner/resources/app_icon.ico`
- Linux：`linux/CMakeLists.txt`、`linux/xy_encrypt_app.desktop`、`linux/icons/hicolor/`

## 构建状态

- Android Debug：已验证，APK `com.hujiayucc.decode`，版本 `1.3.1 (180)`。
- Linux ARM64 Release：构建成功；bundle 位于 `build/linux/arm64/release/bundle`，可执行文件 SHA-256 为 `292e2ca55372e82e0cd009e52e196e704ef059c1c0843339c79c5ce7dbab14c7`，大小 `74968` 字节；desktop 文件和 8 个 hicolor 图标均已打包。
- Windows：工程配置和资源已完成，原生构建需 Windows/Visual Studio 宿主机。