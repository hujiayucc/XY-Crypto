import 'package:flutter/material.dart';

import 'emoji_catalog.dart';
import 'smiley_catalog.dart';

/// TextEditingController that paints the original XY EmojiBoard images inline.
/// The underlying value remains the original Unicode text, so crypto and copy
/// operations continue to use the same code points as the APK.
class EmojiTextEditingController extends TextEditingController {
  EmojiTextEditingController({super.text})
      : _assets = {
          for (final emoji in originalEmojiCatalog) emoji.codePoint: emoji.asset,
        };

  final Map<int, String> _assets;
  static final Map<String, String> _smileyAssets = {
    for (final smiley in allSmileyCatalog) smiley.insertionText: smiley.asset,
  };

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final valueText = text;
    if (valueText.isEmpty) return TextSpan(style: style);

    final children = <InlineSpan>[];
    final plain = StringBuffer();
    final fontSize = style?.fontSize ??
        DefaultTextStyle.of(context).style.fontSize ?? 14;
    final emojiSize = fontSize + 10;
    void flushPlain() {
      if (plain.isEmpty) return;
      children.add(TextSpan(text: plain.toString(), style: style));
      plain.clear();
    }

    for (var offset = 0; offset < valueText.length;) {
      final firstUnit = valueText.codeUnitAt(offset);
      final isHighSurrogate = firstUnit >= 0xD800 && firstUnit <= 0xDBFF;
      final hasLowSurrogate =
          offset + 1 < valueText.length &&
          valueText.codeUnitAt(offset + 1) >= 0xDC00 &&
          valueText.codeUnitAt(offset + 1) <= 0xDFFF;
      final unitLength = isHighSurrogate && hasLowSurrogate ? 2 : 1;
      final rune = isHighSurrogate && hasLowSurrogate
          ? 0x10000 +
              ((firstUnit - 0xD800) << 10) +
              (valueText.codeUnitAt(offset + 1) - 0xDC00)
          : firstUnit;
      final codeUnits = valueText.substring(offset, offset + unitLength);
      final smiley = _smileyAssets.entries.firstWhere(
        (entry) => valueText.startsWith(entry.key, offset),
        orElse: () => const MapEntry('', ''),
      );
      final asset = smiley.key.isNotEmpty ? smiley.value : _assets[rune];
      final consumedLength = smiley.key.isNotEmpty
          ? smiley.key.length
          : unitLength;
      final renderedText = smiley.key.isNotEmpty ? smiley.key : codeUnits;
      if (asset == null) {
        plain.write(renderedText);
      } else {
        flushPlain();
        children.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: SizedBox(
              width: emojiSize,
              height: emojiSize,
              child: Image.asset(
                asset,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
                errorBuilder: (context, error, stackTrace) => Text(
                  renderedText,
                  style: style?.copyWith(fontSize: fontSize),
                ),
              ),
            ),
          ),
        );
      }
      offset += consumedLength;
    }
    flushPlain();
    return TextSpan(style: style, children: children);
  }
}