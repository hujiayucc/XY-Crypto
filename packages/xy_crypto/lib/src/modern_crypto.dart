// ignore_for_file: curly_braces_in_flow_control_structures, deprecated_member_use

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:pointycastle/export.dart' as pc;

import 'sm4_engine.dart';

class _Envelope {
  const _Envelope(this.nonce, this.payload);
  final Uint8List nonce;
  final Uint8List payload;
}

/// Modern algorithms and format helpers. Every binary format starts with a
/// four-byte ASCII marker so malformed or mismatched ciphertext is rejected.
abstract final class ModernCrypto {
  static const _mask32 = 0xffffffff;
  static final _random = math.Random.secure();
  static const _base32Alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  static const _base58Alphabet =
      '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

  static Uint8List randomBytes(int length) => Uint8List.fromList(
        List<int>.generate(length, (_) => _random.nextInt(256)),
      );

  static Uint8List passwordKey(String password, [int length = 32]) {
    if (password.isEmpty) throw const FormatException('请输入秘钥');
    final digest = crypto.sha256.convert(utf8.encode(password)).bytes;
    return Uint8List.fromList(digest.sublist(0, length));
  }

  static Uint8List labelledKey(String password, String label, int length) {
    return passwordKey('$label:$password', length);
  }

  static Uint8List _hmac(pc.Digest digest, Uint8List key, Uint8List data) {
    final mac = pc.HMac.withDigest(digest)..init(pc.KeyParameter(key));
    return mac.process(data);
  }

  static Uint8List _hmacSha256(Uint8List key, Uint8List data) =>
      _hmac(pc.SHA256Digest(), key, data);

  static Uint8List _hmacSha3(Uint8List key, Uint8List data) =>
      _hmac(pc.SHA3Digest(256), key, data);

  static Uint8List _hmacSm3(Uint8List key, Uint8List data) =>
      _hmac(pc.SM3Digest(), key, data);

  static bool _constantTimeEqual(List<int> a, List<int> b) {
    var result = a.length ^ b.length;
    final length = math.max(a.length, b.length);
    for (var i = 0; i < length; i++) {
      result |= (i < a.length ? a[i] : 0) ^ (i < b.length ? b[i] : 0);
    }
    return result == 0;
  }

  static Uint8List _pack(String marker, List<int> nonce, List<int> payload) {
    return Uint8List.fromList(<int>[
      ...ascii.encode(marker),
      ...nonce,
      ...payload,
    ]);
  }

  static _Envelope _unpack(
    List<int> encoded,
    String marker,
    int nonceLength, {
    int minimumPayload = 1,
  }) {
    final headerLength = marker.length + nonceLength;
    if (encoded.length < headerLength + minimumPayload ||
        ascii.decode(encoded.sublist(0, marker.length), allowInvalid: true) !=
            marker) {
      throw FormatException('$marker 密文格式无效');
    }
    return _Envelope(
      Uint8List.fromList(encoded.sublist(marker.length, headerLength)),
      Uint8List.fromList(encoded.sublist(headerLength)),
    );
  }

  static Uint8List _aeadBlockEncrypt(
    pc.AEADBlockCipher cipher,
    Uint8List key,
    Uint8List nonce,
    List<int> data,
  ) {
    cipher.init(
      true,
      pc.AEADParameters<pc.KeyParameter>(
        pc.KeyParameter(key),
        128,
        nonce,
        Uint8List(0),
      ),
    );
    return cipher.process(Uint8List.fromList(data));
  }

  static Uint8List _aeadBlockDecrypt(
    pc.AEADBlockCipher cipher,
    Uint8List key,
    Uint8List nonce,
    Uint8List data,
  ) {
    cipher.init(
      false,
      pc.AEADParameters<pc.KeyParameter>(
        pc.KeyParameter(key),
        128,
        nonce,
        Uint8List(0),
      ),
    );
    try {
      return cipher.process(data);
    } on pc.InvalidCipherTextException {
      throw const FormatException('认证失败：密钥错误或密文已损坏');
    }
  }

