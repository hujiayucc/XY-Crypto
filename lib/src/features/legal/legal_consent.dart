import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const legalConsentVersion = 'xy-legal-v2';

enum LegalDocument {
  agreement('用户协议', 'user_agreement_zh.md',
      'build_artifacts/legal_site/user_agreement_zh.html'),
  privacy('隐私政策', 'privacy_policy_zh.md',
      'build_artifacts/legal_site/privacy_policy_zh.html'),
  collection('个人信息收集清单', 'personal_information_list_zh.md'),
  sharing('第三方共享个人信息清单', 'third_party_sharing_zh.md'),
  sdk('第三方 SDK 与组件清单', 'sdk_list_zh.md'),
  permissions('权限用途说明', 'permissions_zh.md');

  const LegalDocument(this.title, this.file, [this.htmlFile]);
  final String title;
  final String file;
  final String? htmlFile;
}

class _HtmlBlock {
  const _HtmlBlock(this.tag, this.start, this.content);

  final String tag;
  final int start;
  final String content;
}

class LegalDocumentPage extends StatelessWidget {
  const LegalDocumentPage(
      {super.key, bool privacy = true, LegalDocument? document})
      : document = document ??
            (privacy ? LegalDocument.privacy : LegalDocument.agreement);

  final LegalDocument document;
  String get _title => document.title;
  String get _asset => 'assets/legal/${document.file}';

  @override
  Widget build(BuildContext context) {
    final htmlAsset = document.htmlFile;
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: FutureBuilder<String>(
        future: rootBundle.loadString(htmlAsset ?? _asset),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('文档加载失败，请稍后重试'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final children = htmlAsset == null
              ? snapshot.data!.split('\n').map((line) => _line(context, line))
              : _htmlWidgets(context, snapshot.data!);
          return SelectionArea(
              child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
            children: children.toList(),
          ));
        },
      ),
    );
  }

  List<Widget> _htmlWidgets(BuildContext context, String source) {
    final withoutCode = source
        .replaceAll(
            RegExp(r'<style\b[^>]*>[\s\S]*?</style>', caseSensitive: false), '')
        .replaceAll(
            RegExp(r'<script\b[^>]*>[\s\S]*?</script>', caseSensitive: false),
            '');
    final main = RegExp(r'<main\b[^>]*>([\s\S]*?)</main>', caseSensitive: false)
            .firstMatch(withoutCode)
            ?.group(1) ??
        withoutCode;
    final blocks = <_HtmlBlock>[];
    for (final tag in const ['h1', 'h2', 'h3', 'h4', 'p', 'table']) {
      final pattern = RegExp(
        '<$tag\\b[^>]*>([\\s\\S]*?)</$tag>',
        caseSensitive: false,
      );
      for (final match in pattern.allMatches(main)) {
        blocks.add(_HtmlBlock(tag, match.start, match.group(1)!));
      }
    }
    blocks.sort((a, b) => a.start.compareTo(b.start));
    if (blocks.isEmpty) return [const Text('文档内容为空')];
    return [
      for (final block in blocks)
        if (block.tag == 'table')
          _htmlTable(context, block.content)
        else
          _htmlTextBlock(context, block.tag, _decodeHtml(block.content)),
    ];
  }

  Widget _htmlTextBlock(BuildContext context, String tag, String text) {
    final style = switch (tag) {
      'h1' => Theme.of(context).textTheme.headlineSmall,
      'h2' || 'h3' || 'h4' => Theme.of(context).textTheme.titleLarge,
      _ => Theme.of(context).textTheme.bodyMedium,
    };
    final padding = tag == 'h1'
        ? const EdgeInsets.only(bottom: 12)
        : tag == 'h2' || tag == 'h3' || tag == 'h4'
            ? const EdgeInsets.only(top: 8, bottom: 6)
            : const EdgeInsets.only(bottom: 8);
    return Padding(padding: padding, child: Text(text, style: style));
  }

  Widget _htmlTable(BuildContext context, String source) {
    final rows = RegExp(
      r'<tr\b[^>]*>([\s\S]*?)</tr>',
      caseSensitive: false,
    ).allMatches(source).map((match) {
      final cells = RegExp(
        r'<(?:th|td)\b[^>]*>([\s\S]*?)</(?:th|td)>',
        caseSensitive: false,
      ).allMatches(match.group(1)!).map((cell) => _decodeHtml(cell.group(1)!));
      return cells.join(' | ');
    }).where((row) => row.trim().isNotEmpty);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(row),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _decodeHtml(String source) {
    var text =
        source.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');
    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('"', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&');
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Widget _line(BuildContext context, String raw) {
    final line = raw.trim();
    if (line.isEmpty) return const SizedBox(height: 10);
    if (line.startsWith('|---')) return const SizedBox.shrink();
    if (line.startsWith('|')) {
      final cells = line
          .split('|')
          .map((cell) => cell.trim())
          .where((cell) => cell.isNotEmpty)
          .toList();
      if (cells.isEmpty || cells.first.startsWith('---')) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (cells.isNotEmpty)
                  Text(cells.first,
                      style: Theme.of(context).textTheme.titleSmall),
                for (final cell in cells.skip(1)) ...[
                  const SizedBox(height: 4),
                  Text(cell),
                ],
              ],
            ),
          ),
        ),
      );
    }
    if (line.startsWith('# ')) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(line.substring(2),
            style: Theme.of(context).textTheme.headlineSmall),
      );
    }
    if (line.startsWith('## ')) {
      return Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 6),
        child: Text(line.substring(3),
            style: Theme.of(context).textTheme.titleLarge),
      );
    }
    if (line.startsWith('- ')) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('•  '),
            Expanded(child: Text(line.substring(2))),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(line.replaceAll('  ', '')),
    );
  }
}

