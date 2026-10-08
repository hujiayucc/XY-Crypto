import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart' as pc;
import 'package:test/test.dart';
import 'package:xy_crypto/xy_crypto.dart';
import 'package:xy_crypto/src/sm4_engine.dart';

String hex(List<int> bytes) =>
    bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();

Uint8List hexBytes(String input) {
  final output = Uint8List(input.length ~/ 2);
  for (var i = 0; i < output.length; i++) {
    output[i] = int.parse(input.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return output;
}

void main() {
  test('Generated keys are usable for every keyed mode', () {
    expect(CryptoEngine.generateKey(CryptoMode.desHex).length, 8);

    final aesKey = CryptoEngine.generateKey(CryptoMode.aesGcmHex);
    expect(aesKey, isNotEmpty);
    final encrypted =
        ModernCrypto.chacha20Poly1305Encrypt(aesKey, utf8.encode('abc'));
    expect(utf8.decode(ModernCrypto.chacha20Poly1305Decrypt(aesKey, encrypted)),
        'abc');

    final hmac = CryptoEngine.generateKey(CryptoMode.hmacSha256Hex);
    expect(ModernCrypto.hmacSha256(hmac, utf8.encode('abc')),
        ModernCrypto.hmacSha256(hmac, utf8.encode('abc')));

    final rsa = CryptoEngine.generateKey(CryptoMode.rsaOaepBase64);
    final rsaValue = jsonDecode(rsa) as Map<String, dynamic>;
    expect(rsaValue.keys, containsAll(<String>['n', 'e', 'd', 'p', 'q']));
    const rsaPlain = 'RSA random key text';
    final rsaCipher = ModernCrypto.rsaOaepEncrypt(rsa, utf8.encode(rsaPlain));
    expect(utf8.decode(ModernCrypto.rsaOaepDecrypt(rsa, rsaCipher)), rsaPlain);

    final ecdsa = CryptoEngine.generateKey(CryptoMode.ecdsaSignHex);
    final ecdsaValue = jsonDecode(ecdsa) as Map<String, dynamic>;
    expect(ecdsaValue.keys, containsAll(<String>['d', 'q']));
    final message = utf8.encode('sign me');
    final signature = ModernCrypto.ecdsaSign(ecdsa, message);
    expect(ModernCrypto.ecdsaVerify(ecdsa, message, signature), isTrue);

    expect(() => CryptoEngine.generateKey(CryptoMode.sha256Hex),
        throwsFormatException);
  });
  test('SM4 standard block vector', () {
    final key = hexBytes('0123456789abcdeffedcba9876543210');
    final cipher = Sm4Engine()..init(true, pc.KeyParameter(key));
    final encrypted = cipher.process(key);
    expect(hex(encrypted), '681edf34d206965e86b3e94f536e4246');

    final decipher = Sm4Engine()..init(false, pc.KeyParameter(key));
    expect(decipher.process(encrypted), key);
  });

  test('all reversible modern modes roundtrip across formats', () {
    const plain = '中文 + / = & ? 😀';
    const key = 'modern test password';
    final modes = <CryptoMode>[
      CryptoMode.aesGcmBase64,
      CryptoMode.aesGcmHex,
      CryptoMode.aesGcmBytes,
      CryptoMode.chacha20Poly1305Base64,
      CryptoMode.chacha20Poly1305Hex,
      CryptoMode.chacha20Poly1305Bytes,
      CryptoMode.xchacha20Poly1305Base64,
      CryptoMode.xchacha20Poly1305Hex,
      CryptoMode.xchacha20Poly1305Bytes,
      CryptoMode.sm4GcmBase64,
      CryptoMode.sm4GcmHex,
      CryptoMode.sm4GcmBytes,
      CryptoMode.aesCbcHmacBase64,
      CryptoMode.aesCbcHmacHex,
      CryptoMode.aesCbcHmacBytes,
      CryptoMode.sm4CbcHmacBase64,
      CryptoMode.sm4CbcHmacHex,
      CryptoMode.sm4CbcHmacBytes,
      CryptoMode.aesCtrHmacBase64,
      CryptoMode.aesCtrHmacHex,
      CryptoMode.aesCtrHmacBytes,
      CryptoMode.base32,
      CryptoMode.base58,
      CryptoMode.urlEncode,
      CryptoMode.utf16Hex,
      CryptoMode.gb18030Bytes,
    ];
    for (final mode in modes) {
      final sample = mode == CryptoMode.gb18030Bytes ? '中文 + / = & ?' : plain;
      final encoded = CryptoEngine.transform(
        input: sample,
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
        sample,
        reason: mode.label,
      );
    }

    final gbkLossy = CryptoEngine.transform(
      input: plain,
      mode: CryptoMode.gb18030Bytes,
      encode: true,
      key: key,
    );
    expect(
      CryptoEngine.transform(
        input: gbkLossy,
        mode: CryptoMode.gb18030Bytes,
        encode: false,
        key: key,
      ),
      '中文 + / = & ? ?',
    );
  });

  test('digests and HMACs share equivalent BASE64, Byte[ ] and HEX output', () {
    const input = 'kdf input';
    const key = 'kdf password';
    final groups = <List<CryptoMode>>[
      [
        CryptoMode.sha256Base64,
        CryptoMode.sha256Bytes,
        CryptoMode.sha256Hex,
      ],
      [
        CryptoMode.sha512Base64,
        CryptoMode.sha512Bytes,
        CryptoMode.sha512Hex,
      ],
      [
        CryptoMode.sha3_256Base64,
        CryptoMode.sha3_256Bytes,
        CryptoMode.sha3_256Hex,
      ],
      [
        CryptoMode.blake2b512Base64,
        CryptoMode.blake2b512Bytes,
        CryptoMode.blake2b512Hex,
      ],
      [
        CryptoMode.sm3Base64,
        CryptoMode.sm3Bytes,
        CryptoMode.sm3Hex,
      ],
      [
        CryptoMode.hmacSha256Base64,
        CryptoMode.hmacSha256Bytes,
        CryptoMode.hmacSha256Hex,
      ],
      [
        CryptoMode.hmacSha3_256Base64,
        CryptoMode.hmacSha3_256Bytes,
        CryptoMode.hmacSha3_256Hex,
      ],
      [
        CryptoMode.hmacSm3Base64,
        CryptoMode.hmacSm3Bytes,
        CryptoMode.hmacSm3Hex,
      ],
    ];
    for (final group in groups) {
      expect(
        group.map((mode) => mode.formatLabel).toList(),
        ['BASE64', 'Byte[ ]', 'HEX'],
      );
      final outputs = group
          .map((mode) => CryptoEngine.transform(
                input: input,
                mode: mode,
                encode: true,
                key: key,
              ))
          .toList();
      final expectedBytes = hexBytes(outputs[2]);
      expect(base64Decode(outputs[0]), expectedBytes,
          reason: group.first.label);
      final byteText = outputs[1].trim();
      final byteValues = byteText
          .substring(1, byteText.length - 1)
          .split(',')
          .where((part) => part.trim().isNotEmpty)
          .map((part) => int.parse(part.trim()))
          .map((value) => value < 0 ? value + 256 : value)
          .toList();
      expect(byteValues, expectedBytes, reason: group[1].label);
      expect(group.first.isDigest, isTrue);
      expect(
          group.first.operationSpec.kind,
          group.first.label.startsWith('HMAC-')
              ? CryptoOperationKind.keyedDigest
              : CryptoOperationKind.digest);
      expect(group.first.needsKey, group.first.label.startsWith('HMAC-'));
    }
  });

  test('all ten encoding choices roundtrip representative algorithms', () {
    const plain = 'uniform formats 中文 + / = & ? 😀';
    const key = 'uniform format key';
    const formats = <String>[
      'BASE32',
      'BASE58',
      'BASE64',
      'Byte[ ] (GB18030/GBK兼容)',
      'Byte[ ] (GBK)',
      'Byte[ ] (UTF-8)',
      'HEX',
      'UniCode',
      'URL Encode',
      'UTF-16 (HEX)',
    ];
    for (final algorithm in <String>[
      'DES',
      'AES-256-GCM',
      'ChaCha20-Poly1305',
      'SM4-GCM',
    ]) {
      final choice = cryptoAlgorithmChoices.firstWhere(
        (item) => item.label == algorithm,
      );
      expect(choice.modes.map((mode) => mode.formatLabel).toSet(),
          containsAll(formats),
          reason: algorithm);
      for (final mode in choice.modes) {
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
          reason: mode.label,
        );
      }
    }

    for (final algorithm in <String>['SHA-256', 'HMAC-SHA256', 'MD5']) {
      final choice = cryptoAlgorithmChoices.firstWhere(
        (item) => item.label == algorithm,
      );
      for (final mode in choice.modes) {
        expect(
          CryptoEngine.transform(
            input: plain,
            mode: mode,
            encode: true,
            key: key,
          ),
          isNotEmpty,
          reason: mode.label,
        );
      }
    }
  });

  test('KDF modes still produce output', () {
    const input = 'kdf input';
    const key = 'kdf password';
    for (final mode in <CryptoMode>[
      CryptoMode.pbkdf2Base64,
      CryptoMode.pbkdf2Hex,
      CryptoMode.pbkdf2Bytes,
      CryptoMode.scryptBase64,
      CryptoMode.scryptHex,
      CryptoMode.scryptBytes,
      CryptoMode.argon2idBase64,
      CryptoMode.argon2idHex,
      CryptoMode.argon2idBytes,
    ]) {
      final output = CryptoEngine.transform(
        input: input,
        mode: mode,
        encode: true,
        key: key,
      );
      expect(output, isNotEmpty, reason: mode.label);
    }
  });

  test('RSA-OAEP roundtrip', () {
    final random = pc.FortunaRandom()
      ..seed(pc.KeyParameter(Uint8List.fromList(
        List<int>.generate(32, (index) => index + 1),
      )));
    final generator = pc.RSAKeyGenerator()
      ..init(pc.ParametersWithRandom(
        pc.RSAKeyGeneratorParameters(BigInt.from(65537), 1024, 5),
        random,
      ));
    final pair = generator.generateKeyPair();
    final publicKey = pair.publicKey as pc.RSAPublicKey;
    final privateKey = pair.privateKey as pc.RSAPrivateKey;
    final publicJson = jsonEncode({
      'n': publicKey.modulus.toString(),
      'e': publicKey.publicExponent.toString(),
    });
    final privateJson = jsonEncode({
      'n': privateKey.modulus.toString(),
      'd': privateKey.privateExponent.toString(),
      'p': privateKey.p.toString(),
      'q': privateKey.q.toString(),
      'e': privateKey.publicExponent.toString(),
    });
    const plain = 'RSA short text';
    final cipher = ModernCrypto.rsaOaepEncrypt(
      publicJson,
      utf8.encode(plain),
    );
    expect(
      utf8.decode(ModernCrypto.rsaOaepDecrypt(privateJson, cipher)),
      plain,
    );
  });

  test(
      'algorithm and encoding choices are sorted without changing mode indexes',
      () {
    final labels =
        cryptoAlgorithmChoices.map((choice) => choice.label).toList();
    expect(
        labels,
        orderedEquals([...labels]
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()))));
    final visibleModes =
        cryptoAlgorithmChoices.expand((choice) => choice.modes);
    expect(visibleModes, hasLength(240));
    expect(visibleModes.toSet(), hasLength(240));
    expect(CryptoMode.values.length, greaterThan(80));
    for (final choice
        in cryptoAlgorithmChoices.where((choice) => choice.label != '编码转换')) {
      expect(
        choice.modes.map((mode) => mode.formatLabel).toSet(),
        hasLength(10),
        reason: choice.label,
      );
    }
    for (final choice in cryptoAlgorithmChoices) {
      final formats = choice.modes.map((mode) => mode.formatLabel).toList();
      expect(
        formats,
        orderedEquals([...formats]
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()))),
        reason: choice.label,
      );
    }
    expect(CryptoMode.hex.index, 0);
    expect(CryptoMode.ecdsaSignBytes.index, 63);
    expect(CryptoMode.sha256Base64.index, 64);
    expect(CryptoMode.hmacSm3Bytes.index, 79);
    expect(CryptoMode.values.length, 266);
    expect(CryptoMode.aesGcmBase32.index, 80);
    expect(CryptoMode.xchacha20Poly1305Utf8Bytes.index, 265);
  });

  test('ECDSA sign and verify', () {
    final domain = pc.ECDomainParameters('secp256r1');
    final privateValue = BigInt.parse(
      '519b423d715f8b5d549b9e4f6b4a8b7f2c6f1f5b1e3d5a7c9b8d7e6f5a4b3c2',
      radix: 16,
    );
    final point = domain.G * privateValue;
    final keyJson = jsonEncode({
      'd': privateValue.toString(),
      'q': base64Encode(point!.getEncoded(false)),
    });
    const plain = 'signed text';
    final signature = ModernCrypto.ecdsaSign(keyJson, utf8.encode(plain));
    expect(signature, hasLength(64));
    expect(
      ModernCrypto.ecdsaVerify(keyJson, utf8.encode(plain), signature),
      isTrue,
    );
    expect(
      ModernCrypto.ecdsaVerify(keyJson, utf8.encode('changed'), signature),
      isFalse,
    );
  });
}
