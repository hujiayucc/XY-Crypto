import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xy_encrypt_app/src/features/home/emoji_text_editing_controller.dart';

void main() {
  testWidgets('renders original EmojiBoard code points as image spans',
      (tester) async {
    final controller = EmojiTextEditingController(text: 'A😀B');
    TextSpan? span;

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) {
          span = controller.buildTextSpan(
            context: context,
            style: const TextStyle(fontSize: 16),
            withComposing: false,
          );
          return const SizedBox.shrink();
        },
      ),
    ));

    expect(controller.text, 'A😀B');
    expect(span, isNotNull);
    expect(span!.children!.whereType<WidgetSpan>(), hasLength(1));
    controller.dispose();
  });

  testWidgets('attaches Emoji images to a real TextField', (tester) async {
    final controller = EmojiTextEditingController(
      text: 'A😀B',
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TextField(controller: controller, maxLines: 3),
      ),
    ));

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}