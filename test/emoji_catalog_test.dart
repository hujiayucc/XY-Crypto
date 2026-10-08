import 'package:flutter_test/flutter_test.dart';
import 'package:xy_encrypt_app/src/features/home/emoji_catalog.dart';

void main() {
  test('keeps the 132 native Emoji entries in original order', () {
    expect(originalEmojiCatalog, hasLength(132));
    expect(originalEmojiCatalog.first.codePoint, 0x1f603);
    expect(originalEmojiCatalog[1].codePoint, 0x1f600);
    expect(originalEmojiCatalog.last.codePoint, 0x1f30f);
    expect(
      originalEmojiCatalog.any((entry) => entry.codePoint >= 0x30d40),
      isFalse,
    );
    expect(
      originalEmojiCatalog.map((entry) => entry.asset).toSet(),
      hasLength(132),
    );
  });
}