  static Uint8List _chachaEncrypt(
    Uint8List key,
    Uint8List nonce,
    List<int> data,
  ) {
    final cipher = pc.ChaCha20Poly1305(
      pc.ChaCha7539Engine(),
      pc.Poly1305(),
    )..init(
        true,
        pc.AEADParameters<pc.KeyParameter>(
          pc.KeyParameter(key),
          128,
          nonce,
          Uint8List(0),
        ),
      );
    final input = Uint8List.fromList(data);
    final output = Uint8List(cipher.getOutputSize(input.length));
    var count = cipher.processBytes(input, 0, input.length, output, 0);
    count += cipher.doFinal(output, count);
    return Uint8List.fromList(output.sublist(0, count));
  }

  static Uint8List _chachaDecrypt(
    Uint8List key,
    Uint8List nonce,
    Uint8List data,
  ) {
    final cipher = pc.ChaCha20Poly1305(
      pc.ChaCha7539Engine(),
      pc.Poly1305(),
    )..init(
        false,
        pc.AEADParameters<pc.KeyParameter>(
          pc.KeyParameter(key),
          128,
          nonce,
          Uint8List(0),
        ),
      );
    final output = Uint8List(cipher.getOutputSize(data.length));
    try {
      var count = cipher.processBytes(data, 0, data.length, output, 0);
      count += cipher.doFinal(output, count);
      return Uint8List.fromList(output.sublist(0, count));
    } catch (_) {
      throw const FormatException('认证失败：密钥错误或密文已损坏');
    }
  }

  static Uint8List chacha20Poly1305Encrypt(String password, List<int> data) {
    final nonce = randomBytes(12);
    return _pack(
      'CCP1',
      nonce,
      _chachaEncrypt(passwordKey(password), nonce, data),
    );
  }

  static Uint8List chacha20Poly1305Decrypt(String password, List<int> data) {
    final envelope = _unpack(data, 'CCP1', 12, minimumPayload: 16);
    return _chachaDecrypt(
        passwordKey(password), envelope.nonce, envelope.payload);
  }

  static int _rotl32(int value, int bits) =>
      ((value << bits) | ((value & _mask32) >>> (32 - bits))) & _mask32;

  static void _quarterRound(List<int> state, int a, int b, int c, int d) {
    state[a] = (state[a] + state[b]) & _mask32;
    state[d] = _rotl32(state[d] ^ state[a], 16);
    state[c] = (state[c] + state[d]) & _mask32;
    state[b] = _rotl32(state[b] ^ state[c], 12);
    state[a] = (state[a] + state[b]) & _mask32;
    state[d] = _rotl32(state[d] ^ state[a], 8);
    state[c] = (state[c] + state[d]) & _mask32;
    state[b] = _rotl32(state[b] ^ state[c], 7);
  }

  static int _readLe32(List<int> bytes, int offset) =>
      (bytes[offset] & 0xff) |
      ((bytes[offset + 1] & 0xff) << 8) |
      ((bytes[offset + 2] & 0xff) << 16) |
      ((bytes[offset + 3] & 0xff) << 24);

  static void _writeLe32(int value, List<int> bytes, int offset) {
    bytes[offset] = value & 0xff;
    bytes[offset + 1] = (value >>> 8) & 0xff;
    bytes[offset + 2] = (value >>> 16) & 0xff;
    bytes[offset + 3] = (value >>> 24) & 0xff;
  }

