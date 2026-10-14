import 'dart:convert';
import 'package:crypto/crypto.dart' as crypto;
import 'crypto_engine.dart';
import 'share_codec.dart';

abstract final class ShareFileCodec {
  static const extension = '.xyshare';
  static const fileName = 'XY加密分享.xyshare';
  static const mimeType = 'application/x-xyshare';
  static const maxFileBytes = 32 * 1024 * 1024;

  static List<int> encode(CryptoMode mode, String text, {String? key, String? operation}) {
    if (text.isEmpty) throw const FormatException('分享内容为空');
    if (operation != null && operation != ShareCodec.encryptOperation && operation != ShareCodec.decryptOperation) {
      throw const FormatException('分享操作类型无效');
    }
    final content = <String, Object>{'format': 'xyshare', 'version': 1, 'mode': mode.index, 'text': text,
      if (operation != null) 'op': operation, if (key != null && key.isNotEmpty) 'key': key};
    final digest = crypto.sha256.convert(utf8.encode(jsonEncode(content))).toString();
    final bytes = utf8.encode(jsonEncode({...content, 'sha256': digest}));
    if (bytes.length > maxFileBytes) throw const FormatException('分享文件超过 32 MB，请缩短内容');
    return bytes;
  }

  static SharedText decode(List<int> bytes) {
    if (bytes.isEmpty || bytes.length > maxFileBytes) throw const FormatException('分享文件为空或超过 32 MB');
    try {
      final object = jsonDecode(utf8.decode(bytes));
      if (object is! Map<String, dynamic>) throw const FormatException('分享文件格式无效');
      final mode = object['mode'], text = object['text'], op = object['op'], key = object['key'], digest = object['sha256'];
      if (object['format'] != 'xyshare' || object['version'] != 1 || mode is! int || mode < 0 || mode >= CryptoMode.values.length || text is! String || text.isEmpty || (op != null && op != ShareCodec.encryptOperation && op != ShareCodec.decryptOperation) || (key != null && key is! String) || digest is! String || !RegExp(r'^[0-9a-f]{64}$').hasMatch(digest)) throw const FormatException('分享文件格式或版本无效');
      final content = <String, Object>{'format': 'xyshare', 'version': 1, 'mode': mode, 'text': text,
        if (op != null) 'op': op as String, if (key != null) 'key': key as String};
      if (crypto.sha256.convert(utf8.encode(jsonEncode(content))).toString() != digest) throw const FormatException('分享文件内容不完整');
      return SharedText(CryptoMode.values[mode], text, key: key as String?, operation: op as String?);
    } on FormatException { rethrow; } catch (_) { throw const FormatException('分享文件格式无效'); }
  }
}