import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xy_encrypt_app/src/core/app_theme.dart';
import 'package:xy_encrypt_app/src/core/crypto_engine.dart';
import 'package:xy_encrypt_app/src/features/home/home_controller.dart';
import 'package:xy_encrypt_app/src/features/home/home_page.dart';

void main() {
  for (final width in [320.0, 390.0, 900.0, 1280.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('width=$width textScale=$scale keyboard open',
          (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final model = HomeController()..setMode(CryptoMode.md5Upper32);
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              viewInsets: const EdgeInsets.only(bottom: 280),
            ),
            child: child!,
          ),
          home: HomePage(controller: model),
        ));
        expect(tester.takeException(), isNull);
        expect(find.text('生成摘要'), findsOneWidget);
        expect(find.text('解密'), findsNothing);
        expect(find.text('无需密钥'), findsNothing);
        expect(find.byKey(const ValueKey('key-state')), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
      });
    }
  }

  testWidgets('Narrow screen keeps text file import action visible',
      (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final model = HomeController();
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: HomePage(controller: model)),
    );

    expect(find.text('导入文本文件'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });

  testWidgets('Landscape places input and output editors side by side',
      (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final model = HomeController();
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: HomePage(controller: model)),
    );

    final fields = find.byType(TextField);
    final input = tester.getRect(fields.at(0));
    final output = tester.getRect(fields.at(1));
    expect(output.left, greaterThan(input.right));
    expect(output.top, closeTo(input.top, 1));
    final inputEditor = tester.getRect(
      find.byKey(const ValueKey('editor-input')),
    );
    final outputEditor = tester.getRect(
      find.byKey(const ValueKey('editor-output')),
    );
    final emoji = tester.getRect(find.byTooltip('表情'));
    final clearOutput = tester.getRect(find.byTooltip('清空结果'));
    expect(emoji.left, greaterThanOrEqualTo(inputEditor.left));
    expect(emoji.bottom, lessThanOrEqualTo(inputEditor.bottom));
    expect(clearOutput.right, lessThanOrEqualTo(outputEditor.right));
    expect(clearOutput.bottom, lessThanOrEqualTo(outputEditor.bottom));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });
}
