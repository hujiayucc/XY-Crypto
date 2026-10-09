import 'crypto_engine.dart';

class SharedText {
  const SharedText(
    this.mode,
    this.text, {
    this.key,
    this.operation,
  });

  final CryptoMode mode;
  final String text;
  final String? key;
  final String? operation;

  bool get isEncryptedPayload => operation == ShareCodec.encryptOperation;
}

abstract final class ShareCodec {
  static const scheme = 'xyd';
  static const host = 'share';
  static const legacyHost = 'app.hujiayucc.cn';
  static const webShareBase = 'https://app.hujiayucc.cn/share';

  static const maxPayloadLength = 5000;
  static const encryptOperation = 'encrypt';
  static const decryptOperation = 'decrypt';
  static final _trailingPunctuation = RegExp(r'[。，、；！？）\]}>]+$');

  static Uri encode(
    CryptoMode mode,
    String output, {
    String? key,
    String? operation,
  }) {
    if (output.isEmpty) {
      throw const FormatException('请先生成加密文');
    }
    // Legacy BASE64 share payloads have an additional HEX envelope.
    final payload = _payloadFor(mode, output);
    final encodedPayloadLength = Uri.encodeQueryComponent(payload).length;
    _checkLength(encodedPayloadLength);
    final parameters = <String, String>{
      'type': mode.index.toString(),
      'text': payload,
    };
    if (operation != null && operation.isNotEmpty) {
      if (operation != encryptOperation && operation != decryptOperation) {
        throw const FormatException('分享操作类型无效');
      }
      parameters['op'] = operation;
    }
    if (key != null && key.isNotEmpty) {
      final encodedKeyLength = Uri.encodeQueryComponent(key).length;
      _checkLength(encodedKeyLength);
      _checkLength(encodedPayloadLength + encodedKeyLength);
      parameters['key'] = key;
    }
    return Uri(scheme: scheme, host: host, queryParameters: parameters);
  }

  static Uri encodeWebUrl(Uri deepLink) {
    if (!_isSupportedUri(deepLink) || deepLink.scheme != scheme) {
      throw const FormatException('分享链接格式无效');
    }
    final webUri = Uri.parse('$webShareBase#${Uri.encodeComponent(deepLink.toString())}');
    if (webUri.toString().length > 8192) {
      throw const FormatException('分享链接过长');
    }
    return webUri;
  }

  static Uri encodeWebShare(
    CryptoMode mode,
    String output, {
    String? key,
    String? operation,
  }) => encodeWebUrl(
        encode(
          mode,
          output,
          key: key,
          operation: operation,
        ),
      );

  static String composeMessage(Uri uri) =>
      '我分享了一个加密文，点击导入：\n${uri.toString()}';

  static int encodedPayloadLength(Uri uri) {
    final payload = uri.queryParameters['text'];
    return payload == null ? 0 : Uri.encodeQueryComponent(payload).length;
  }

  static bool isShareLink(String text) {
    final uri = Uri.tryParse(text.trim());
    return uri != null && _isSupportedUri(uri);
  }

  /// Finds a share link inside text produced by another app, such as
  /// "点击查看\\n[xyd link]".

  static String? findShareLink(String text) {
    final trimmed = text.trim();
    final website = Uri.tryParse(trimmed);
    if (website != null &&
        website.scheme == 'https' &&
        website.host == legacyHost &&
        website.path == '/share' &&
        website.fragment.isNotEmpty) {
      final fragment = website.fragment;
      if (isShareLink(fragment)) return fragment;
      final decoded = Uri.decodeComponent(fragment);
      if (isShareLink(decoded)) return decoded;
    }
    final match = RegExp(
      r'(?:xyd://share\?[^\s]+|https://app\.hujiayucc\.cn/share#[^\s]+|https://app\.hujiayucc\.cn(?:/)?\?[^\s]+)',
    ).firstMatch(trimmed);
    if (match != null) {
      final value = match.group(0)!.replaceFirst(_trailingPunctuation, '');
      final embeddedWebsite = Uri.tryParse(value);
      if (embeddedWebsite != null &&
          embeddedWebsite.path == '/share' &&
          embeddedWebsite.fragment.isNotEmpty) {
        final fragment = embeddedWebsite.fragment;
        if (isShareLink(fragment)) return fragment;
        final decoded = Uri.decodeComponent(fragment);
        if (isShareLink(decoded)) return decoded;
      }
      return value;
    }
    if (isShareLink(trimmed)) return trimmed;
    return null;
  }

  static SharedText? decode(String text) {
    final trimmed = text.trim();
    final link = findShareLink(trimmed);
    final candidate = link ?? trimmed;
    final uri = Uri.tryParse(candidate);
    if (uri == null) {
      if (trimmed.startsWith('$scheme://') ||
          trimmed.startsWith('https://$legacyHost')) {
        throw const FormatException('分享链接格式无效');
      }
      return null;
    }
    if (!_isSupportedUri(uri)) return null;

    final typeValues = uri.queryParametersAll['type'];
    final payloadValues = uri.queryParametersAll['text'];
    if (typeValues == null ||
        typeValues.length != 1 ||
        payloadValues == null ||
        payloadValues.length != 1) {
      throw const FormatException('分享链接的模式或内容缺失');
    }
    final index = int.tryParse(typeValues.single);
    final payload = payloadValues.single;
    if (index == null ||
        index < 0 ||
        index >= CryptoMode.values.length ||
        payload.isEmpty) {
      throw const FormatException('分享链接的模式或内容缺失');
    }
    final encodedPayloadLength = Uri.encodeQueryComponent(payload).length;
    _checkLength(encodedPayloadLength);

    final mode = CryptoMode.values[index];
    final decoded = mode.label.contains('BASE64')
        ? CryptoEngine.transform(
            input: payload, mode: CryptoMode.hex, encode: false)
        : payload;
    if (decoded.isEmpty) {
      throw const FormatException('分享链接内容为空');
    }
    final operationValues = uri.queryParametersAll['op'] ?? const <String>[];
    if (operationValues.length > 1 ||
        (operationValues.isNotEmpty &&
            operationValues.single != encryptOperation &&
            operationValues.single != decryptOperation)) {
      throw const FormatException('分享操作类型无效');
    }
    final keyValues = uri.queryParametersAll['key'] ?? const <String>[];
    if (keyValues.length > 1) {
      throw const FormatException('分享密钥参数重复');
    }
    final operation = operationValues.isEmpty ? null : operationValues.single;
    final key = keyValues.isEmpty ? null : keyValues.single;
    if (key != null && key.isNotEmpty) {
      final encodedKeyLength = Uri.encodeQueryComponent(key).length;
      _checkLength(encodedKeyLength);
      _checkLength(encodedPayloadLength + encodedKeyLength);
    }
    return SharedText(mode, decoded, key: key, operation: operation);
  }

  static String _payloadFor(CryptoMode mode, String output) {
    return mode.label.contains('BASE64')
        ? CryptoEngine.transform(
            input: output, mode: CryptoMode.hex, encode: true)
        : output;
  }

  static bool _isSupportedUri(Uri uri) {
    final custom = uri.scheme == scheme && uri.host == host;
    final legacy = uri.scheme == 'https' &&
        uri.host == legacyHost &&
        (uri.path.isEmpty || uri.path == '/');
    return custom || legacy;
  }

  static void _checkLength(int encodedLength) {
    if (encodedLength > maxPayloadLength) {
      throw const FormatException('分享的加密文过长，最多支持5000个字符');
    }
  }
}
