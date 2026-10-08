import 'package:test/test.dart';
import 'package:xy_crypto/xy_crypto.dart';

void main() {
  test('decodes a link embedded in a system-share message', () {
    final uri = ShareCodec.encode(CryptoMode.hex, 'A1B2');
    final message = ShareCodec.composeMessage(uri);
    expect(ShareCodec.findShareLink(message), uri.toString());
    expect(ShareCodec.decode(message)?.text, 'A1B2');
  });

  test('removes common trailing punctuation from embedded links', () {
    final uri = ShareCodec.encode(CryptoMode.hex, 'AB');
    expect(ShareCodec.findShareLink('${uri.toString()}。'), uri.toString());
  });

  test('rejects duplicate share parameters', () {
    expect(
      () => ShareCodec.decode('xyd://share?type=0&type=1&text=AB'),
      throwsFormatException,
    );
  });

  test('accepts the legacy HTTPS root link', () {
    final result = ShareCodec.decode(
      'https://app.hujiayucc.cn/?type=0&text=AB',
    );
    expect(result?.mode, CryptoMode.hex);
    expect(result?.text, 'AB');
    expect(result?.operation, isNull);
    expect(result?.key, isNull);
  });

  test('keeps encrypted payload and optional key in the new protocol', () {
    const cipher = '密文+/=&?';
    const key = 'share secret';
    final uri = ShareCodec.encode(
      CryptoMode.aesGcmBase64,
      cipher,
      operation: ShareCodec.encryptOperation,
      key: key,
    );
    final decoded = ShareCodec.decode(uri.toString());
    expect(decoded?.mode, CryptoMode.aesGcmBase64);
    expect(decoded?.text, cipher);
    expect(decoded?.operation, ShareCodec.encryptOperation);
    expect(decoded?.key, key);
    expect(decoded?.isEncryptedPayload, isTrue);
  });

  test('encrypted share can omit the key', () {
    final uri = ShareCodec.encode(
      CryptoMode.aesGcmHex,
      'A1B2',
      operation: ShareCodec.encryptOperation,
    );
    final decoded = ShareCodec.decode(uri.toString());
    expect(decoded?.text, 'A1B2');
    expect(decoded?.operation, ShareCodec.encryptOperation);
    expect(decoded?.key, isNull);
  });

  test('rejects duplicate key and invalid operation parameters', () {
    expect(
      () => ShareCodec.decode('xyd://share?type=0&text=AB&key=a&key=b'),
      throwsFormatException,
    );
    expect(
      () => ShareCodec.decode('xyd://share?type=0&text=AB&op=invalid'),
      throwsFormatException,
    );
  });

  test('enforces the original 5000-character share limit', () {
    final boundary = 'A' * ShareCodec.maxPayloadLength;
    expect(ShareCodec.encode(CryptoMode.hex, boundary), isNotNull);
    expect(
      () => ShareCodec.encode(CryptoMode.hex, '$boundary A'),
      throwsFormatException,
    );
  });

  test('reports encoded payload length for QR display', () {
    final uri = ShareCodec.encode(CryptoMode.hex, '中文');
    expect(
      ShareCodec.encodedPayloadLength(uri),
      Uri.encodeQueryComponent('中文').length,
    );
  });

  test('rejects malformed supported links', () {
    expect(
      () => ShareCodec.decode('xyd://share?type=0'),
      throwsFormatException,
    );
    expect(
      () => ShareCodec.decode('xyd://share?type=0&text='),
      throwsFormatException,
    );
  });
}