  static Uint8List _hChaCha20(Uint8List key, Uint8List nonce) {
    final state = <int>[
      0x61707865,
      0x3320646e,
      0x79622d32,
      0x6b206574,
      for (var i = 0; i < 8; i++) _readLe32(key, i * 4),
      for (var i = 0; i < 4; i++) _readLe32(nonce, i * 4),
    ];
    for (var round = 0; round < 10; round++) {
      _quarterRound(state, 0, 4, 8, 12);
      _quarterRound(state, 1, 5, 9, 13);
      _quarterRound(state, 2, 6, 10, 14);
      _quarterRound(state, 3, 7, 11, 15);
      _quarterRound(state, 0, 5, 10, 15);
      _quarterRound(state, 1, 6, 11, 12);
      _quarterRound(state, 2, 7, 8, 13);
      _quarterRound(state, 3, 4, 9, 14);
    }
    final output = Uint8List(32);
    _writeLe32(state[0], output, 0);
    _writeLe32(state[1], output, 4);
    _writeLe32(state[2], output, 8);
    _writeLe32(state[3], output, 12);
    _writeLe32(state[12], output, 16);
    _writeLe32(state[13], output, 20);
    _writeLe32(state[14], output, 24);
    _writeLe32(state[15], output, 28);
    return output;
  }

  static Uint8List xChaCha20Poly1305Encrypt(String password, List<int> data) {
    final nonce = randomBytes(24);
    final key = passwordKey(password);
    final subKey = _hChaCha20(key, nonce.sublist(0, 16));
    final shortNonce =
        Uint8List.fromList(<int>[0, 0, 0, 0, ...nonce.sublist(16)]);
    return _pack('XCP1', nonce, _chachaEncrypt(subKey, shortNonce, data));
  }

  static Uint8List xChaCha20Poly1305Decrypt(String password, List<int> data) {
    final envelope = _unpack(data, 'XCP1', 24, minimumPayload: 16);
    final subKey =
        _hChaCha20(passwordKey(password), envelope.nonce.sublist(0, 16));
    final shortNonce =
        Uint8List.fromList(<int>[0, 0, 0, 0, ...envelope.nonce.sublist(16)]);
    return _chachaDecrypt(subKey, shortNonce, envelope.payload);
  }

  static Uint8List sm4GcmEncrypt(String password, List<int> data) {
    final nonce = randomBytes(12);
    final key = passwordKey(password, 16);
    final cipher = pc.GCMBlockCipher(Sm4Engine());
    return _pack('S4G1', nonce, _aeadBlockEncrypt(cipher, key, nonce, data));
  }

  static Uint8List sm4GcmDecrypt(String password, List<int> data) {
    final envelope = _unpack(data, 'S4G1', 12, minimumPayload: 16);
    return _aeadBlockDecrypt(
      pc.GCMBlockCipher(Sm4Engine()),
      passwordKey(password, 16),
      envelope.nonce,
      envelope.payload,
    );
  }

  static Uint8List _cbc(bool encrypt, pc.BlockCipher block, Uint8List key,
      Uint8List iv, List<int> data) {
    final cipher = pc.PaddedBlockCipherImpl(
      pc.PKCS7Padding(),
      pc.CBCBlockCipher(block),
    );
    cipher.init(
      encrypt,
      pc.PaddedBlockCipherParameters<pc.ParametersWithIV<pc.KeyParameter>,
          Null>(
        pc.ParametersWithIV<pc.KeyParameter>(pc.KeyParameter(key), iv),
        null,
      ),
    );
    return cipher.process(Uint8List.fromList(data));
  }

  static Uint8List _cbcHmacEncrypt(
    String marker,
    String password,
    List<int> data,
    pc.BlockCipher block,
    int keyLength,
    Uint8List Function(Uint8List, Uint8List) mac,
  ) {
    final iv = randomBytes(16);
    final root = passwordKey(password);
    final cipherText = _cbc(true, block, root.sublist(0, keyLength), iv, data);
    final body = _pack(marker, iv, cipherText);
    return Uint8List.fromList(
        <int>[...body, ...mac(root.sublist(keyLength), body)]);
  }

