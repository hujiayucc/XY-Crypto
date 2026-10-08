import 'dart:async';
import 'dart:io';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'src/core/privacy_runtime.dart';
import 'src/core/app_theme.dart';
import 'src/core/incoming_share.dart';
import 'src/core/share_codec.dart';
import 'src/features/home/home_controller.dart';
import 'src/features/home/home_page.dart';
import 'src/features/legal/legal_consent.dart';
import 'src/features/splash/splash_page.dart';
import 'src/features/web/web_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }
  runApp(const XyApp());
}

class XyApp extends StatefulWidget {
  const XyApp({super.key, this.privacyRuntime});
  final PrivacyRuntime? privacyRuntime;
  @override
  State<XyApp> createState() => _XyAppState();
}

class _XyAppState extends State<XyApp> {
  static const _splashDuration = Duration(seconds: 2);
  final _controller = HomeController();
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  AppLinks? _links;
  late final PrivacyRuntime _privacy =
      widget.privacyRuntime ?? PrivacyRuntime();
  bool _servicesStarted = false;
  int _consentEpoch = 0;
  late final IncomingShareService _incomingShare;
  StreamSubscription<Uri>? _subscription;
  String? _lastImported;
  bool _showSplash = true;
  bool _legalAccepted = false;
  bool _checkingLegal = true;
  Timer? _splashTimer;

  @override
  void initState() {
    super.initState();
    _incomingShare = IncomingShareService(onText: _importText);
    _loadLegalConsent();
    _splashTimer = Timer(_splashDuration, () {
      if (!mounted) return;
      if (Platform.isAndroid || Platform.isIOS) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
      setState(() => _showSplash = false);
    });
  }

  Future<void> _loadLegalConsent() async {
    var accepted = await _privacy.hasConsent(legalConsentVersion);
    if (!mounted) return;
    if (accepted) {
      try {
        await _privacy.activate(legalConsentVersion);
      } catch (_) {
        accepted = false;
      }
    }
    if (!mounted) return;
    setState(() {
      _legalAccepted = accepted;
      _checkingLegal = false;
    });
    if (accepted) _startIncomingServices();
  }

  Future<void> _acceptLegal() async {
    await _privacy.accept(legalConsentVersion);
    await _privacy.activate(legalConsentVersion);
    if (!mounted) return;
    setState(() => _legalAccepted = true);
    _startIncomingServices();
  }

  Future<void> _withdrawLegalConsent() async {
    await _privacy.revoke();
    _legalAccepted = false;
    _consentEpoch++;
    await _subscription?.cancel();
    _subscription = null;
    _incomingShare.dispose();
    _servicesStarted = false;
    _lastImported = null;
    _controller.clearSessionData();
    if (!mounted) return;
    _messenger.currentState?.clearSnackBars();
    setState(() {});
    if (_privacy.android) await _privacy.exitApp();
  }

  void _startIncomingServices() {
    if (!_legalAccepted || _servicesStarted) return;
    _servicesStarted = true;
    if (_privacy.android) {
      unawaited(_incomingShare.start());
    } else {
      _links ??= AppLinks();
      _subscription = _links!.uriLinkStream.listen(
        _importLink,
        onError: (Object error) => _message('链接导入暂未就绪'),
      );
      unawaited(_initialLink());
    }
  }

  Future<void> _initialLink() async {
    final epoch = _consentEpoch;
    try {
      final uri = await _links?.getInitialLink();
      if (mounted && _legalAccepted && epoch == _consentEpoch && uri != null) {
        await _importLink(uri);
      }
    } catch (_) {
      if (_legalAccepted) _message('链接监听未就绪');
    }
  }

  void _message(String text) =>
      _messenger.currentState?.showSnackBar(SnackBar(content: Text(text)));
  Future<void> _importLink(Uri uri) => _importText(uri.toString());

  Future<void> _importText(String text) async {
    if (!mounted || !_legalAccepted) return;
    final epoch = _consentEpoch;
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed == _lastImported) return;
    try {
      final link = ShareCodec.findShareLink(trimmed);
      final imported = await _controller.importText(
        link ?? trimmed,
        allowPlainText: link == null,
      );
      if (!mounted || !_legalAccepted || epoch != _consentEpoch) return;
      if (!imported) {
        _message('未识别到有效的 XY 分享链接');
        return;
      }
      _lastImported = trimmed;
      _message(link == null ? '已导入分享文本' : '分享内容已导入');
    } on FormatException catch (error) {
      _message(error.message);
    }
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    _subscription?.cancel();
    _incomingShare.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'XY加密',
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: _messenger,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
        home: _checkingLegal
            ? const SplashPage()
            : !_legalAccepted
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      const SplashPage(),
                      ModalBarrier(
                        dismissible: false,
                        color: Colors.black26,
                      ),
                      Center(
                        child: LegalConsentDialog(
                          onAccept: _acceptLegal,
                          onDecline: () {
                            if (_privacy.android) {
                              unawaited(_privacy.exitApp());
                            } else {
                              _message('未同意时请关闭应用停止使用');
                            }
                          },
                        ),
                      ),
                    ],
                  )
                : _showSplash
                    ? const SplashPage()
                    : HomePage(
                        controller: _controller,
                        onWithdrawConsent: _withdrawLegalConsent,
                      ),
        routes: {
          '/web': (_) => _legalAccepted ? const WebPage() : const SplashPage()
        },
      );
}
