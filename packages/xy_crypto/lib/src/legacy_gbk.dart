import 'gbk_tables.g.dart';

/// GBK conversion with Java's replacement behavior for unmappable characters.
abstract final class LegacyGbk {
  static List<int> encode(String text) {
    final result = <int>[];
    for (final rune in text.runes) {
      if (rune < 0x80) {
        result.add(rune);
        continue;
      }
      final code = gbkEncodeMap[rune];
      if (code == null) {
        result.add(0x3f);
      } else if (code <= 0xff) {
        result.add(code);
      } else {
        result
          ..add(code >> 8)
          ..add(code & 0xff);
      }
    }
    return result;
  }

  static String decode(List<int> bytes) {
    final result = StringBuffer();
    var i = 0;
    while (i < bytes.length) {
      final lead = bytes[i++] & 0xff;
      if (lead < 0x80) {
        result.writeCharCode(lead);
        continue;
      }
      final single = gbkDecodeMap[lead];
      if (single != null) {
        result.writeCharCode(single);
        continue;
      }
      if (lead < 0x81 || lead > 0xfe || i == bytes.length) {
        result.writeCharCode(0xfffd);
        continue;
      }
      final trail = bytes[i] & 0xff;
      final code = gbkDecodeMap[(lead << 8) | trail];
      if (code != null) {
        i++;
        result.writeCharCode(code);
      } else {
        result.writeCharCode(0xfffd);
        // Valid trailing-byte range forms one unmappable byte pair.
        if (trail >= 0x40 && trail <= 0xfe && trail != 0x7f) i++;
      }
    }
    return result.toString();
  }
}