  static Uint8List _cbcHmacDecrypt(
    String marker,
    String password,
    List<int> data,
    pc.BlockCipher block,
    int keyLength,
    int tagLength,
    Uint8List Function(Uint8List, Uint8List) mac,
  ) {
    final envelope = _unpack(data, marker, 16, minimumPayload: tagLength + 16);
    final bodyLength = data.length - tagLength;
    final body = Uint8List.fromList(data.sublist(0, bodyLength));
    final tag = data.sublist(bodyLength);
    final root = passwordKey(password);
    if (!_constantTimeEqual(tag, mac(root.sublist(keyLength), body))) {
      throw const FormatException('认证失败：密钥错误或密文已损坏');
    }
    try {
      return _cbc(false, block, root.sublist(0, keyLength), envelope.nonce,
          envelope.payload.sublist(0, envelope.payload.length - tagLength));
    } catch (_) {
      throw const FormatException('密文格式无效');
    }
  }

  static Uint8List aesCbcHmacEncrypt(String password, List<int> data) =>
      _cbcHmacEncrypt(
        'ACB1',
        password,
        data,
        pc.AESEngine(),
        16,
        (key, body) => _hmacSha256(key, body),
      );

  static Uint8List aesCbcHmacDecrypt(String password, List<int> data) =>
      _cbcHmacDecrypt(
        'ACB1',
        password,
        data,
        pc.AESEngine(),
        16,
        32,
        (key, body) => _hmacSha256(key, body),
      );

  static Uint8List sm4CbcHmacEncrypt(String password, List<int> data) =>
      _cbcHmacEncrypt(
        'S4C1',
        password,
        data,
        Sm4Engine(),
        16,
        (key, body) => _hmacSm3(key, body),
      );

  static Uint8List sm4CbcHmacDecrypt(String password, List<int> data) =>
      _cbcHmacDecrypt(
        'S4C1',
        password,
        data,
        Sm4Engine(),
        16,
        32,
        (key, body) => _hmacSm3(key, body),
      );

  static Uint8List aesCtrHmacEncrypt(String password, List<int> data) {
    final iv = randomBytes(16);
    final root = passwordKey(password);
    final cipher = pc.CTRStreamCipher(pc.AESEngine())
      ..init(
          true,
          pc.ParametersWithIV<pc.KeyParameter>(
              pc.KeyParameter(root.sublist(0, 16)), iv));
    final body = _pack('ACT1', iv, cipher.process(Uint8List.fromList(data)));
    return Uint8List.fromList(
        <int>[...body, ..._hmacSha256(root.sublist(16), body)]);
  }

  static Uint8List aesCtrHmacDecrypt(String password, List<int> data) {
    const tagLength = 32;
    final envelope = _unpack(data, 'ACT1', 16, minimumPayload: tagLength + 1);
    final body = Uint8List.fromList(data.sublist(0, data.length - tagLength));
    final tag = data.sublist(data.length - tagLength);
    final root = passwordKey(password);
    if (!_constantTimeEqual(tag, _hmacSha256(root.sublist(16), body))) {
      throw const FormatException('认证失败：密钥错误或密文已损坏');
    }
    final cipher = pc.CTRStreamCipher(pc.AESEngine())
      ..init(
          false,
          pc.ParametersWithIV<pc.KeyParameter>(
              pc.KeyParameter(root.sublist(0, 16)), envelope.nonce));
    return cipher.process(
        envelope.payload.sublist(0, envelope.payload.length - tagLength));
  }

  static Uint8List digest(pc.Digest digest, List<int> data) =>
      digest.process(Uint8List.fromList(data));

  static Uint8List hmacSha256(String password, List<int> data) =>
      _hmacSha256(passwordKey(password), Uint8List.fromList(data));

  static Uint8List hmacSha3(String password, List<int> data) =>
      _hmacSha3(passwordKey(password), Uint8List.fromList(data));

  static Uint8List hmacSm3(String password, List<int> data) =>
      _hmacSm3(passwordKey(password), Uint8List.fromList(data));

  static Uint8List pbkdf2(String password, List<int> data) {
    final salt = crypto.sha256
        .convert(
            utf8.encode('PBKDF2:${utf8.decode(data, allowMalformed: true)}'))
        .bytes
        .sublist(0, 16);
    final derivator =
        pc.PBKDF2KeyDerivator(pc.HMac.withDigest(pc.SHA256Digest()))
          ..init(pc.Pbkdf2Parameters(Uint8List.fromList(salt), 120000, 32));
    final out = Uint8List(32);
    derivator.deriveKey(Uint8List.fromList(utf8.encode(password)), 0, out, 0);
    return out;
  }

