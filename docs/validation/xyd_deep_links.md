# 外部 xyd 分享链接

支持链接：`xyd://share?type=<CryptoMode索引>&text=<URL编码内容>`。
正式分享链接由 `ShareCodec.encode` 生成，保留现有模式索引、BASE64 的 HEX 封装以及可选 `op`、`key` 参数。其他软件通过系统打开 URL 即可唤起应用；接收过程不读取剪切板。

## 行为

- 应用关闭：系统启动应用；已同意隐私政策时直接显示导入后的首页。
- 应用已打开：接收新的链接，关闭其他页面/弹窗并回到首页。
- 再次打开同一链接：允许重新导入，取消此前的永久去重。
- 首次启动：等待主动同意用户协议和隐私政策后再解析并导入。Android 保留原始 Intent；其他平台仅在内存暂存最新原始链接。
- 多个链接依次到达：串行导入，避免异步密钥读取造成先后顺序错乱。
- 无效模式、缺少内容或不支持的链接：显示提示，保留原有编辑内容；后续有效链接仍可导入。
- 分享含加密操作和密钥时，沿用现有解密流程；缺少密钥时保留密文供用户输入密钥。

## 系统接入

- Android：导出的 singleTask MainActivity 接收 BROWSABLE/DEFAULT ACTION_VIEW，注册整个 `xyd` scheme；Dart 继续严格验证 `share` host。ACTION_SEND/PROCESS_TEXT 保持可用。原生分享 channel 仅在同意后启用。
- Windows：Inno Setup 安装时在当前用户 `Software\Classes\xyd` 注册 URL Protocol；调用命令对 EXE 和 `%1` 分别加引号。链接启动时向已存在的应用窗口发送带 NUL 结尾的 UTF-8 WM_COPYDATA，使用 app_links 协议接收；传入缓冲区长度和终止符会先校验。直接解压 portable ZIP 不会自动修改系统协议注册，请使用安装版注册后测试系统唤起。
- Linux：desktop 文件声明 `Exec=xy_encrypt_app %u` 与 `MimeType=x-scheme-handler/xyd;`。GTK 单实例和 command-line/open 事件交给 app_links_linux；已存在窗口会显示到前台。安装包包含 desktop 注册文件；portable 目录的协议注册需由用户桌面环境安装该 desktop 入口并设置对应可执行路径。

## 手动验收

使用不含密钥的测试链接 `xyd://share?type=0&text=DeepLinkTest`：

- Android：`adb shell am start -W -a android.intent.action.VIEW -c android.intent.category.BROWSABLE -d 'xyd://share?type=0&text=DeepLinkTest'`。
- Windows 安装版：PowerShell 执行 `Start-Process 'xyd://share?type=0&text=DeepLinkTest'`。
- Linux 安装版：执行 `xdg-open 'xyd://share?type=0&text=DeepLinkTest'`。

分别验证关闭状态、后台状态、其他页面打开状态，以及清空输入后重复点击同一链接。首次启动验证同意之前不导入，同意之后导入。

来源软件需要允许自定义协议跳转；有些浏览器/聊天软件会拦截或不将自定义 URI 转为可点击链接，这时应使用该软件的“在外部应用打开”能力或系统分享入口。

## 验证范围
