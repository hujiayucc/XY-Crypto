import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:xy_crypto/xy_crypto.dart';

void main() {
  final data =
      jsonDecode(File('test/fixtures/java_vectors.json').readAsStringSync())
          as Map<String, dynamic>;
  final vectors = data['vectors'] as List<dynamic>;
  for (var i = 0; i < vectors.length; i++) {
    final v = vectors[i] as Map<String, dynamic>;
    final mode = CryptoMode.values[v['mode'] as int];
    test('JCE reference $i: ${mode.label}', () {
      final encoded = CryptoEngine.transform(
          input: v['input'] as String,
          mode: mode,
          encode: true,
          key: v['key'] as String);
      expect(encoded, v['expected']);
      if (!mode.isDigest) {
        expect(
            CryptoEngine.transform(
                input: encoded,
                mode: mode,
                encode: false,
                key: v['key'] as String),
            v['decoded']);
      }
    });
  }
  test('DES accepts arbitrary non-empty password lengths', () {
    const plain = 'DES password test';
    for (final key in ['a', 'longer DES password', '中文密钥']) {
      for (final mode in <CryptoMode>[
        CryptoMode.desBase64,
        CryptoMode.desHex,
        CryptoMode.desBytes,
      ]) {
        final encoded = CryptoEngine.transform(
          input: plain,
          mode: mode,
          encode: true,
          key: key,
        );
        expect(
          CryptoEngine.transform(
            input: encoded,
            mode: mode,
            encode: false,
            key: key,
          ),
          plain,
          reason: '${mode.label} / $key',
        );
      }
    }
    expect(
      () => CryptoEngine.transform(
        input: plain,
        mode: CryptoMode.desHex,
        encode: true,
      ),
      throwsFormatException,
    );
  });

  test('DES keeps legacy eight-character vectors unchanged', () {
    expect(
      CryptoEngine.transform(
        input: 'abc',
        mode: CryptoMode.desBase64,
        encode: true,
        key: '12345678',
      ),
      'wkuY+tXAWA4=',
    );
  });

  test('RC4 published Key/Plaintext example', () {
    expect(
        CryptoEngine.transform(
            input: 'Plaintext',
            mode: CryptoMode.rc4Hex,
            encode: true,
            key: 'Key'),
        'BBF316E8D940AF0AD3');
  });
  test('AES-256-GCM roundtrip authenticates ciphertext', () {
    const plain = '中文 + / = & ? 😀';
    const key = 'aes test key';
    final encoded = CryptoEngine.transform(
      input: plain,
      mode: CryptoMode.aesGcmBase64,
      encode: true,
      key: key,
    );
    expect(
      CryptoEngine.transform(
        input: encoded,
        mode: CryptoMode.aesGcmBase64,
        encode: false,
        key: key,
      ),
      plain,
    );
    expect(encoded, isNotEmpty);
    expect(
      CryptoEngine.transform(
        input: plain,
        mode: CryptoMode.aesGcmBase64,
        encode: true,
        key: key,
      ),
      isNot(encoded),
    );
    expect(
      () => CryptoEngine.transform(
        input: encoded,
        mode: CryptoMode.aesGcmBase64,
        encode: false,
        key: 'wrong key',
      ),
      throwsFormatException,
    );
  });

  test('AES-256-GCM rejects malformed ciphertext', () {
    expect(
      () => CryptoEngine.transform(
        input: base64Encode(<int>[1, 2, 3]),
        mode: CryptoMode.aesGcmBase64,
        encode: false,
        key: 'key',
      ),
      throwsFormatException,
    );
  });

  test('Reject out-of-range signed bytes', () {
    expect(
        () => CryptoEngine.transform(
            input: '[256]', mode: CryptoMode.utf8Bytes, encode: false),
        throwsFormatException);
  });
  test('One-way modes report their own algorithm', () {
    final cases = <({CryptoMode mode, String message})>[
      (
        mode: CryptoMode.md5Upper32,
        message: 'MD5 是单向摘要，仅支持生成摘要',
      ),
      (
        mode: CryptoMode.sha256Hex,
        message: 'SHA-256 是单向摘要，仅支持生成摘要',
      ),
      (
        mode: CryptoMode.hmacSha256Hex,
        message: 'HMAC-SHA256 是带密钥的单向摘要，仅支持生成摘要',
      ),
      (
        mode: CryptoMode.pbkdf2Hex,
        message: 'PBKDF2-HMAC-SHA256 是单向密钥派生，仅支持生成结果',
      ),
      (
        mode: CryptoMode.ecdsaSignHex,
        message: 'ECDSA-SHA256 签名 是单向签名，仅支持生成签名',
      ),
    ];

    for (final testCase in cases) {
      expect(
        () => CryptoEngine.transform(
          input: 'abc',
          mode: testCase.mode,
          encode: false,
          key: 'test-key',
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            testCase.message,
          ),
        ),
        reason: testCase.mode.label,
      );
    }
  });
  test('Share mode IDs and Base64 HEX envelope roundtrip', () {
    for (final mode in CryptoMode.values) {
      const text = '中文 + / = & ? 😀';
      final uri = ShareCodec.encode(mode, text);
      final result = ShareCodec.decode(uri.toString())!;
      expect(result.mode, mode);
      expect(result.text, text);
    }
  });
  test('Share invalid mode rejected', () {
    expect(() => ShareCodec.decode('xyd://share?type=999&text=a'),
        throwsFormatException);
  });
}