  static Uint8List scrypt(String password, List<int> data) {
    final salt =
        crypto.sha256.convert(Uint8List.fromList(data)).bytes.sublist(0, 16);
    final derivator = pc.Scrypt()
      ..init(pc.ScryptParameters(1 << 14, 8, 1, 32, Uint8List.fromList(salt)));
    final out = Uint8List(32);
    derivator.deriveKey(Uint8List.fromList(utf8.encode(password)), 0, out, 0);
    return out;
  }

  static Uint8List argon2id(String password, List<int> data) {
    final salt =
        crypto.sha256.convert(Uint8List.fromList(data)).bytes.sublist(0, 16);
    final derivator = pc.Argon2BytesGenerator()
      ..init(pc.Argon2Parameters(
        pc.Argon2Parameters.ARGON2_id,
        Uint8List.fromList(salt),
        desiredKeyLength: 32,
        iterations: 2,
        memoryPowerOf2: 12,
        lanes: 1,
      ));
    final out = Uint8List(32);
    derivator.deriveKey(Uint8List.fromList(utf8.encode(password)), 0, out, 0);
    return out;
  }

  static const _passwordAlphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  static const _passwordLength = 24;

  /// Builds valid key material for a mode. DES receives an eight-character
  /// generated secret; user supplied DES passwords may be any non-empty
  /// length. Password based modes take any non-empty secret, RSA needs a JWK
  /// style object with `n`, `e`, `d`, `p` and `q`, and ECDSA needs `d` plus the
  /// matching public point `q`.
  static String generateKeyForMode(String modeName) => switch (modeName) {
        'des' => _randomSecret(8, length: 8),
        'rsa' => _rsaKeyJson(),
        'ecdsa' => _ecdsaKeyJson(),
        _ => _randomSecret(_passwordLength),
      };

  static String _randomSecret(int byteLength, {int? length}) {
    final size = length ?? byteLength;
    final bytes = randomBytes(byteLength);
    return String.fromCharCodes(
      bytes.take(size).map((byte) =>
          _passwordAlphabet.codeUnitAt(byte % _passwordAlphabet.length)),
    );
  }

  static String _rsaKeyJson() {
    final generator = pc.RSAKeyGenerator()
      ..init(pc.ParametersWithRandom(
        pc.RSAKeyGeneratorParameters(BigInt.from(65537), 1024, 5),
        _secureRandom(),
      ));
    final pair = generator.generateKeyPair();
    final privateKey = pair.privateKey as pc.RSAPrivateKey;
    return jsonEncode({
      'n': privateKey.modulus.toString(),
      'e': privateKey.publicExponent.toString(),
      'd': privateKey.privateExponent.toString(),
      'p': privateKey.p.toString(),
      'q': privateKey.q.toString(),
    });
  }

  static String _ecdsaKeyJson() {
    final domain = pc.ECDomainParameters('secp256r1');
    final d = BigInt.one +
        (_bigIntFromBytes(randomBytes(32)) % (domain.n - BigInt.one));
    final privateKey = pc.ECPrivateKey(d, domain);
    final publicPoint = domain.G * d;
    return jsonEncode({
      'd': privateKey.d.toString(),
      'q': base64Encode(publicPoint!.getEncoded(false)),
    });
  }

  static BigInt _bigIntFromBytes(List<int> bytes) {
    var value = BigInt.zero;
    for (final byte in bytes) {
      value = (value << 8) | BigInt.from(byte & 0xff);
    }
    return value;
  }

  static pc.FortunaRandom _secureRandom() =>
      pc.FortunaRandom()..seed(pc.KeyParameter(randomBytes(32)));

