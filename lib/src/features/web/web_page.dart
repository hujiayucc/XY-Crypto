import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/scan_picker.dart';

class WebPage extends StatefulWidget {
  const WebPage({super.key});
  @override
  State<WebPage> createState() => _WebPageState();
}
class _WebPageState extends State<WebPage> {
  final _address = TextEditingController();
  WebViewController? _web;
  int _progress = 100;
  String? _error;
  bool get _embedded => Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  @override
  void initState() {
    super.initState();
    if (_embedded) {
      _web = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(NavigationDelegate(
          onProgress: (value) { if (mounted) setState(() => _progress = value); },
          onPageStarted: (url) { if (mounted) setState(() { _address.text = url; _error = null; }); },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true && mounted) setState(() => _error = error.description);
          },
          onNavigationRequest: (request) {
            final scheme = Uri.tryParse(request.url)?.scheme;
            return scheme == 'http' || scheme == 'https' || request.url == 'about:blank'
                ? NavigationDecision.navigate : NavigationDecision.prevent;
          },
        ));
    }
  }
  @override
  void dispose() { _address.dispose(); super.dispose(); }
  void _message(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
  Uri? _uri(String text) {
    var value = text.trim();
    if (value.isEmpty) return null;
    if (!value.contains('://')) {
      value = value.contains('.') && !value.contains(' ')
        ? 'https://$value' : 'https://m.baidu.com/s?word=${Uri.encodeQueryComponent(value)}';
    }
    final uri = Uri.tryParse(value);
    if (uri == null || !['http', 'https'].contains(uri.scheme) || uri.host.isEmpty) {
      _message('请输入 HTTP 或 HTTPS 地址'); return null;
    }
    return uri;
  }
  Future<void> _load(String value) async {
    final uri = _uri(value);
    if (uri == null) return;
    _address.text = uri.toString();
    FocusScope.of(context).unfocus();
    try {
      if (_web != null) { await _web!.loadRequest(uri); }
      else if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) { _message('浏览器打开失败'); }
    } catch (error) { _message('页面打开失败：$error'); }
  }
  Future<void> _menu(String action) async {
    try {
      final value = await _web?.currentUrl() ?? _address.text;
      switch (action) {
        case 'copy': await Clipboard.setData(ClipboardData(text: value)); _message('链接已复制');
        case 'open':
          final uri = _uri(value);
          if (uri != null && !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
            _message('浏览器打开失败');
          }
        case 'clear':
          await _web?.clearCache(); await _web?.clearLocalStorage();
          _message('应用内网页缓存已清理');
      }
    } catch (error) { _message('$error'); }
  }
  Future<void> _scan() async {
    try {
      final text = await scanText(context);
      if (mounted && text != null) await _load(text);
    } catch (error) { _message('识别失败：$error'); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(titleSpacing: 0, title: TextField(controller: _address,
      textInputAction: TextInputAction.go, onSubmitted: _load,
      keyboardType: TextInputType.url,
      style: TextStyle(color: Theme.of(context).appBarTheme.foregroundColor),
      decoration: const InputDecoration(hintText: '输入网址或搜索内容',
        border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none)),
      actions: [
        IconButton(tooltip: '扫一扫', onPressed: _scan, icon: const Icon(Icons.qr_code_scanner)),
        PopupMenuButton<String>(onSelected: _menu, itemBuilder: (_) => [
          const PopupMenuItem(value: 'open', child: Text('用其他软件打开')),
          const PopupMenuItem(value: 'copy', child: Text('复制链接')),
          if (_web != null) const PopupMenuItem(value: 'clear', child: Text('清理缓存')),
        ]),
      ]),
    body: Column(children: [
      if (_progress < 100) LinearProgressIndicator(value: _progress / 100, minHeight: 2),
      if (_error != null) Padding(padding: const EdgeInsets.all(12), child: Text(_error!)),
      Expanded(child: _web != null ? WebViewWidget(controller: _web!) : const Center(
        child: Padding(padding: EdgeInsets.all(24),
          child: Text('输入网址后将在系统浏览器中打开。', textAlign: TextAlign.center)))),
    ]),
    bottomNavigationBar: SafeArea(child: ColoredBox(color: Theme.of(context).colorScheme.secondary,
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        IconButton(tooltip: '后退', onPressed: _web == null ? null : () async {
          if (await _web!.canGoBack()) await _web!.goBack(); }, icon: const Icon(Icons.arrow_back)),
        IconButton(tooltip: '前进', onPressed: _web == null ? null : () async {
          if (await _web!.canGoForward()) await _web!.goForward(); }, icon: const Icon(Icons.arrow_forward)),
        IconButton(tooltip: '刷新', onPressed: _web == null ? null : () => _web!.reload(),
            icon: const Icon(Icons.refresh)),
        IconButton(tooltip: '关闭', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
      ]))),
  );
}
