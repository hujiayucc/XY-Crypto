import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xy_encrypt_app/src/features/legal/legal_consent.dart';

void main() {
  testWidgets('Consent stays disabled until documents are acknowledged',
      (tester) async {
    var accepted = false;
    var declined = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: LegalConsentDialog(
              onAccept: () async => accepted = true,
              onDecline: () => declined = true,
            ),
          ),
        ),
      ),
    ));

    final acceptButton = find.widgetWithText(FilledButton, '同意并继续');
    expect(tester.widget<FilledButton>(acceptButton).onPressed, isNull);
    expect(find.byType(OutlinedButton), findsNothing);
    final consentTile = tester.widget<CheckboxListTile>(
      find.byType(CheckboxListTile),
    );
    expect(consentTile.checkboxShape, const CircleBorder());
    final consentTheme = tester.widget<Theme>(
      find.byKey(const ValueKey('consent-choice-theme')),
    );
    expect(consentTheme.data.splashFactory, NoSplash.splashFactory);
    expect(consentTheme.data.highlightColor, Colors.transparent);
    expect(
      consentTheme.data.checkboxTheme.overlayColor?.resolve({}),
      Colors.transparent,
    );
    expect(find.byIcon(Icons.lock_outline), findsNothing);
    expect(LegalDocument.agreement.htmlFile,
        'build_artifacts/legal_site/user_agreement_zh.html');
    expect(LegalDocument.privacy.htmlFile,
        'build_artifacts/legal_site/privacy_policy_zh.html');
    expect(LegalDocument.collection.htmlFile, isNull);
    final legalText = find.textContaining('《用户协议》', findRichText: true);
    expect(legalText, findsOneWidget);
    final legalRender = tester.renderObject<RenderParagraph>(legalText);
    final legalOffset = legalRender.getOffsetForCaret(
      TextPosition(offset: legalRender.text.toPlainText().indexOf('《')),
      Rect.zero,
    );
    await tester
        .tapAt(tester.getTopLeft(legalText) + legalOffset + const Offset(4, 8));
    await tester.pumpAndSettle();
    expect(find.text('XY加密用户协议'), findsOneWidget);
    expect(find.textContaining('胡佳宇'), findsWidgets);
    expect(find.textContaining('hujiayucc@qq.com'), findsWidgets);
    expect(find.textContaining('2022/10/25'), findsWidgets);
    expect(find.textContaining('联系地址'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    final privacyText = find.textContaining('《隐私政策》', findRichText: true);
    expect(privacyText, findsOneWidget);
    final privacyRender = tester.renderObject<RenderParagraph>(privacyText);
    final privacyOffset = privacyRender.getOffsetForCaret(
      TextPosition(
        offset: privacyRender.text.toPlainText().indexOf('《隐私政策》'),
      ),
      Rect.zero,
    );
    await tester.tapAt(
      tester.getTopLeft(privacyText) + privacyOffset + const Offset(4, 8),
    );
    await tester.pumpAndSettle();
    expect(find.text('XY加密隐私政策'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('3. 本地处理与密钥安全存储'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('3. 本地处理与密钥安全存储'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('我已阅读并同意以上内容'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(acceptButton).onPressed, isNotNull);
    await tester.tap(acceptButton);
    await tester.pumpAndSettle();
    expect(accepted, isTrue);
    expect(declined, isFalse);
  });

  testWidgets('Declining consent invokes the exit callback', (tester) async {
    var declined = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: LegalConsentDialog(
            onAccept: () async {},
            onDecline: () => declined = true,
          ),
        ),
      ),
    ));

    await tester.tap(find.text('退出应用'));
    expect(declined, isTrue);
  });
}
