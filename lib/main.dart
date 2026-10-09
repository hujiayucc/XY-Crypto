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
  final _navigator = GlobalKey<NavigatorState>();
  AppLinks? _links;
  late final PrivacyRuntime _privacy =
      widget.privacyRuntime ?? PrivacyRuntime();
  bool _servicesStarted = false;
  int _consentEpoch = 0;
  late final IncomingShareService _incomingShare;
  StreamSubscription<String>? _subscription;
  Future<void> _importQueue = Future<void>.value();
  String? _pendingExternalLink;
  String? _pendingMessage;
  bool _showSplash = true;
  bool _legalAccepted = false;
  bool _checkingLegal = true;
  Timer? _splashTimer;

  @override
  void initState() {
    super.initState();
    _incomingShare = IncomingShareService(onText: _importText);
    if (!_privacy.android) {
      // Keep raw OS events in memory until consent; parse/import them afterwards.
      _listenExternalLinks();
    }
    _loadLegalConsent();
    _splashTimer = Timer(_splashDuration, () {
      if (!mounted) return;
      if (Platform.isAndroid || Platform.isIOS) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
      setState(() => _showSplash = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _legalAccepted && _pendingMessage != null) {
          final message = _pendingMessage!;
          _pendingMessage = null;
          _message(message);
        }
      });
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
    _legalAccepted = false;
    _consentEpoch++;
    await _privacy.revoke();
    _pendingExternalLink = null;
    _pendingMessage = null;
    await _incomingShare.stop();
    _servicesStarted = false;
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
      return;
    }
    final pending = _pendingExternalLink;
    _pendingExternalLink = null;
    if (pending != null) unawaited(_importExternalLink(pending));
  }

  void _listenExternalLinks() {
    _links ??= AppLinks();
    // The stream supplies both the initial link and subsequent activations.
    // Calling getInitialLink as well can replay an old URI over a newer one.
    _subscription = _links!.stringLinkStream.listen(
      (raw) {
        if (!_legalAccepted) {
          _pendingExternalLink = raw;
        } else {
          unawaited(_importExternalLink(raw));
        }
      },
      onError: (Object error) {
        if (mounted && _legalAccepted) _message('链接监听未就绪');
      },
    );
  }

  void _message(String text) {
    // Always wait for the current navigation/consent frame to install its Scaffold.
    _pendingMessage = text;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _checkingLegal || !_legalAccepted || _showSplash) return;
      final pending = _pendingMessage;
      _pendingMessage = null;
      if (pending != null) {
        _messenger.currentState?.showSnackBar(SnackBar(content: Text(pending)));
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _importExternalLink(String text) =>
      _enqueueImport(text, uriOnly: true);

  Future<void> _importText(String text) => _enqueueImport(text,
      uriOnly: text.trim().toLowerCase().startsWith('xyd:'));

  Future<void> _enqueueImport(String text, {required bool uriOnly}) {
    final epoch = _consentEpoch;
    _importQueue = _importQueue.then((_) async {
      if (!mounted || !_legalAccepted || epoch != _consentEpoch) return;
      await _applyIncoming(text, uriOnly: uriOnly);
    });
    return _importQueue;
  }

  Future<void> _applyIncoming(String text, {required bool uriOnly}) async {
    if (!mounted || !_legalAccepted) return;
    final epoch = _consentEpoch;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    try {
      final link = ShareCodec.findShareLink(trimmed);
      if (uriOnly && !ShareCodec.isShareLink(trimmed)) {
        _message('未识别到有效的 XY 分享链接');
        return;
      }
      // Validate before dismissing the current route or changing the editor.
      if (link != null) ShareCodec.decode(link);
      _navigator.currentState?.popUntil((route) => route.isFirst);
      final imported = await _controller.importText(
        link ?? trimmed,
        allowPlainText: !uriOnly && link == null,
      );
      if (!mounted || !_legalAccepted || epoch != _consentEpoch) return;
      if (!imported) {
        _message('未识别到有效的 XY 分享链接');
        return;
      }
      _splashTimer?.cancel();
      if (_showSplash) {
        if (Platform.isAndroid || Platform.isIOS) {
          unawaited(
              SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
        }
        setState(() => _showSplash = false);
      }
      _navigator.currentState?.popUntil((route) => route.isFirst);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _legalAccepted && epoch == _consentEpoch) {
          _message(_controller.statusMessage ??
              (link == null ? '已导入分享文本' : '分享内容已导入'));
        }
      });
    } on FormatException catch (error) {
      if (mounted && _legalAccepted && epoch == _consentEpoch) {
        _message(error.message);
      }
    } catch (_) {
      if (mounted && _legalAccepted && epoch == _consentEpoch) {
        _message('分享导入失败，请重试');
      }
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
        navigatorKey: _navigator,
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
