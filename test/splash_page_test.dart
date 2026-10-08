import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xy_encrypt_app/src/features/splash/splash_page.dart';

void main() {
  testWidgets('matches the original splash content', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashPage()));

    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.text('XY加密'), findsOneWidget);
    expect(
      find.textContaining('备案号: 蜀ICP备2021022209号'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
