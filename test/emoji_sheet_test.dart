import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xy_encrypt_app/src/features/home/emoji_catalog.dart';
import 'package:xy_encrypt_app/src/features/home/emoji_sheet.dart';

void main() {
  testWidgets('shows all native Emoji in one vertically scrollable category',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OriginalEmojiSheet(entries: originalEmojiCatalog),
        ),
      ),
    );

    expect(find.text('原生 Emoji'), findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.byType(PageView), findsOneWidget);
    expect(find.byType(GridView), findsOneWidget);
    expect(find.byType(Image), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(GridView), const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('supports horizontal category switching for future packs',
      (tester) async {
    final categories = [
      EmojiCategory(label: '原生 Emoji', items: originalEmojiCatalog),
      EmojiCategory(label: 'QQ', items: originalEmojiCatalog.take(1).toList()),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OriginalEmojiSheet(
            entries: originalEmojiCatalog,
            categories: categories,
          ),
        ),
      ),
    );

    expect(find.byType(ChoiceChip), findsNothing);
    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const PageStorageKey<String>('QQ')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('centers category indicators independently of delete button',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OriginalEmojiSheet(entries: originalEmojiCatalog),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dots = find.byType(AnimatedContainer);
    expect(dots, findsNWidgets(4));
    final first = tester.getCenter(dots.at(0));
    final last = tester.getCenter(dots.at(3));
    final panelFinder = find.byType(OriginalEmojiSheet);
    final panelRect = tester.getRect(panelFinder);
    expect((first.dx + last.dx) / 2, closeTo(panelRect.center.dx, 0.1));

    final deleteCenter = tester.getCenter(find.byTooltip('删除'));
    expect(deleteCenter.dx, closeTo(panelRect.right - 24, 0.1));
    expect(tester.takeException(), isNull);
  });
}
