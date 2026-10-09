import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xy_crypto/xy_crypto.dart';
import 'package:xy_encrypt_app/main.dart';
import 'package:xy_encrypt_app/src/core/privacy_runtime.dart';
import 'package:xy_encrypt_app/src/features/home/home_page.dart';

class TestPrivacy extends PrivacyRuntime {
  TestPrivacy({required this.accepted, super.android});
  bool accepted;
  @override
  Future<bool> hasConsent(String version) async => accepted;
  @override
  Future<void> activate(String version) async {}
  @override
  Future<void> accept(String version) async => accepted = true;
  @override
  Future<void> revoke() async => accepted = false;
  @override
  Future<void> exitApp() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const native = MethodChannel('com.hujiayucc.decode/share');
  const events = MethodChannel('com.llfbandit.app_links/events');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const codec = StandardMethodCodec();
  var initialCalls = 0;
  String? initial;

  Future<void> emitNative(String text) async {
    final result = Completer<void>();
    messenger.handlePlatformMessage(
        native.name,
        codec.encodeMethodCall(MethodCall('sharedText', text)),
        (_) => result.complete());
    await result.future;
  }

  Future<void> emitLink(String text) async {
    final result = Completer<void>();
    messenger.handlePlatformMessage(events.name,
        codec.encodeSuccessEnvelope(text), (_) => result.complete());
    await result.future;
  }

  HomePage home(WidgetTester tester) =>
      tester.widget<HomePage>(find.byType(HomePage));
  String link(String text) =>
      ShareCodec.encode(CryptoMode.hex, text).toString();

  setUp(() {
    initialCalls = 0;
    initial = null;
    messenger.setMockMethodCallHandler(native, (call) async {
      if (call.method == 'getInitialSharedText') {
        initialCalls++;
        return initial;
      }
      return null;
    });
    messenger.setMockMethodCallHandler(events, (_) async => null);
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(native, null);
    messenger.setMockMethodCallHandler(events, null);
  });

  testWidgets('Android cold link opens home without clipboard or splash delay',
      (tester) async {
    initial = link('冷启动内容 + & 中文');
    await tester.pumpWidget(
        XyApp(privacyRuntime: TestPrivacy(accepted: true, android: true)));
    await tester.pumpAndSettle();
    expect(home(tester).controller.input, '冷启动内容 + & 中文');
    expect(home(tester).controller.mode, CryptoMode.hex);
    expect(initialCalls, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'warm link returns to home and the same URI can be imported again',
      (tester) async {
    initial = link('first');
    await tester.pumpWidget(
        XyApp(privacyRuntime: TestPrivacy(accepted: true, android: true)));
    await tester.pumpAndSettle();
    final model = home(tester).controller;
    Navigator.of(tester.element(find.byType(HomePage))).push(
        MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('another page'))));
    await tester.pumpAndSettle();
    await emitNative(link('second'));
    await tester.pumpAndSettle();
    expect(find.text('another page'), findsNothing);
    expect(model.input, 'second');
    model.clearInput();
    await emitNative(link('second'));
    await tester.pumpAndSettle();
    expect(model.input, 'second');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Android defers cold link until consent is explicitly accepted',
      (tester) async {
    initial = link('pending');
    await tester.pumpWidget(
        XyApp(privacyRuntime: TestPrivacy(accepted: false, android: true)));
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(HomePage), findsNothing);
    expect(initialCalls, 0);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '同意并继续'));
    await tester.pumpAndSettle();
    expect(home(tester).controller.input, 'pending');
    expect(initialCalls, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('malformed URI leaves existing editor intact and next link works',
      (tester) async {
    initial = link('keep');
    await tester.pumpWidget(
        XyApp(privacyRuntime: TestPrivacy(accepted: true, android: true)));
    await tester.pumpAndSettle();
    for (final invalid in [
      'xyd://other?type=0&text=bad',
      'xyd://share?type=9999&text=bad',
      'xyd://share?type=0'
    ]) {
      await emitNative(invalid);
      await tester.pumpAndSettle();
      expect(home(tester).controller.input, 'keep');
    }
    await emitNative(link('valid'));
    await tester.pumpAndSettle();
    expect(home(tester).controller.input, 'valid');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'desktop and Apple event stream buffers newest URI before consent',
      (tester) async {
    await tester.pumpWidget(
        XyApp(privacyRuntime: TestPrivacy(accepted: false, android: false)));
    await tester.pump();
    await emitLink(link('older'));
    await emitLink(link('newest'));
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(HomePage), findsNothing);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '同意并继续'));
    await tester.pumpAndSettle();
    final model = home(tester).controller;
    expect(model.input, 'newest');
    await emitLink('https://unrelated.example/');
    await tester.pumpAndSettle();
    expect(model.input, 'newest');
    await emitLink(link('warm'));
    await tester.pumpAndSettle();
    expect(model.input, 'warm');
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
  testWidgets('invalid cold link reports error after splash and permits retry',
      (tester) async {
    initial = 'xyd://share?type=9999&text=bad';
    await tester.pumpWidget(
        XyApp(privacyRuntime: TestPrivacy(accepted: true, android: true)));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(home(tester).controller.input, isEmpty);
    await emitNative(link('retry'));
    await tester.pumpAndSettle();
    expect(home(tester).controller.input, 'retry');
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'invalid pending link after consent does not poison later imports',
      (tester) async {
    initial = 'xyd://share?type=9999&text=bad';
    await tester.pumpWidget(
        XyApp(privacyRuntime: TestPrivacy(accepted: false, android: true)));
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '同意并继续'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(home(tester).controller.input, isEmpty);
    await emitNative(link('after consent'));
    await tester.pumpAndSettle();
    expect(home(tester).controller.input, 'after consent');
    await tester.pumpWidget(const SizedBox());
  });
}
