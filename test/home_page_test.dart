import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xy_encrypt_app/src/core/app_theme.dart';
import 'package:xy_encrypt_app/src/core/crypto_engine.dart';
import 'package:xy_encrypt_app/src/core/share_codec.dart';

import 'package:xy_encrypt_app/src/features/home/emoji_catalog.dart';
import 'package:xy_encrypt_app/src/features/home/emoji_sheet.dart';
import 'package:xy_encrypt_app/src/features/home/home_controller.dart';
import 'package:xy_encrypt_app/src/features/home/home_page.dart';
import 'package:xy_encrypt_app/src/features/home/key_input_sheet.dart';

void main() {
  test('One-way operation reports the selected algorithm', () async {
    final model = HomeController();
    model.setMode(CryptoMode.sha256Hex);
    model.input = 'abc';

    await model.run(encode: false);

    expect(model.error, 'SHA-256 是单向摘要，仅支持生成摘要');
    expect(model.error, isNot(contains('MD5')));
    model.dispose();
  });

  testWidgets('Saved key is reused for encryption without opening the dialog',
      (tester) async {
    final model = HomeController(
      keyReader: (_) async => 'saved password',
    )..setMode(CryptoMode.aesGcmHex);
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: HomePage(controller: model)),
    );

    await tester.enterText(find.byType(TextField).first, 'saved key text');
    await tester.tap(find.text('加密'));
    await tester.runAsync(() async {
      for (var i = 0; i < 100; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (!model.busy) break;
      }
    });
    await tester.pump();
    expect(model.busy, isFalse);
    expect(find.byType(KeyInputSheet), findsNothing);
    expect(model.output, isNotEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });

  testWidgets('Key state always opens the key dialog', (tester) async {
    final model = HomeController(
      keyReader: (_) async => 'saved password',
    )..setMode(CryptoMode.aesGcmHex);
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: HomePage(controller: model)),
    );

    expect(find.byKey(const ValueKey('key-state')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('key-state')));
    await tester.pumpAndSettle();
    expect(find.byType(KeyInputSheet), findsOneWidget);
    expect(find.text('取消').last, findsOneWidget);
    await tester.tap(find.text('取消').last);
    await tester.pumpAndSettle();
    expect(find.byType(KeyInputSheet), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });

  test(
      'Encrypted share import keeps ciphertext in input and plaintext in output',
      () async {
    const plain = 'share plaintext';
    const key = 'share password';
    final cipher = CryptoEngine.transform(
      input: plain,
      mode: CryptoMode.aesGcmHex,
      encode: true,
      key: key,
    );
    final link = ShareCodec.encode(
      CryptoMode.aesGcmHex,
      cipher,
      operation: ShareCodec.encryptOperation,
      key: key,
    );
    final model = HomeController();

    expect(await model.importText(link.toString()), isTrue);
    expect(model.input, cipher);
    expect(model.output, plain);
    expect(model.shareText, cipher);
    expect(model.shareKey, key);
    expect(model.shareIsEncrypted, isTrue);
    expect(model.statusMessage, '密文已导入并完成解密');
    model.dispose();
  });

  test('Encrypted share without a key keeps ciphertext for later decryption',
      () async {
    const cipher = 'A1B2C3';
    final link = ShareCodec.encode(
      CryptoMode.aesGcmHex,
      cipher,
      operation: ShareCodec.encryptOperation,
    );
    final model = HomeController();

    expect(await model.importText(link.toString()), isTrue);
    expect(model.input, cipher);
    expect(model.output, isEmpty);
    expect(model.shareText, cipher);
    expect(model.shareIsEncrypted, isTrue);
    expect(model.statusMessage, '密文已导入，请输入密钥后解密');
    model.dispose();
  });

  testWidgets('Clear operation synchronizes model and editor', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final model = HomeController();
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(), home: HomePage(controller: model)));
    await tester.enterText(find.byType(TextField).first, 'test');
    expect(model.input, 'test');
    model.clearInput();
    await tester.pump();
    expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        isEmpty);
    model.setMode(CryptoMode.md5Upper32);
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });
  testWidgets('Emoji panel stays open and does not dim the page',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final model = HomeController();
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(), home: HomePage(controller: model)));

    await tester.tap(find.byTooltip('表情'));
    await tester.pumpAndSettle();
    expect(find.byType(OriginalEmojiSheet), findsOneWidget);
    final barriers = tester.widgetList<ModalBarrier>(find.byType(ModalBarrier));
    expect(barriers, isNotEmpty);
    expect(
      barriers.every(
        (barrier) => barrier.color == null || barrier.color!.a == 0,
      ),
      isTrue,
    );

    await tester.tap(
      find
          .descendant(
            of: find.byType(OriginalEmojiSheet),
            matching: find.byType(Image),
          )
          .first,
    );
    await tester.pump();
    expect(
        model.input, String.fromCharCode(originalEmojiCatalog.first.codePoint));
    expect(find.byType(OriginalEmojiSheet), findsOneWidget);
    expect(
      tester.widgetList<ModalBarrier>(find.byType(ModalBarrier)).every(
            (barrier) => barrier.color == null || barrier.color!.a == 0,
          ),
      isTrue,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });

  testWidgets('Top-right menu groups related actions into submenus',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final model = HomeController();
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: HomePage(controller: model)),
    );

    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    expect(find.text('网页'), findsNothing);
    expect(find.text('导入'), findsOneWidget);
    expect(find.text('隐私与协议'), findsNothing);
    expect(find.text('更新检测'), findsOneWidget);
    expect(find.text('隐私中心'), findsOneWidget);
    expect(find.text('导入文本或分享链接'), findsNothing);
    expect(find.text('用户协议'), findsNothing);
    expect(find.text('退出'), findsOneWidget);

    await tester.tap(find.text('导入'));
    await tester.pumpAndSettle();
    expect(find.text('导入文本或分享链接'), findsOneWidget);
    expect(find.text('从剪贴板导入分享链接'), findsOneWidget);

    await tester.tapAt(const Offset(20, 400));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    expect(find.text('隐私中心'), findsOneWidget);
    expect(find.text('清除本机已保存密钥'), findsNothing);
    expect(find.text('撤回协议同意'), findsNothing);

    await tester.tap(find.text('隐私中心'));
    await tester.pumpAndSettle();
    expect(find.text('隐私政策'), findsOneWidget);
    expect(find.text('用户协议'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });

  testWidgets('Algorithm and encoding are separate controls', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final model = HomeController();
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: HomePage(controller: model)),
    );

    expect(find.text('算法：'), findsOneWidget);
    expect(find.text('编码方式：'), findsOneWidget);
    expect(find.text('编码转换'), findsOneWidget);
    expect(find.text('HEX'), findsOneWidget);

    await tester.tap(find.text('编码转换').first);
    await tester.pumpAndSettle();
    expect(find.text('请选择算法'), findsOneWidget);
    expect(find.text('DES'), findsOneWidget);
    expect(find.text('BASE64'), findsNothing);
    expect(find.text('DES (BASE64)'), findsNothing);

    await tester.tap(find.text('DES'));
    await tester.pumpAndSettle();
    expect(model.mode, CryptoMode.desHex);
    expect(find.text('请选择算法'), findsNothing);
    expect(find.text('DES · 请选择编码方式'), findsNothing);

    await tester.tap(find.text('编码方式：'));
    await tester.pumpAndSettle();
    expect(find.text('DES · 请选择编码方式'), findsOneWidget);
    expect(find.text('BASE64'), findsOneWidget);
    expect(find.text('HEX'), findsNWidgets(2));
    expect(find.text('Byte[ ] (UTF-8)'), findsOneWidget);
    expect(find.text('AES-256-GCM (BASE64)'), findsNothing);

    await tester.tap(find.text('BASE64'));
    await tester.pumpAndSettle();
    expect(model.mode, CryptoMode.desBase64);
    expect(find.text('编码方式：'), findsOneWidget);
    expect(find.text('BASE64'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });

  testWidgets('Modern algorithms expose separate encoding choices',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final model = HomeController();
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: HomePage(controller: model)),
    );

    await tester.tap(find.text('编码转换').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('AES-256-GCM'));
    await tester.pumpAndSettle();

    expect(model.mode, CryptoMode.aesGcmHex);
    expect(find.text('请选择算法'), findsNothing);
    expect(find.text('AES-256-GCM'), findsOneWidget);
    expect(find.text('编码方式：'), findsOneWidget);
    expect(find.text('HEX'), findsOneWidget);

    await tester.tap(find.text('编码方式：'));
    await tester.pumpAndSettle();
    expect(find.text('AES-256-GCM · 请选择编码方式'), findsOneWidget);
    expect(find.text('HEX'), findsNWidgets(2));
    expect(find.text('Byte[ ] (UTF-8)'), findsOneWidget);
    await tester.tap(find.text('HEX').last);
    await tester.pumpAndSettle();
    expect(model.mode, CryptoMode.aesGcmHex);

    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });

  testWidgets('Choice arrows align to the right edge and center',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final model = HomeController();
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: HomePage(controller: model)),
    );

    for (final label in ['算法', '编码方式']) {
      final boxFinder = find.byKey(ValueKey('choice-$label'));
      final arrowFinder = find.descendant(
        of: boxFinder,
        matching: find.byIcon(Icons.arrow_drop_down),
      );
      final box = tester.getRect(boxFinder);
      final arrow = tester.getRect(arrowFinder);
      expect(arrow.right, closeTo(box.right - 2, 1));
      expect(arrow.center.dy, closeTo(box.center.dy, 1));
    }

    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });

  testWidgets('One-way algorithms show a single generate action',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final model = HomeController();
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: HomePage(controller: model)),
    );

    const cases = <({CryptoMode mode, String action})>[
      (mode: CryptoMode.sha256Hex, action: '生成摘要'),
      (mode: CryptoMode.hmacSha256Hex, action: '生成 HMAC'),
      (mode: CryptoMode.pbkdf2Hex, action: '生成派生结果'),
      (mode: CryptoMode.ecdsaSignHex, action: '生成签名'),
    ];
    for (final testCase in cases) {
      model.setMode(testCase.mode);
      await tester.pump();
      expect(find.text(testCase.action), findsOneWidget,
          reason: testCase.mode.label);
      expect(find.text('解密'), findsNothing, reason: testCase.mode.label);
      expect(find.text('加密'), findsNothing, reason: testCase.mode.label);
    }

    model.setMode(CryptoMode.aesGcmHex);
    await tester.pump();
    expect(find.text('加密'), findsOneWidget);
    expect(find.text('解密'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });

  testWidgets('Output labels its source and marks stale results',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final model = HomeController();
    model.setMode(CryptoMode.sha256Hex);
    model.input = 'abc';
    await tester.runAsync(() => model.run(encode: true));
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: HomePage(controller: model)),
    );
    await tester.pump();

    expect(find.text('SHA-256 · HEX'), findsOneWidget);

    model.setMode(CryptoMode.sha512Hex);
    await tester.pump();
    expect(find.text('SHA-256 · HEX'), findsOneWidget);
    expect(find.text('当前算法已变化，结果仍来自上一次操作'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });

  testWidgets('Key sheet fills a random key from the bottom left',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              key: const ValueKey('open-key-sheet'),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const KeyInputSheet(
                  mode: CryptoMode.desHex,
                  initialValue: '',
                ),
              ),
              child: const Text('打开密钥弹窗'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open-key-sheet')));
    await tester.pumpAndSettle();
    expect(find.byType(KeyInputSheet), findsOneWidget);
    expect(find.text('请输入DES秘钥'), findsOneWidget);
    final keyField = find.byKey(const ValueKey('key-field'));
    expect(
      tester.widget<TextField>(keyField).obscureText,
      isTrue,
    );
    final visibilityButton =
        find.byKey(const ValueKey('toggle-key-visibility'));
    expect(visibilityButton, findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    await tester.tap(visibilityButton);
    await tester.pump();
    expect(tester.widget<TextField>(keyField).obscureText, isFalse);
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    await tester.tap(visibilityButton);
    await tester.pump();
    expect(tester.widget<TextField>(keyField).obscureText, isTrue);
    final button = find.byKey(const ValueKey('random-key-button'));
    expect(button, findsOneWidget);
    final dialog = find.byType(AlertDialog);
    expect(
      tester.getCenter(button).dy,
      greaterThan(tester.getTopLeft(dialog).dy),
    );

    await tester.tap(button);
    await tester.pump();
    final generated = tester
        .widget<TextField>(find.byKey(const ValueKey('key-field')))
        .controller!
        .text;
    expect(generated.length, 8, reason: generated);

    await tester.tap(find.text('确定').last);
    await tester.pumpAndSettle();
    expect(find.byType(KeyInputSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Desktop places the operation bar between editors',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final model = HomeController()..setMode(CryptoMode.aesGcmHex);
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark(), home: HomePage(controller: model)),
    );

    final input = tester.getRect(find.byKey(const ValueKey('editor-input')));
    final output = tester.getRect(find.byKey(const ValueKey('editor-output')));
    final action = tester.getRect(find.text('加密'));
    expect(output.left, greaterThan(action.right));
    expect(action.left, greaterThan(input.right));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });

  testWidgets('Wide desktop has no layout exception', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final model = HomeController();
    await tester.pumpWidget(
        MaterialApp(theme: AppTheme.dark(), home: HomePage(controller: model)));
    expect(find.byType(TextField), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });
}
