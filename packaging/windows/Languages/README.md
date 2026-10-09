# Inno Setup 简体中文资源

`ChineseSimplified.isl` 来自 Inno Setup 上游翻译，保留原作者署名，翻译内容未修改；保存为带 BOM 的 UTF-8 以供英文 Windows runner 正确读取。

- 来源：https://raw.githubusercontent.com/jrsoftware/issrc/main/Files/Languages/ChineseSimplified.isl
- 获取日期：2026-10-09
- 上游维护者：Zhenghan Yang (Kira)，详见文件头。
- 本地文件 SHA-256：`3784dcfb01a7623fcb9de1b10959cb1348feeefaf9ce8d97a59217356e30ecad`
- 消息键及参数已与 Inno Setup `is-6_7_1/Files/Default.isl` 对照，未缺项。
- 许可证：同目录 `Inno-Setup-LICENSE.txt`。

CI 与 Release 使用 Inno Setup 6.7.1。升级编译器时应重新核对默认消息键与翻译占位符，防止新增界面退回英文。安装脚本只启用该语言，并关闭语言选择与旧安装语言继承。