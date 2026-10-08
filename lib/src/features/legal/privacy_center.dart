import 'package:flutter/material.dart';

import '../../core/privacy_runtime.dart';
import 'legal_consent.dart';

class PrivacyCenter extends StatelessWidget {
  const PrivacyCenter(
      {super.key, required this.onClearKeys, required this.onWithdraw});
  final Future<void> Function() onClearKeys;
  final Future<void> Function() onWithdraw;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('隐私中心')),
        body: ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              for (final document in LegalDocument.values)
                ListTile(
                  title: Text(document.title),
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) =>
                              LegalDocumentPage(document: document))),
                ),
              const Divider(),
              ListTile(
                title: const Text('系统权限管理'),
                subtitle: const Text('相机只用于扫码；关闭权限仍可进行本地加解密'),
                onTap: () async {
                  try {
                    final opened = await PrivacyRuntime.openPermissions();
                    if (!context.mounted || opened) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('请在系统设置的隐私与安全中管理本应用权限')));
                  } catch (_) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('请在系统设置 → 应用 → XY加密 → 权限中管理')));
                  }
                },
              ),
              ListTile(title: const Text('清除本机已保存密钥'), onTap: onClearKeys),
              ListTile(
                  title: const Text('撤回协议同意'),
                  subtitle: const Text('清空会话并退出；已保存密钥可在上方单独清除'),
                  onTap: onWithdraw),
              const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('本版本没有账号、个性化广告或定向推送，因此没有账号注销或推荐开关。隐私联系渠道见隐私政策。')),
            ]),
      );
}