class LegalConsentDialog extends StatefulWidget {
  const LegalConsentDialog({
    super.key,
    required this.onAccept,
    required this.onDecline,
  });

  final Future<void> Function() onAccept;
  final VoidCallback onDecline;

  @override
  State<LegalConsentDialog> createState() => _LegalConsentDialogState();
}

class _LegalConsentDialogState extends State<LegalConsentDialog> {
  late final TapGestureRecognizer _agreementRecognizer = TapGestureRecognizer()
    ..onTap = () => _openDocument(false);
  late final TapGestureRecognizer _privacyRecognizer = TapGestureRecognizer()
    ..onTap = () => _openDocument(true);
  bool _confirmed = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _agreementRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    if (!_confirmed || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onAccept();
    } on PlatformException catch (error) {
      if (!mounted) return;
      final details = error.details;
      final diagnostic = details is Map
          ? [details['plugin'], details['exception']]
              .whereType<String>()
              .where((value) => value.isNotEmpty)
              .join('/')
          : '';
      final suffix = diagnostic.isEmpty ? '' : ' [$diagnostic]';
      final message = switch (error.code) {
        'consent_activation_failed' =>
          '确认记录已保存，但应用组件初始化失败，请重试（${error.code}$suffix）',
        'consent_save_failed' => '保存确认记录失败，请重试（${error.code}$suffix）',
        _ => '确认过程失败，请重试（${error.code}$suffix）',
      };
      setState(() => _error = message);
    } catch (_) {
      if (mounted) setState(() => _error = '确认过程失败，请重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openDocument(bool privacy) async {
    if (_saving) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => LegalDocumentPage(privacy: privacy)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = scheme.primary;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '使用前请阅读并同意',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 18),
              Text(
                '欢迎使用 XY加密',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '文本与密钥在本机处理。文件、剪贴板和分享仅在你操作时使用。相机扫码另行说明 ML Kit 诊断数据处理，授权后再启用。',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.55,
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 14),
              Text.rich(
                TextSpan(
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.55,
                        color: scheme.onSurfaceVariant,
                      ),
                  children: [
                    const TextSpan(text: '请阅读 '),
                    _linkSpan('《用户协议》', accent, _agreementRecognizer),
                    const TextSpan(text: ' 和 '),
                    _linkSpan('《隐私政策》', accent, _privacyRecognizer),
                    const TextSpan(text: '。'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Theme(
                key: const ValueKey('consent-choice-theme'),
                data: Theme.of(context).copyWith(
                  splashFactory: NoSplash.splashFactory,
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                  checkboxTheme: Theme.of(context).checkboxTheme.copyWith(
                        overlayColor:
                            const WidgetStatePropertyAll(Colors.transparent),
                      ),
                ),
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  checkboxShape: const CircleBorder(),
                  value: _confirmed,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _confirmed = value ?? false),
                  title: const Text('我已阅读并同意以上内容'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 4),
                Text(
                  _error!,
                  style: TextStyle(color: scheme.error, fontSize: 12),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: _saving ? null : widget.onDecline,
                    child: const Text('退出应用'),
                  ),
                  FilledButton(
                    onPressed: _confirmed && !_saving ? _accept : null,
                    child: Text(_saving ? '正在保存…' : '同意并继续'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextSpan _linkSpan(
          String label, Color color, TapGestureRecognizer recognizer) =>
      TextSpan(
        text: label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          decoration: TextDecoration.underline,
          decorationColor: color,
        ),
        recognizer: recognizer,
      );
}
