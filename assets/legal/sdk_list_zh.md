# 第三方 SDK 与组件清单

版本：2.0
更新日期：2026/10/07
生效日期：2022/10/25
个人信息处理者：胡佳宇
联系邮箱：hujiayucc@qq.com

版本以本工程 pubspec.lock 及 Android 依赖解析为依据。开源项目维护者与法律意义上的数据接收者分别说明；未另设独立隐私政策的本地库不虚构隐私链接。依赖升级或替换后同步更新本清单。

| 组件与实际版本 | 开发者/维护者、来源与政策 | 功能、处理信息、触发条件 |
|---|---|---|
| mobile_scanner 6.0.11 | Julian Steenbakker / 开源贡献者；https://pub.dev/packages/mobile_scanner | 相机扫码桥接。Android 为 ML Kit + CameraX；桌面端使用系统相机能力。处理相机画面及二维码结果，仅选择相机后运行 |
| Google ML Kit barcode-scanning 17.3.0、common 18.11.0（捆绑模型） | Google LLC；https://developers.google.cn/ml-kit/android-data-disclosure?hl=zh-cn；https://policies.google.com/privacy | 图像本地识别；SDK 诊断信息见共享清单。Android 移除 MlKitInitProvider 自动初始化，用户确认扫码说明和相机授权后初始化 |
| AndroidX CameraX camera-lifecycle / camera-camera2 1.5.0 | Google / Android Open Source Project；https://developer.android.com/jetpack/androidx/releases/camera | 相机设备、预览、图像帧和生命周期；用户启用相机时调用，非账户或广告 SDK |
| flutter_secure_storage 9.2.4 | German Saprykin / 项目维护者；https://pub.dev/packages/flutter_secure_storage | 平台安全存储。处理用户选择保存的密码/JSON 密钥；桌面还存同意记录。未配置向作者发送内容 |
| file_picker 8.3.7 | Miguel Ruivo / 项目维护者；https://pub.dev/packages/file_picker | 用户选择文件和二维码图片后，读取内容、名称、路径/URI，可产生私有临时缓存；未配置向作者上传 |
| share_plus 10.1.4 | Flutter Community / Plus Plugins 维护者；https://pub.dev/packages/share_plus | 主动分享文本及链接，交给系统和用户选择的应用；不由插件作者接收这些内容 |
| url_launcher 6.3.2；Android 6.3.29 | Flutter 项目作者；https://pub.dev/packages/url_launcher | 打开用户指定的外部地址；目标应用/网站按各自规则处理请求 |
| webview_flutter 4.13.1；Android 4.12.0 | Flutter 项目作者；https://pub.dev/packages/webview_flutter | 系统 WebView 展示主动访问的页面，可能有 URL、IP、Cookie 和页面存储；首页无自动访问网站行为 |
| app_links 6.4.1 | llfbandit / 项目维护者；https://pub.dev/packages/app_links | 处理操作系统投递的链接；本版 Android 使用自有同意控制通道且不注册该插件，其余平台保留深链能力，原生初始化行为需各宿主验收 |
| image 4.10.1 | Brendan Duncan / 贡献者；https://pub.dev/packages/image | 本地解码、缩放用户选择的图片；无需网络/相机 |
| zxing2 0.2.4 | zxing-dart / xvrh 贡献者；https://pub.dev/packages/zxing2 | 本地图片二维码解码和二维码生成；处理像素或文本，不向作者上传 |
| crypto 3.0.6、pointycastle 3.9.1 | Dart 项目作者；Pointy Castle / Bouncy Castle 贡献者；https://pub.dev/packages/crypto；https://pub.dev/packages/pointycastle | 本机摘要、HMAC、派生、加密、签名运算；处理输入、参数与密钥，不带业务上传接口 |
| path_provider 2.1.5 / Android 2.2.23、flutter_plugin_android_lifecycle 2.0.34 | Flutter 项目作者；https://pub.dev/packages/path_provider；https://pub.dev/packages/flutter_plugin_android_lifecycle | 文件缓存目录与界面生命周期支持，本机路径/生命周期状态 |
| AndroidX Startup / Lifecycle / Core / ProfileInstaller、Google DataTransport 等间接原生依赖 | Google / Android 开源项目；https://developer.android.com/jetpack/androidx；https://developers.google.cn/ml-kit/android-data-disclosure?hl=zh-cn | 平台基础能力或 ML Kit 的间接运行组件；Google DataTransport 可承担诊断传输。实际解析依赖清单保存在构建证据中；不将其与本地算法库混称“零收集” |

Android 未同意前仅运行应用界面、离线政策和本地同意记录读取；业务插件在确认后注册。相机 SDK 另按使用场景延迟初始化。Flutter/操作系统基础运行并非个人信息收集免责依据，发行前仍需冷启动、拒绝、后台、权限撤回和网络抓包验证。