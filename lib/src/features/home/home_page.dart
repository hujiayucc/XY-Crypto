import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zxing2/qrcode.dart';
import '../../core/crypto_engine.dart';
import '../../core/scan_picker.dart';
import '../../core/share_codec.dart';
import 'emoji_catalog.dart';
import 'emoji_sheet.dart';
import 'emoji_text_editing_controller.dart';
import 'home_controller.dart';
import 'home_status_banner.dart';
import 'input_editor_pane.dart';
import 'key_input_sheet.dart';
import 'mode_panel.dart';
import 'operation_bar.dart';
import 'output_editor_pane.dart';
import '../legal/legal_consent.dart';
import '../legal/privacy_center.dart';
import 'share_qr_dialog.dart';

enum _ShareAction { system, copyLink, qr, file }

class _ShareOptions {
  const _ShareOptions({required this.includeKey});

  final bool includeKey;
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.controller,
    this.onWithdrawConsent,
  });
  final HomeController controller;
  final Future<void> Function()? onWithdrawConsent;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _websiteBase = 'https://app.hujiayucc.cn';
  static const _appVersion = '1.3.2';
  static const _appBuild = 181;
  late final EmojiTextEditingController _input;
  late final EmojiTextEditingController _output;
  bool _keyDialogOpen = false;
  HomeController get model => widget.controller;

  @override
  void initState() {
    super.initState();
    _input = EmojiTextEditingController(text: model.input)
      ..addListener(_inputChanged);
    _output = EmojiTextEditingController(text: model.output);
    model.addListener(_modelChanged);
  }

  void _inputChanged() {
    if (_input.text != model.input) model.input = _input.text;
  }

  void _modelChanged() {
    if (_input.text != model.input) {
      _input.value = TextEditingValue(
          text: model.input,
          selection: TextSelection.collapsed(offset: model.input.length));
    }
    if (_output.text != model.output) _output.text = model.output;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    model.removeListener(_modelChanged);
    _input.removeListener(_inputChanged);
    _input.dispose();
    _output.dispose();
    super.dispose();
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _run(bool encode) async {
    if (model.busy || _keyDialogOpen || model.input.isEmpty) return;
    FocusScope.of(context).unfocus();
    var key = '';
    if (model.mode.needsKey) {
      _keyDialogOpen = true;
      String? selected;
      try {
        if (encode) {
          final saved = await _readSavedKey();
          if (saved != null && saved.isNotEmpty) {
            key = saved;
          } else {
            selected =
                await _openKeyDialogWithResult(initialValue: saved ?? '');
          }
        } else {
          selected = await _openKeyDialogWithResult();
        }
      } finally {
        _keyDialogOpen = false;
      }
      if (!mounted || selected == null && key.isEmpty) return;
      if (selected != null) key = selected;
    }
    await model.run(encode: encode, key: key);
  }

  Future<String?> _readSavedKey() async {
    try {
      return await model.readKey(model.mode);
    } catch (_) {
      _message('密钥存储未就绪，本次可直接输入');
      return null;
    }
  }

  Future<void> _showKeyDialog() async {
    await _openKeyDialog();
  }

  Future<String?> _openKeyDialogWithResult({String? initialValue}) async {
    final mode = model.mode;
    final initial = initialValue ?? await _readSavedKey() ?? '';
    if (!mounted) return null;
    final result = await showDialog<KeySheetResult>(
      context: context,
      builder: (dialogContext) =>
          KeyInputSheet(mode: mode, initialValue: initial),
    );
    final key = result?.value;
    if (key != null && result!.remember) {
      try {
        await model.rememberKey(mode, key);
      } catch (_) {
        _message('本次密钥已使用，设备存储未保存');
      }
    }
    return key;
  }

  Future<String?> _openKeyDialog({String? initialValue}) async {
    if (model.busy || _keyDialogOpen || !model.mode.needsKey) return null;
    FocusScope.of(context).unfocus();
    _keyDialogOpen = true;
    try {
      return await _openKeyDialogWithResult(initialValue: initialValue);
    } finally {
      _keyDialogOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter, control: true): () =>
              _run(true),
          const SingleActivator(LogicalKeyboardKey.enter,
              control: true, shift: true): () => _run(false),
          const SingleActivator(LogicalKeyboardKey.enter, meta: true): () =>
              _run(true),
          const SingleActivator(LogicalKeyboardKey.enter,
              meta: true, shift: true): () => _run(false),
        },
        child: Scaffold(
          appBar: AppBar(
            toolbarHeight: 64,
            title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('XY加密'),
                Text('文本编码与加解密', style: TextStyle(fontSize: 11)),
              ],
            ),
            actions: [
              IconButton(
                tooltip: '扫一扫',
                onPressed: _scan,
                icon: const Icon(Icons.qr_code_scanner),
              ),
              IconButton(
                tooltip: '分享',
                onPressed: model.shareText.isEmpty ? null : _share,
                icon: const Icon(Icons.share_outlined),
              ),
              MenuAnchor(
                menuChildren: [
                  SubmenuButton(
                    menuChildren: [
                      MenuItemButton(
                        onPressed: () => _menu('import'),
                        child: const Text('导入文本或分享链接'),
                      ),
                      MenuItemButton(
                        onPressed: () => _menu('pasteShare'),
                        child: const Text('从剪贴板导入分享链接'),
                      ),
                      MenuItemButton(
                        onPressed: _pickFile,
                        child: const Text('导入文本或 .xyshare 文件'),
                      ),
                    ],
                    child: const Text('导入'),
                  ),
                  MenuItemButton(
                    onPressed: () => _menu('update'),
                    child: const Text('更新检测'),
                  ),
                  MenuItemButton(
                    onPressed: () => _menu('privacyCenter'),
                    child: const Text('隐私中心'),
                  ),
                  MenuItemButton(
                    onPressed: () => _menu('exit'),
                    child: const Text('退出'),
                  ),
                ],
                builder: (context, controller, child) => IconButton(
                  tooltip: '更多',
                  onPressed: () => controller.isOpen
                      ? controller.close()
                      : controller.open(),
                  icon: const Icon(Icons.more_vert),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, size) {
                final landscape = size.maxWidth > size.maxHeight;
                final desktop = size.maxWidth >= 1100;
                final wide =
                    size.maxWidth >= 700 || (landscape && size.maxWidth >= 600);
                final editorHeight = size.maxHeight < 600
                    ? 220.0
                    : desktop
                        ? 430.0
                        : wide
                            ? 320.0
                            : 280.0;
                final content = _content(
                  wide: wide,
                  desktop: desktop,
                  editorHeight: editorHeight,
                );
                return SingleChildScrollView(
                  padding: EdgeInsets.all(size.maxWidth < 360 ? 16 : 24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: desktop
                            ? 1440
                            : wide
                                ? 1100
                                : 700,
                      ),
                      child: content,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

  Widget _content({
    required bool wide,
    required bool desktop,
    required double editorHeight,
  }) {
    final modePanel = ModePanel(
      mode: model.mode,
      encodingLabel: _encodingLabel(_choiceForMode(model.mode), model.mode),
      wide: wide,
      onAlgorithm: model.busy ? null : _chooseAlgorithm,
      onEncoding: model.busy ? null : _chooseEncoding,
      onKey: model.busy ? null : _showKeyDialog,
    );
    final input = InputEditorPane(
      controller: _input,
      height: editorHeight,
      onImport: _pickFile,
      onEmoji: _emoji,
      onClear: model.clearInput,
    );
    final output = OutputEditorPane(
      controller: _output,
      height: editorHeight,
      sourceMode: model.outputMode,
      stale: model.outputStale,
      onCopy: () => _copy(model.output),
      onShare: _share,
      onRestore: model.restoreOutputToInput,
      onClear: model.clearOutput,
    );
    final operation = OperationBar(
      spec: model.mode.operationSpec,
      busy: model.busy,
      wide: wide,
      onPrimary: () => _run(true),
      onSecondary: () => _run(false),
    );
    final editors = desktop
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: input),
              const SizedBox(width: 18),
              SizedBox(width: 160, child: operation),
              const SizedBox(width: 18),
              Expanded(child: output),
            ],
          )
        : wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: input),
                  const SizedBox(width: 18),
                  Expanded(child: output),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  input,
                  const SizedBox(height: 16),
                  operation,
                  const SizedBox(height: 16),
                  output,
                ],
              );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        modePanel,
        const SizedBox(height: 18),
        if (wide && !desktop) ...[
          operation,
          const SizedBox(height: 16),
        ],
        editors,
        HomeStatusBanner(
          busy: model.busy,
          error: model.error,
          message: model.statusMessage,
        ),
      ],
    );
  }

  CryptoAlgorithmChoice _choiceForMode(CryptoMode mode) =>
      cryptoAlgorithmChoices.firstWhere(
        (choice) => choice.label == mode.algorithmLabel,
      );

  // Keep historic mode IDs decodable. Only exact duplicate labels are merged;
  // distinct byte encodings (GB18030/GBK/UTF-8) remain selectable.
  List<CryptoMode> _visibleEncodingModes(CryptoAlgorithmChoice choice) {
    final seenLabels = <String>{};
    return choice.modes
        .where((mode) => seenLabels.add(mode.formatLabel))
        .toList();
  }

  String _encodingLabel(CryptoAlgorithmChoice choice, CryptoMode mode) =>
      mode.formatLabel;

  Future<void> _chooseAlgorithm() async {
    FocusScope.of(context).unfocus();
    final currentChoice = _choiceForMode(model.mode);
    final choice = await showDialog<CryptoAlgorithmChoice>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('请选择算法'),
        content: SizedBox(
          width: 320,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final item in cryptoAlgorithmChoices)
                  ListTile(
                    selected: item == currentChoice,
                    title: Text(item.label),
                    trailing:
                        item == currentChoice ? const Icon(Icons.check) : null,
                    onTap: () => Navigator.pop(dialogContext, item),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return;

    var nextMode = _visibleEncodingModes(choice).first;
    for (final mode in _visibleEncodingModes(choice)) {
      if (_encodingLabel(choice, mode) ==
          _encodingLabel(currentChoice, model.mode)) {
        nextMode = mode;
        break;
      }
    }
    model.setMode(nextMode);
  }

  Future<void> _chooseEncoding() async {
    FocusScope.of(context).unfocus();
    final currentMode = model.mode;
    final choice = _choiceForMode(currentMode);
    final selected = await showDialog<CryptoMode>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${choice.label} · 请选择编码方式'),
        content: SizedBox(
          width: 320,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final mode in _visibleEncodingModes(choice))
                  ListTile(
                    selected: mode == currentMode ||
                        _encodingLabel(choice, mode) ==
                            _encodingLabel(choice, currentMode),
                    title: Text(_encodingLabel(choice, mode)),
                    trailing: _encodingLabel(choice, mode) ==
                            _encodingLabel(choice, currentMode)
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () => Navigator.pop(dialogContext, mode),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
        ],
      ),
    );
    if (mounted && selected != null) model.setMode(selected);
  }

  Future<void> _emoji() async {
    FocusScope.of(context).unfocus();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      barrierColor: Colors.transparent,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => OriginalEmojiSheet(
        entries: originalEmojiCatalog,
        onSelection: _handleEmojiSelection,
      ),
    );
  }

  void _handleEmojiSelection(EmojiPanelSelection selected) {
    if (selected.isDelete) {
      _deletePreviousEmoji();
      return;
    }
    final item = selected.item;
    if (item == null) return;
    final value = item.insertionText;
    final selection = _input.selection;
    final start = selection.isValid ? selection.start : _input.text.length;
    final end = selection.isValid ? selection.end : _input.text.length;
    _input.value = TextEditingValue(
      text: _input.text.replaceRange(start, end, value),
      selection: TextSelection.collapsed(offset: start + value.length),
    );
  }

  void _deletePreviousEmoji() {
    final selection = _input.selection;
    if (!selection.isValid || !selection.isCollapsed || selection.start <= 0) {
      return;
    }
    final text = _input.text;
    var start = selection.start - 1;
    final previous = text.codeUnitAt(start);
    if (previous >= 0xDC00 && previous <= 0xDFFF && start > 0) {
      final high = text.codeUnitAt(start - 1);
      if (high >= 0xD800 && high <= 0xDBFF) start--;
    }
    final tokenStart = text.lastIndexOf('[', selection.start - 1);
    final tokenEnd = text.lastIndexOf(']', selection.start - 1);
    if (tokenEnd == selection.start - 1 && tokenStart >= 0) start = tokenStart;
    _input.value = TextEditingValue(
      text: text.replaceRange(start, selection.start, ''),
      selection: TextSelection.collapsed(offset: start),
    );
  }

  Future<void> _pickFile() async {
    try {
      final files = await FilePicker.platform.pickFiles(withData: false);
      if (files == null || !mounted) return;
      final file = files.files.single;
      if (file.size > ShareFileCodec.maxFileBytes) {
        throw const FormatException('文件超过 32 MB');
      }
      final bytes = file.bytes ??
          (file.path == null ? null : await File(file.path!).readAsBytes());
      if (bytes == null || !mounted) return;
      if (bytes.length > ShareFileCodec.maxFileBytes) {
        throw const FormatException('文件超过 32 MB');
      }
      if (file.name.toLowerCase().endsWith(ShareFileCodec.extension)) {
        await model.importSharedText(ShareFileCodec.decode(bytes));
        if (mounted) _message(model.statusMessage ?? '分享文件已导入');
      } else {
        model.input = utf8.decode(bytes);
      }
    } on FormatException catch (error) {
      if (mounted) _message(error.message);
    } catch (error) {
      if (mounted) _message('文件读取失败：$error');
    }
  }

  Future<void> _scan() async {
    try {
      final text = await scanText(context);
      if (mounted && text != null) await model.importText(text);
    } catch (error) {
      _message('识别失败：$error');
    }
  }

  Future<void> _copy(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      _message('复制成功');
    } catch (error) {
      _message('复制失败：$error');
    }
  }

  Future<void> _share() async {
    if (model.shareText.isEmpty) {
      _message('请先生成结果');
      return;
    }
    final shareOptions = await _askShareOptions();
    if (!mounted || shareOptions == null) return;
    final mode = model.shareMode;
    final text = model.shareText;
    final operation =
        model.shareIsEncrypted ? ShareCodec.encryptOperation : null;
    final key = shareOptions.includeKey && model.shareIsEncrypted
        ? model.shareKey
        : null;
    Uri? webUri;
    String? linkError;
    try {
      final uri = ShareCodec.encode(mode, text, operation: operation, key: key);
      webUri = ShareCodec.encodeWebUrl(uri);
    } on FormatException catch (error) {
      linkError = error.message;
    }
    final link = webUri;
    final action = await showModalBottomSheet<_ShareAction>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (linkError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text('$linkError，请选择分享文件'),
            ),
          ListTile(
            enabled: link != null,
            leading: const Icon(Icons.ios_share_outlined),
            title: const Text('系统分享'),
            subtitle: Text(
              shareOptions.includeKey ? '包含密钥的可导入链接' : '不包含密钥',
            ),
            onTap: link == null
                ? null
                : () => Navigator.pop(sheetContext, _ShareAction.system),
          ),
          ListTile(
            enabled: link != null,
            leading: const Icon(Icons.link),
            title: const Text('复制链接'),
            subtitle: const Text('复制网站分享链接'),
            onTap: link == null
                ? null
                : () => Navigator.pop(sheetContext, _ShareAction.copyLink),
          ),
          ListTile(
            enabled: link != null,
            leading: const Icon(Icons.qr_code_2),
            title: const Text('二维码'),
            subtitle: const Text('使用扫一扫导入'),
            onTap: link == null
                ? null
                : () => Navigator.pop(sheetContext, _ShareAction.qr),
          ),
          ListTile(
            leading: const Icon(Icons.insert_drive_file_outlined),
            title: const Text('分享文件'),
            subtitle: const Text('适合超长内容，生成 .xyshare 文件'),
            onTap: () => Navigator.pop(sheetContext, _ShareAction.file),
          ),
        ]),
      ),
    );
    if (!mounted || action == null) return;
    if (action == _ShareAction.file) {
      await _shareFile(mode, text, operation: operation, key: key);
      return;
    }
    if (link == null) return;
    switch (action) {
      case _ShareAction.system:
        await _shareSystem(link);
      case _ShareAction.copyLink:
        await _copyShareLink(link);
      case _ShareAction.qr:
        await _showShareQr(link);
      case _ShareAction.file:
        break;
    }
  }

  Future<void> _shareFile(CryptoMode mode, String text,
      {String? operation, String? key}) async {
    final box = context.findRenderObject() as RenderBox?;
    try {
      final bytes =
          ShareFileCodec.encode(mode, text, operation: operation, key: key);
      await Share.shareXFiles(
        [
          XFile.fromData(
            Uint8List.fromList(bytes),
            mimeType: ShareFileCodec.mimeType,
            name: ShareFileCodec.fileName,
          ),
        ],
        fileNameOverrides: const [ShareFileCodec.fileName],
        subject: 'XY加密文件分享',
        sharePositionOrigin:
            box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      );
    } on FormatException catch (error) {
      if (mounted) _message(error.message);
    } catch (error) {
      if (mounted) _message('分享文件失败：$error');
    }
  }

  Future<_ShareOptions?> _askShareOptions() async {
    var includeKey = false;
    final canIncludeKey = model.shareIsEncrypted && model.shareKey.isNotEmpty;
    return showDialog<_ShareOptions>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, refresh) => AlertDialog(
          title: const Text('分享设置'),
          content: CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: includeKey,
            title: const Text('在分享链接中包含密钥'),
            subtitle: Text(
              !model.shareIsEncrypted
                  ? '仅可逆加密结果支持携带密钥'
                  : model.shareKey.isEmpty
                      ? '当前结果没有可分享的密钥'
                      : '密钥会与密文一起发送，获得链接的人可读取密钥并解密',
            ),
            onChanged: canIncludeKey
                ? (value) => refresh(() => includeKey = value ?? false)
                : null,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                _ShareOptions(includeKey: includeKey),
              ),
              child: const Text('继续'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareSystem(Uri uri) async {
    final box = context.findRenderObject() as RenderBox?;
    try {
      await Share.share(
        ShareCodec.composeMessage(uri),
        subject: 'XY加密分享',
        sharePositionOrigin:
            box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      );
    } catch (error) {
      _message('分享失败，可使用复制链接：$error');
    }
  }

  Future<void> _copyShareLink(Uri uri) async {
    try {
      await Clipboard.setData(ClipboardData(text: uri.toString()));
      _message('分享链接已复制');
    } catch (error) {
      _message('复制链接失败：$error');
    }
  }

  Future<void> _showShareQr(Uri uri) async {
    try {
      final code = Encoder.encode(
        uri.toString(),
        ErrorCorrectionLevel.m,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => ShareQrDialog(
          code: code,
          link: uri.toString(),
          onCopy: () => _copyShareLink(uri),
        ),
      );
    } catch (error) {
      _message('二维码生成失败：$error');
    }
  }

  Future<void> _checkForUpdate() async {
    _message('正在检查更新…');
    final platform = Platform.isAndroid
        ? 'android'
        : Platform.isWindows
            ? 'windows'
            : Platform.isLinux
                ? 'linux'
                : '';
    final query = <String, String>{
      'channel': 'stable',
      'version': _appVersion,
      'build': _appBuild.toString(),
      if (platform.isNotEmpty) 'platform': platform,
    };
    final updateUri = Uri.parse('$_websiteBase/api/update').replace(
      queryParameters: query,
    );
    final client = HttpClient();
    try {
      final request = await client.getUrl(updateUri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != HttpStatus.ok) {
        throw const FormatException('更新服务暂时不可用');
      }
      final data = jsonDecode(body) as Map<String, dynamic>;
      if (!mounted) return;
      final available = data['available'] == true;
      final release = data['release'] as Map<String, dynamic>?;
      final version = release?['version']?.toString() ?? '';
      final assets = (release?['assets'] as List<dynamic>?) ?? const [];
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(available ? '发现新版本 $version' : '已是最新版本'),
          content: Text(
            available
                ? '检测到 $version，共有 ${assets.length} 个适配当前平台的安装包。打开网站查看下载。'
                : '当前版本 $_appVersion（$_appBuild）已经是最新版本。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('关闭'),
            ),
            if (available)
              FilledButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  await launchUrl(
                    Uri.parse('$_websiteBase/#downloads'),
                    mode: LaunchMode.externalApplication,
                  );
                },
                child: const Text('打开下载页'),
              ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) _message('更新检测失败：$error');
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _pasteShare() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim();
      if (text == null || text.isEmpty) {
        _message('剪贴板没有文本');
        return;
      }
      if (!await model.importText(text, allowPlainText: false)) {
        _message('剪贴板中没有有效的 XY 分享链接');
        return;
      }
      _message('剪贴板分享内容已导入');
    } on FormatException catch (error) {
      _message(error.message);
    } catch (error) {
      _message('读取剪贴板失败：$error');
    }
  }

  Future<void> _import() async {
    final editor = TextEditingController();
    final value = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('导入文本或分享链接'),
              content: TextField(controller: editor, maxLines: 5),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, editor.text),
                    child: const Text('导入'))
              ],
            ));
    Future<void>.delayed(const Duration(seconds: 1), editor.dispose);
    if (mounted && value != null) {
      try {
        await model.importText(value);
      } catch (error) {
        _message('$error');
      }
    }
  }

  void _menu(String action) {
    switch (action) {
      case 'import':
        _import();
      case 'pasteShare':
        _pasteShare();
      case 'update':
        _checkForUpdate();
      case 'agreement':
        _openLegalDocument(privacy: false);
      case 'privacy':
        _openLegalDocument(privacy: true);
      case 'privacyCenter':
        Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => PrivacyCenter(
                onClearKeys: _confirmClearKeys,
                onWithdraw: _confirmWithdrawConsent)));
      case 'clearKeys':
        _confirmClearKeys();
      case 'withdrawConsent':
        _confirmWithdrawConsent();
      case 'exit':
        if (Platform.isAndroid) {
          SystemNavigator.pop();
        } else {
          _message('请使用窗口关闭按钮退出');
        }
    }
  }

  Future<void> _openLegalDocument({required bool privacy}) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => LegalDocumentPage(privacy: privacy),
        ),
      );

  Future<void> _confirmClearKeys() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清除本机已保存密钥？'),
        content: const Text(
          '这会删除本应用保存的所有算法密钥，不影响当前输入框内容。此操作无法撤销。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await model.clearRememberedKeys();
      if (!mounted) return;
      _message('本机已保存密钥已清除');
    } catch (error) {
      _message('清除失败：$error');
    }
  }

  Future<void> _confirmWithdrawConsent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('撤回协议同意？'),
        content: const Text(
          '撤回后清空当前会话并退出应用，下次启动重新确认。已保存密钥请通过清除密钥入口单独删除。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('撤回并退出'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      Navigator.of(context).popUntil((route) => route.isFirst);
      await widget.onWithdrawConsent?.call();
    } catch (_) {
      _message('撤回尚未完成，请重试');
    }
  }
}