  static Uint8List rsaOaepEncrypt(String keyJson, List<int> data) {
    final key = _rsaKey(keyJson, privateKey: false) as pc.RSAPublicKey;
    final cipher = pc.OAEPEncoding.withSHA256(pc.RSAEngine())
      ..init(true, pc.PublicKeyParameter<pc.RSAPublicKey>(key));
    try {
      return cipher.process(Uint8List.fromList(data));
    } catch (_) {
      throw const FormatException('RSA-OAEP 明文过长或公钥格式无效');
    }
  }

  static Uint8List rsaOaepDecrypt(String keyJson, List<int> data) {
    final key = _rsaKey(keyJson, privateKey: true) as pc.RSAPrivateKey;
    final cipher = pc.OAEPEncoding.withSHA256(pc.RSAEngine())
      ..init(false, pc.PrivateKeyParameter<pc.RSAPrivateKey>(key));
    try {
      return cipher.process(Uint8List.fromList(data));
    } catch (_) {
      throw const FormatException('RSA-OAEP 私钥或密文无效');
    }
  }

  static pc.RSAAsymmetricKey _rsaKey(String input, {required bool privateKey}) {
    final value = jsonDecode(input) as Map<String, dynamic>;
    final n = _bigInt(value['n']);
    final e = _bigInt(value['e']);
    if (!privateKey) return pc.RSAPublicKey(n, e);
    final d = _bigInt(value['d']);
    final p = _bigInt(value['p']);
    final q = _bigInt(value['q']);
    return pc.RSAPrivateKey(n, d, p, q);
  }

  static BigInt _bigInt(Object? value) {
    if (value is num) return BigInt.from(value);
    if (value is! String || value.isEmpty)
      throw const FormatException('密钥格式无效');
    final text = value.startsWith('0x') ? value.substring(2) : value;
    final radix =
        value.startsWith('0x') || RegExp(r'[a-fA-F]').hasMatch(text) ? 16 : 10;
    return BigInt.parse(text, radix: radix);
  }

  static Uint8List ecdsaSign(String keyJson, List<int> data) {
    final value = jsonDecode(keyJson) as Map<String, dynamic>;
    final domain = pc.ECDomainParameters('secp256r1');
    final privateKey = pc.ECPrivateKey(_bigInt(value['d']), domain);
    final signer =
        pc.ECDSASigner(pc.SHA256Digest(), pc.HMac.withDigest(pc.SHA256Digest()))
          ..init(true, pc.PrivateKeyParameter<pc.ECPrivateKey>(privateKey));
    final signature =
        signer.generateSignature(Uint8List.fromList(data)) as pc.ECSignature;
    return Uint8List.fromList(<int>[
      ..._fixedBigInt(signature.r, 32),
      ..._fixedBigInt(signature.s, 32),
    ]);
  }

  static bool ecdsaVerify(String keyJson, List<int> data, List<int> signature) {
    if (signature.length != 64) throw const FormatException('ECDSA 签名格式无效');
    final value = jsonDecode(keyJson) as Map<String, dynamic>;
    final domain = pc.ECDomainParameters('secp256r1');
    final encoded = value['q'] is String
        ? base64Decode(value['q'] as String)
        : _hexDecode(value['qHex'] as String);
    final publicKey = pc.ECPublicKey(domain.curve.decodePoint(encoded), domain);
    final signer =
        pc.ECDSASigner(pc.SHA256Digest(), pc.HMac.withDigest(pc.SHA256Digest()))
          ..init(false, pc.PublicKeyParameter<pc.ECPublicKey>(publicKey));
    final sig = pc.ECSignature(
      _fromBigEndian(signature.sublist(0, 32)),
      _fromBigEndian(signature.sublist(32)),
    );
    return signer.verifySignature(Uint8List.fromList(data), sig);
  }

  static List<int> _fixedBigInt(BigInt value, int length) {
    final bytes = _bigIntBytes(value);
    if (bytes.length > length) return bytes.sublist(bytes.length - length);
    return <int>[...List<int>.filled(length - bytes.length, 0), ...bytes];
  }

  static List<int> _bigIntBytes(BigInt value) {
    if (value == BigInt.zero) return <int>[0];
    final result = <int>[];
    var current = value;
    while (current > BigInt.zero) {
      result.insert(0, (current & BigInt.from(255)).toInt());
      current >>= 8;
    }
    return result;
  }

  static BigInt _fromBigEndian(List<int> bytes) {
    var value = BigInt.zero;
    for (final byte in bytes) value = (value << 8) | BigInt.from(byte & 0xff);
    return value;
  }

  static String base32Encode(List<int> data) {
    var buffer = 0;
    var bits = 0;
    final result = StringBuffer();
    for (final byte in data) {
      buffer = (buffer << 8) | byte;
      bits += 8;
      while (bits >= 5) {
        bits -= 5;
        result.write(_base32Alphabet[(buffer >> bits) & 31]);
      }
    }
    if (bits > 0) result.write(_base32Alphabet[(buffer << (5 - bits)) & 31]);
    while (result.length % 8 != 0) result.write('=');
    return result.toString();
  }

  static Uint8List base32Decode(String input) {
    final text =
        input.replaceAll('=', '').replaceAll(RegExp(r'\s+'), '').toUpperCase();
    var buffer = 0;
    var bits = 0;
    final output = <int>[];
    for (final char in text.split('')) {
      final value = _base32Alphabet.indexOf(char);
      if (value < 0) throw const FormatException('Base32 格式无效');
      buffer = (buffer << 5) | value;
      bits += 5;
      if (bits >= 8) {
        bits -= 8;
        output.add((buffer >> bits) & 0xff);
      }
    }
    return Uint8List.fromList(output);
  }

  static String base58Encode(List<int> data) {
    if (data.isEmpty) return '';
    var value = BigInt.zero;
    for (final byte in data) value = (value << 8) | BigInt.from(byte);
    final result = StringBuffer();
    while (value > BigInt.zero) {
      final remainder = (value % BigInt.from(58)).toInt();
      result.write(_base58Alphabet[remainder]);
      value ~/= BigInt.from(58);
    }
    for (final byte in data) {
      if (byte == 0)
        result.write('1');
      else
        break;
    }
    return result.toString().split('').reversed.join();
  }

  static Uint8List base58Decode(String input) {
    var value = BigInt.zero;
    for (final char in input.split('')) {
      final index = _base58Alphabet.indexOf(char);
      if (index < 0) throw const FormatException('Base58 格式无效');
      value = value * BigInt.from(58) + BigInt.from(index);
    }
    final bytes = _bigIntBytes(value);
    var leading = 0;
    while (leading < input.length && input[leading] == '1') leading++;
    return Uint8List.fromList(<int>[...List<int>.filled(leading, 0), ...bytes]);
  }

  static String utf16HexEncode(String text) {
    final bytes = <int>[];
    for (final unit in text.codeUnits) {
      bytes
        ..add((unit >> 8) & 0xff)
        ..add(unit & 0xff);
    }
    return _hex(bytes);
  }

  static String utf16HexDecode(String text) {
    final bytes = _hexDecode(text);
    if (bytes.length.isOdd) throw const FormatException('UTF-16 HEX 长度无效');
    final units = <int>[];
    for (var i = 0; i < bytes.length; i += 2)
      units.add((bytes[i] << 8) | bytes[i + 1]);
    return String.fromCharCodes(units);
  }

  static String _hex(List<int> bytes) {
    const digits = '0123456789ABCDEF';
    final out = StringBuffer();
    for (final byte in bytes)
      out
        ..write(digits[(byte >> 4) & 15])
        ..write(digits[byte & 15]);
    return out.toString();
  }

  static Uint8List _hexDecode(String input) {
    var text = input.trim();
    if (text.length.isOdd) text = '0$text';
    final out = Uint8List(text.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      final value = int.tryParse(text.substring(i * 2, i * 2 + 2), radix: 16);
      if (value == null) throw const FormatException('HEX 格式无效');
      out[i] = value;
    }
    return out;
  }
}
