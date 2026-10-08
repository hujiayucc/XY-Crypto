import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'legacy_gbk.dart';
import 'modern_crypto.dart';
import 'package:pointycastle/export.dart' as pc;

const _legacyModeCount = 80;
const _passwordKeyAlgorithms = <String>{
  'DES',
  'RC4',
  'AES-256-GCM',
  'ChaCha20-Poly1305',
  'XChaCha20-Poly1305',
  'SM4-GCM',
  'AES-CBC + HMAC-SHA256',
  'SM4-CBC + HMAC-SM3',
  'AES-CTR + HMAC-SHA256',
  'HMAC-SHA256',
  'HMAC-SHA3-256',
  'HMAC-SM3',
  'PBKDF2-HMAC-SHA256',
  'scrypt',
  'Argon2id',
};
const _encryptionAlgorithms = <String>{
  'DES',
  'RC4',
  'AES-256-GCM',
  'ChaCha20-Poly1305',
  'XChaCha20-Poly1305',
  'SM4-GCM',
  'AES-CBC + HMAC-SHA256',
  'SM4-CBC + HMAC-SM3',
  'AES-CTR + HMAC-SHA256',
  'RSA-OAEP-SHA256',
};
const _derivationAlgorithms = <String>{
  'PBKDF2-HMAC-SHA256',
  'scrypt',
  'Argon2id',
};
const _digestAlgorithms = <String>{
  'MD5',
  'SHA-256',
  'SHA-512',
  'SHA3-256',
  'BLAKE2b-512',
  'SM3',
};
const _uniformFormatLabels = <String>[
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

enum CryptoMode {
  hex('HEX'),
  base64('BASE64'),
  utf8Bytes('Byte[ ] (UTF-8)'),
  gbkBytes('Byte[ ] (GBK)'),
  unicode('UniCode'),
  desBase64('DES (BASE64)'),
  desHex('DES (HEX)'),
  desBytes('DES (Byte[ ])'),
  md5Upper32('MD5 (大写32位)'),
  md5Lower32('MD5 (小写32位)'),
  md5Upper16('MD5 (大写16位)'),
  md5Lower16('MD5 (小写16位)'),
  rc4Hex('RC4 (HEX)'),
  rc4Base64('RC4 (BASE64)'),
  rc4Bytes('RC4 (Byte[ ])'),
  aesGcmBase64('AES-256-GCM (BASE64)'),
  chacha20Poly1305Base64('ChaCha20-Poly1305 (BASE64)'),
  xchacha20Poly1305Base64('XChaCha20-Poly1305 (BASE64)'),
  sm4GcmBase64('SM4-GCM (BASE64)'),
  aesCbcHmacBase64('AES-CBC + HMAC-SHA256 (BASE64)'),
  sm4CbcHmacBase64('SM4-CBC + HMAC-SM3 (BASE64)'),
  aesCtrHmacBase64('AES-CTR + HMAC-SHA256 (BASE64)'),
  sha256Hex('SHA-256 (HEX)'),
  sha512Hex('SHA-512 (HEX)'),
  sha3_256Hex('SHA3-256 (HEX)'),
  blake2b512Hex('BLAKE2b-512 (HEX)'),
  sm3Hex('SM3 (HEX)'),
  hmacSha256Hex('HMAC-SHA256 (HEX)'),
  hmacSha3_256Hex('HMAC-SHA3-256 (HEX)'),
  hmacSm3Hex('HMAC-SM3 (HEX)'),
  pbkdf2Base64('PBKDF2-HMAC-SHA256 (BASE64)'),
  scryptBase64('scrypt (BASE64)'),
  argon2idBase64('Argon2id (BASE64)'),
  rsaOaepBase64('RSA-OAEP-SHA256 (BASE64)'),
  ecdsaSignBase64('ECDSA-SHA256 签名 (BASE64)'),
  base32('BASE32'),
  base58('BASE58'),
  urlEncode('URL Encode'),
  utf16Hex('UTF-16 (HEX)'),
  gb18030Bytes('Byte[ ] (GB18030/GBK兼容)'),
  aesGcmHex('AES-256-GCM (HEX)'),
  aesGcmBytes('AES-256-GCM (Byte[ ])'),
  chacha20Poly1305Hex('ChaCha20-Poly1305 (HEX)'),
  chacha20Poly1305Bytes('ChaCha20-Poly1305 (Byte[ ])'),
  xchacha20Poly1305Hex('XChaCha20-Poly1305 (HEX)'),
  xchacha20Poly1305Bytes('XChaCha20-Poly1305 (Byte[ ])'),
  sm4GcmHex('SM4-GCM (HEX)'),
  sm4GcmBytes('SM4-GCM (Byte[ ])'),
  aesCbcHmacHex('AES-CBC + HMAC-SHA256 (HEX)'),
  aesCbcHmacBytes('AES-CBC + HMAC-SHA256 (Byte[ ])'),
  sm4CbcHmacHex('SM4-CBC + HMAC-SM3 (HEX)'),
  sm4CbcHmacBytes('SM4-CBC + HMAC-SM3 (Byte[ ])'),
  aesCtrHmacHex('AES-CTR + HMAC-SHA256 (HEX)'),
  aesCtrHmacBytes('AES-CTR + HMAC-SHA256 (Byte[ ])'),
  pbkdf2Hex('PBKDF2-HMAC-SHA256 (HEX)'),
  pbkdf2Bytes('PBKDF2-HMAC-SHA256 (Byte[ ])'),
  scryptHex('scrypt (HEX)'),
  scryptBytes('scrypt (Byte[ ])'),
  argon2idHex('Argon2id (HEX)'),
  argon2idBytes('Argon2id (Byte[ ])'),
  rsaOaepHex('RSA-OAEP-SHA256 (HEX)'),
  rsaOaepBytes('RSA-OAEP-SHA256 (Byte[ ])'),
  ecdsaSignHex('ECDSA-SHA256 签名 (HEX)'),
  ecdsaSignBytes('ECDSA-SHA256 签名 (Byte[ ])'),
  sha256Base64('SHA-256 (BASE64)'),
  sha256Bytes('SHA-256 (Byte[ ])'),
  sha512Base64('SHA-512 (BASE64)'),
  sha512Bytes('SHA-512 (Byte[ ])'),
  sha3_256Base64('SHA3-256 (BASE64)'),
  sha3_256Bytes('SHA3-256 (Byte[ ])'),
  blake2b512Base64('BLAKE2b-512 (BASE64)'),
  blake2b512Bytes('BLAKE2b-512 (Byte[ ])'),
  sm3Base64('SM3 (BASE64)'),
  sm3Bytes('SM3 (Byte[ ])'),
  hmacSha256Base64('HMAC-SHA256 (BASE64)'),
  hmacSha256Bytes('HMAC-SHA256 (Byte[ ])'),
  hmacSha3_256Base64('HMAC-SHA3-256 (BASE64)'),
  hmacSha3_256Bytes('HMAC-SHA3-256 (Byte[ ])'),
  hmacSm3Base64('HMAC-SM3 (BASE64)'),
  hmacSm3Bytes('HMAC-SM3 (Byte[ ])'),
  aesGcmBase32('AES-256-GCM (BASE32)'),
  aesGcmBase58('AES-256-GCM (BASE58)'),
  aesGcmGb18030Bytes('AES-256-GCM (Byte[ ] (GB18030/GBK兼容))'),
  aesGcmGbkBytes('AES-256-GCM (Byte[ ] (GBK))'),
  aesGcmUnicode('AES-256-GCM (UniCode)'),
  aesGcmUrlEncode('AES-256-GCM (URL Encode)'),
  aesGcmUtf16Hex('AES-256-GCM (UTF-16 (HEX))'),
  aesCbcHmacBase32('AES-CBC + HMAC-SHA256 (BASE32)'),
  aesCbcHmacBase58('AES-CBC + HMAC-SHA256 (BASE58)'),
  aesCbcHmacGb18030Bytes('AES-CBC + HMAC-SHA256 (Byte[ ] (GB18030/GBK兼容))'),
  aesCbcHmacGbkBytes('AES-CBC + HMAC-SHA256 (Byte[ ] (GBK))'),
  aesCbcHmacUnicode('AES-CBC + HMAC-SHA256 (UniCode)'),
  aesCbcHmacUrlEncode('AES-CBC + HMAC-SHA256 (URL Encode)'),
  aesCbcHmacUtf16Hex('AES-CBC + HMAC-SHA256 (UTF-16 (HEX))'),
  aesCtrHmacBase32('AES-CTR + HMAC-SHA256 (BASE32)'),
  aesCtrHmacBase58('AES-CTR + HMAC-SHA256 (BASE58)'),
  aesCtrHmacGb18030Bytes('AES-CTR + HMAC-SHA256 (Byte[ ] (GB18030/GBK兼容))'),
  aesCtrHmacGbkBytes('AES-CTR + HMAC-SHA256 (Byte[ ] (GBK))'),
  aesCtrHmacUnicode('AES-CTR + HMAC-SHA256 (UniCode)'),
  aesCtrHmacUrlEncode('AES-CTR + HMAC-SHA256 (URL Encode)'),
  aesCtrHmacUtf16Hex('AES-CTR + HMAC-SHA256 (UTF-16 (HEX))'),
  argon2idBase32('Argon2id (BASE32)'),
  argon2idBase58('Argon2id (BASE58)'),
  argon2idGb18030Bytes('Argon2id (Byte[ ] (GB18030/GBK兼容))'),
  argon2idGbkBytes('Argon2id (Byte[ ] (GBK))'),
  argon2idUnicode('Argon2id (UniCode)'),
  argon2idUrlEncode('Argon2id (URL Encode)'),
  argon2idUtf16Hex('Argon2id (UTF-16 (HEX))'),
  blake2b512Base32('BLAKE2b-512 (BASE32)'),
  blake2b512Base58('BLAKE2b-512 (BASE58)'),
  blake2b512Gb18030Bytes('BLAKE2b-512 (Byte[ ] (GB18030/GBK兼容))'),
  blake2b512GbkBytes('BLAKE2b-512 (Byte[ ] (GBK))'),
  blake2b512Unicode('BLAKE2b-512 (UniCode)'),
  blake2b512UrlEncode('BLAKE2b-512 (URL Encode)'),
  blake2b512Utf16Hex('BLAKE2b-512 (UTF-16 (HEX))'),
  chacha20Poly1305Base32('ChaCha20-Poly1305 (BASE32)'),
  chacha20Poly1305Base58('ChaCha20-Poly1305 (BASE58)'),
  chacha20Poly1305Gb18030Bytes('ChaCha20-Poly1305 (Byte[ ] (GB18030/GBK兼容))'),
  chacha20Poly1305GbkBytes('ChaCha20-Poly1305 (Byte[ ] (GBK))'),
  chacha20Poly1305Unicode('ChaCha20-Poly1305 (UniCode)'),
  chacha20Poly1305UrlEncode('ChaCha20-Poly1305 (URL Encode)'),
  chacha20Poly1305Utf16Hex('ChaCha20-Poly1305 (UTF-16 (HEX))'),
  desBase32('DES (BASE32)'),
  desBase58('DES (BASE58)'),
  desGb18030Bytes('DES (Byte[ ] (GB18030/GBK兼容))'),
  desGbkBytes('DES (Byte[ ] (GBK))'),
  desUnicode('DES (UniCode)'),
  desUrlEncode('DES (URL Encode)'),
  desUtf16Hex('DES (UTF-16 (HEX))'),
  ecdsaSignBase32('ECDSA-SHA256 签名 (BASE32)'),
  ecdsaSignBase58('ECDSA-SHA256 签名 (BASE58)'),
  ecdsaSignGb18030Bytes('ECDSA-SHA256 签名 (Byte[ ] (GB18030/GBK兼容))'),
  ecdsaSignGbkBytes('ECDSA-SHA256 签名 (Byte[ ] (GBK))'),
  ecdsaSignUnicode('ECDSA-SHA256 签名 (UniCode)'),
  ecdsaSignUrlEncode('ECDSA-SHA256 签名 (URL Encode)'),
  ecdsaSignUtf16Hex('ECDSA-SHA256 签名 (UTF-16 (HEX))'),
  hmacSha256Base32('HMAC-SHA256 (BASE32)'),
  hmacSha256Base58('HMAC-SHA256 (BASE58)'),
  hmacSha256Gb18030Bytes('HMAC-SHA256 (Byte[ ] (GB18030/GBK兼容))'),
  hmacSha256GbkBytes('HMAC-SHA256 (Byte[ ] (GBK))'),
  hmacSha256Unicode('HMAC-SHA256 (UniCode)'),
  hmacSha256UrlEncode('HMAC-SHA256 (URL Encode)'),
  hmacSha256Utf16Hex('HMAC-SHA256 (UTF-16 (HEX))'),
  hmacSha3_256Base32('HMAC-SHA3-256 (BASE32)'),
  hmacSha3_256Base58('HMAC-SHA3-256 (BASE58)'),
  hmacSha3_256Gb18030Bytes('HMAC-SHA3-256 (Byte[ ] (GB18030/GBK兼容))'),
  hmacSha3_256GbkBytes('HMAC-SHA3-256 (Byte[ ] (GBK))'),
  hmacSha3_256Unicode('HMAC-SHA3-256 (UniCode)'),
  hmacSha3_256UrlEncode('HMAC-SHA3-256 (URL Encode)'),
  hmacSha3_256Utf16Hex('HMAC-SHA3-256 (UTF-16 (HEX))'),
  hmacSm3Base32('HMAC-SM3 (BASE32)'),
  hmacSm3Base58('HMAC-SM3 (BASE58)'),
  hmacSm3Gb18030Bytes('HMAC-SM3 (Byte[ ] (GB18030/GBK兼容))'),
  hmacSm3GbkBytes('HMAC-SM3 (Byte[ ] (GBK))'),
  hmacSm3Unicode('HMAC-SM3 (UniCode)'),
  hmacSm3UrlEncode('HMAC-SM3 (URL Encode)'),
  hmacSm3Utf16Hex('HMAC-SM3 (UTF-16 (HEX))'),
  pbkdf2Base32('PBKDF2-HMAC-SHA256 (BASE32)'),
  pbkdf2Base58('PBKDF2-HMAC-SHA256 (BASE58)'),
  pbkdf2Gb18030Bytes('PBKDF2-HMAC-SHA256 (Byte[ ] (GB18030/GBK兼容))'),
  pbkdf2GbkBytes('PBKDF2-HMAC-SHA256 (Byte[ ] (GBK))'),
  pbkdf2Unicode('PBKDF2-HMAC-SHA256 (UniCode)'),
  pbkdf2UrlEncode('PBKDF2-HMAC-SHA256 (URL Encode)'),
  pbkdf2Utf16Hex('PBKDF2-HMAC-SHA256 (UTF-16 (HEX))'),
  rc4Base32('RC4 (BASE32)'),
  rc4Base58('RC4 (BASE58)'),
  rc4Gb18030Bytes('RC4 (Byte[ ] (GB18030/GBK兼容))'),
  rc4GbkBytes('RC4 (Byte[ ] (GBK))'),
  rc4Unicode('RC4 (UniCode)'),
  rc4UrlEncode('RC4 (URL Encode)'),
  rc4Utf16Hex('RC4 (UTF-16 (HEX))'),
  rsaOaepBase32('RSA-OAEP-SHA256 (BASE32)'),
  rsaOaepBase58('RSA-OAEP-SHA256 (BASE58)'),
  rsaOaepGb18030Bytes('RSA-OAEP-SHA256 (Byte[ ] (GB18030/GBK兼容))'),
  rsaOaepGbkBytes('RSA-OAEP-SHA256 (Byte[ ] (GBK))'),
  rsaOaepUnicode('RSA-OAEP-SHA256 (UniCode)'),
  rsaOaepUrlEncode('RSA-OAEP-SHA256 (URL Encode)'),
  rsaOaepUtf16Hex('RSA-OAEP-SHA256 (UTF-16 (HEX))'),
  scryptBase32('scrypt (BASE32)'),
  scryptBase58('scrypt (BASE58)'),
  scryptGb18030Bytes('scrypt (Byte[ ] (GB18030/GBK兼容))'),
  scryptGbkBytes('scrypt (Byte[ ] (GBK))'),
  scryptUnicode('scrypt (UniCode)'),
  scryptUrlEncode('scrypt (URL Encode)'),
  scryptUtf16Hex('scrypt (UTF-16 (HEX))'),
  sha256Base32('SHA-256 (BASE32)'),
  sha256Base58('SHA-256 (BASE58)'),
  sha256Gb18030Bytes('SHA-256 (Byte[ ] (GB18030/GBK兼容))'),
  sha256GbkBytes('SHA-256 (Byte[ ] (GBK))'),
  sha256Unicode('SHA-256 (UniCode)'),
  sha256UrlEncode('SHA-256 (URL Encode)'),
  sha256Utf16Hex('SHA-256 (UTF-16 (HEX))'),
  sha512Base32('SHA-512 (BASE32)'),
  sha512Base58('SHA-512 (BASE58)'),
  sha512Gb18030Bytes('SHA-512 (Byte[ ] (GB18030/GBK兼容))'),
  sha512GbkBytes('SHA-512 (Byte[ ] (GBK))'),
  sha512Unicode('SHA-512 (UniCode)'),
  sha512UrlEncode('SHA-512 (URL Encode)'),
  sha512Utf16Hex('SHA-512 (UTF-16 (HEX))'),
  sha3_256Base32('SHA3-256 (BASE32)'),
  sha3_256Base58('SHA3-256 (BASE58)'),
  sha3_256Gb18030Bytes('SHA3-256 (Byte[ ] (GB18030/GBK兼容))'),
  sha3_256GbkBytes('SHA3-256 (Byte[ ] (GBK))'),
  sha3_256Unicode('SHA3-256 (UniCode)'),
  sha3_256UrlEncode('SHA3-256 (URL Encode)'),
  sha3_256Utf16Hex('SHA3-256 (UTF-16 (HEX))'),
  sm3Base32('SM3 (BASE32)'),
  sm3Base58('SM3 (BASE58)'),
  sm3Gb18030Bytes('SM3 (Byte[ ] (GB18030/GBK兼容))'),
  sm3GbkBytes('SM3 (Byte[ ] (GBK))'),
  sm3Unicode('SM3 (UniCode)'),
  sm3UrlEncode('SM3 (URL Encode)'),
  sm3Utf16Hex('SM3 (UTF-16 (HEX))'),
  sm4CbcHmacBase32('SM4-CBC + HMAC-SM3 (BASE32)'),
  sm4CbcHmacBase58('SM4-CBC + HMAC-SM3 (BASE58)'),
  sm4CbcHmacGb18030Bytes('SM4-CBC + HMAC-SM3 (Byte[ ] (GB18030/GBK兼容))'),
  sm4CbcHmacGbkBytes('SM4-CBC + HMAC-SM3 (Byte[ ] (GBK))'),
  sm4CbcHmacUnicode('SM4-CBC + HMAC-SM3 (UniCode)'),
  sm4CbcHmacUrlEncode('SM4-CBC + HMAC-SM3 (URL Encode)'),
  sm4CbcHmacUtf16Hex('SM4-CBC + HMAC-SM3 (UTF-16 (HEX))'),
  sm4GcmBase32('SM4-GCM (BASE32)'),
  sm4GcmBase58('SM4-GCM (BASE58)'),
  sm4GcmGb18030Bytes('SM4-GCM (Byte[ ] (GB18030/GBK兼容))'),
  sm4GcmGbkBytes('SM4-GCM (Byte[ ] (GBK))'),
  sm4GcmUnicode('SM4-GCM (UniCode)'),
  sm4GcmUrlEncode('SM4-GCM (URL Encode)'),
  sm4GcmUtf16Hex('SM4-GCM (UTF-16 (HEX))'),
  xchacha20Poly1305Base32('XChaCha20-Poly1305 (BASE32)'),
  xchacha20Poly1305Base58('XChaCha20-Poly1305 (BASE58)'),
  xchacha20Poly1305Gb18030Bytes('XChaCha20-Poly1305 (Byte[ ] (GB18030/GBK兼容))'),
  xchacha20Poly1305GbkBytes('XChaCha20-Poly1305 (Byte[ ] (GBK))'),
  xchacha20Poly1305Unicode('XChaCha20-Poly1305 (UniCode)'),
  xchacha20Poly1305UrlEncode('XChaCha20-Poly1305 (URL Encode)'),
  xchacha20Poly1305Utf16Hex('XChaCha20-Poly1305 (UTF-16 (HEX))'),
  md5Base32('MD5 (BASE32)'),
  md5Base58('MD5 (BASE58)'),
  md5Base64('MD5 (BASE64)'),
  md5Gb18030Bytes('MD5 (Byte[ ] (GB18030/GBK兼容))'),
  md5GbkBytes('MD5 (Byte[ ] (GBK))'),
  md5Utf8Bytes('MD5 (Byte[ ] (UTF-8))'),
  md5Hex('MD5 (HEX)'),
  md5Unicode('MD5 (UniCode)'),
  md5UrlEncode('MD5 (URL Encode)'),
  md5Utf16Hex('MD5 (UTF-16 (HEX))'),
  aesGcmUtf8Bytes('AES-256-GCM (Byte[ ] (UTF-8))'),
  aesCbcHmacUtf8Bytes('AES-CBC + HMAC-SHA256 (Byte[ ] (UTF-8))'),
  aesCtrHmacUtf8Bytes('AES-CTR + HMAC-SHA256 (Byte[ ] (UTF-8))'),
  argon2idUtf8Bytes('Argon2id (Byte[ ] (UTF-8))'),
  blake2b512Utf8Bytes('BLAKE2b-512 (Byte[ ] (UTF-8))'),
  chacha20Poly1305Utf8Bytes('ChaCha20-Poly1305 (Byte[ ] (UTF-8))'),
  desUtf8Bytes('DES (Byte[ ] (UTF-8))'),
  ecdsaSignUtf8Bytes('ECDSA-SHA256 签名 (Byte[ ] (UTF-8))'),
  hmacSha256Utf8Bytes('HMAC-SHA256 (Byte[ ] (UTF-8))'),
  hmacSha3_256Utf8Bytes('HMAC-SHA3-256 (Byte[ ] (UTF-8))'),
  hmacSm3Utf8Bytes('HMAC-SM3 (Byte[ ] (UTF-8))'),
  pbkdf2Utf8Bytes('PBKDF2-HMAC-SHA256 (Byte[ ] (UTF-8))'),
  rc4Utf8Bytes('RC4 (Byte[ ] (UTF-8))'),
  rsaOaepUtf8Bytes('RSA-OAEP-SHA256 (Byte[ ] (UTF-8))'),
  scryptUtf8Bytes('scrypt (Byte[ ] (UTF-8))'),
  sha256Utf8Bytes('SHA-256 (Byte[ ] (UTF-8))'),
  sha512Utf8Bytes('SHA-512 (Byte[ ] (UTF-8))'),
  sha3_256Utf8Bytes('SHA3-256 (Byte[ ] (UTF-8))'),
  sm3Utf8Bytes('SM3 (Byte[ ] (UTF-8))'),
  sm4CbcHmacUtf8Bytes('SM4-CBC + HMAC-SM3 (Byte[ ] (UTF-8))'),
  sm4GcmUtf8Bytes('SM4-GCM (Byte[ ] (UTF-8))'),
  xchacha20Poly1305Utf8Bytes('XChaCha20-Poly1305 (Byte[ ] (UTF-8))');

  const CryptoMode(this.label);
  final String label;

  bool get needsDesKey => algorithmLabel == 'DES';

  bool get needsRc4Key => algorithmLabel == 'RC4';

  bool get needsAesGcmKey => algorithmLabel == 'AES-256-GCM';

  bool get needsPasswordKey => _passwordKeyAlgorithms.contains(algorithmLabel);

  bool get needsKey =>
      needsPasswordKey ||
      algorithmLabel == 'RSA-OAEP-SHA256' ||
      algorithmLabel == 'ECDSA-SHA256 签名';

  bool get isDigest => switch (operationSpec.kind) {
        CryptoOperationKind.digest ||
        CryptoOperationKind.keyedDigest ||
        CryptoOperationKind.derivation ||
        CryptoOperationKind.signature =>
          true,
        _ => false,
      };

  String get oneWayErrorMessage {
    final algorithm = algorithmLabel;
    if (algorithm == 'ECDSA-SHA256 签名') {
      return '$algorithm 是单向签名，仅支持生成签名';
    }
    if (algorithm == 'PBKDF2-HMAC-SHA256' ||
        algorithm == 'scrypt' ||
        algorithm == 'Argon2id') {
      return '$algorithm 是单向密钥派生，仅支持生成结果';
    }
    if (algorithm.startsWith('HMAC-')) {
      return '$algorithm 是带密钥的单向摘要，仅支持生成摘要';
    }
    return '$algorithm 是单向摘要，仅支持生成摘要';
  }
}

enum CryptoOperationKind {
  conversion,
  encryption,
  digest,
  keyedDigest,
  derivation,
  signature,
}

class CryptoOperationSpec {
  const CryptoOperationSpec({
    required this.kind,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.description,
  });

  final CryptoOperationKind kind;
  final String primaryLabel;
  final String? secondaryLabel;
  final String description;

  bool get supportsSecondary => secondaryLabel != null;
}

class CryptoAlgorithmChoice {
  const CryptoAlgorithmChoice(this.label, this.modes);

  final String label;
  final List<CryptoMode> modes;
}

const _legacyCryptoAlgorithmChoices = <CryptoAlgorithmChoice>[
  CryptoAlgorithmChoice('AES-256-GCM', [
    CryptoMode.aesGcmBase32,
    CryptoMode.aesGcmBase58,
    CryptoMode.aesGcmBase64,
    CryptoMode.aesGcmGb18030Bytes,
    CryptoMode.aesGcmGbkBytes,
    CryptoMode.aesGcmUtf8Bytes,
    CryptoMode.aesGcmHex,
    CryptoMode.aesGcmUnicode,
    CryptoMode.aesGcmUrlEncode,
    CryptoMode.aesGcmUtf16Hex,
  ]),
  CryptoAlgorithmChoice('AES-CBC + HMAC-SHA256', [
    CryptoMode.aesCbcHmacBase32,
    CryptoMode.aesCbcHmacBase58,
    CryptoMode.aesCbcHmacBase64,
    CryptoMode.aesCbcHmacGb18030Bytes,
    CryptoMode.aesCbcHmacGbkBytes,
    CryptoMode.aesCbcHmacUtf8Bytes,
    CryptoMode.aesCbcHmacHex,
    CryptoMode.aesCbcHmacUnicode,
    CryptoMode.aesCbcHmacUrlEncode,
    CryptoMode.aesCbcHmacUtf16Hex,
  ]),
  CryptoAlgorithmChoice('AES-CTR + HMAC-SHA256', [
    CryptoMode.aesCtrHmacBase32,
    CryptoMode.aesCtrHmacBase58,
    CryptoMode.aesCtrHmacBase64,
    CryptoMode.aesCtrHmacGb18030Bytes,
    CryptoMode.aesCtrHmacGbkBytes,
    CryptoMode.aesCtrHmacUtf8Bytes,
    CryptoMode.aesCtrHmacHex,
    CryptoMode.aesCtrHmacUnicode,
    CryptoMode.aesCtrHmacUrlEncode,
    CryptoMode.aesCtrHmacUtf16Hex,
  ]),
  CryptoAlgorithmChoice('Argon2id', [
    CryptoMode.argon2idBase32,
    CryptoMode.argon2idBase58,
    CryptoMode.argon2idBase64,
    CryptoMode.argon2idGb18030Bytes,
    CryptoMode.argon2idGbkBytes,
    CryptoMode.argon2idUtf8Bytes,
    CryptoMode.argon2idHex,
    CryptoMode.argon2idUnicode,
    CryptoMode.argon2idUrlEncode,
    CryptoMode.argon2idUtf16Hex,
  ]),
  CryptoAlgorithmChoice('BLAKE2b-512', [
    CryptoMode.blake2b512Base32,
    CryptoMode.blake2b512Base58,
    CryptoMode.blake2b512Base64,
    CryptoMode.blake2b512Gb18030Bytes,
    CryptoMode.blake2b512GbkBytes,
    CryptoMode.blake2b512Utf8Bytes,
    CryptoMode.blake2b512Hex,
    CryptoMode.blake2b512Unicode,
    CryptoMode.blake2b512UrlEncode,
    CryptoMode.blake2b512Utf16Hex,
  ]),
  CryptoAlgorithmChoice('ChaCha20-Poly1305', [
    CryptoMode.chacha20Poly1305Base32,
    CryptoMode.chacha20Poly1305Base58,
    CryptoMode.chacha20Poly1305Base64,
    CryptoMode.chacha20Poly1305Gb18030Bytes,
    CryptoMode.chacha20Poly1305GbkBytes,
    CryptoMode.chacha20Poly1305Utf8Bytes,
    CryptoMode.chacha20Poly1305Hex,
    CryptoMode.chacha20Poly1305Unicode,
    CryptoMode.chacha20Poly1305UrlEncode,
    CryptoMode.chacha20Poly1305Utf16Hex,
  ]),
  CryptoAlgorithmChoice('DES', [
    CryptoMode.desBase32,
    CryptoMode.desBase58,
    CryptoMode.desBase64,
    CryptoMode.desGb18030Bytes,
    CryptoMode.desGbkBytes,
    CryptoMode.desUtf8Bytes,
    CryptoMode.desHex,
    CryptoMode.desUnicode,
    CryptoMode.desUrlEncode,
    CryptoMode.desUtf16Hex,
  ]),
  CryptoAlgorithmChoice('ECDSA-SHA256 签名', [
    CryptoMode.ecdsaSignBase32,
    CryptoMode.ecdsaSignBase58,
    CryptoMode.ecdsaSignBase64,
    CryptoMode.ecdsaSignGb18030Bytes,
    CryptoMode.ecdsaSignGbkBytes,
    CryptoMode.ecdsaSignUtf8Bytes,
    CryptoMode.ecdsaSignHex,
    CryptoMode.ecdsaSignUnicode,
    CryptoMode.ecdsaSignUrlEncode,
    CryptoMode.ecdsaSignUtf16Hex,
  ]),
  CryptoAlgorithmChoice('HMAC-SHA256', [
    CryptoMode.hmacSha256Base32,
    CryptoMode.hmacSha256Base58,
    CryptoMode.hmacSha256Base64,
    CryptoMode.hmacSha256Gb18030Bytes,
    CryptoMode.hmacSha256GbkBytes,
    CryptoMode.hmacSha256Utf8Bytes,
    CryptoMode.hmacSha256Hex,
    CryptoMode.hmacSha256Unicode,
    CryptoMode.hmacSha256UrlEncode,
    CryptoMode.hmacSha256Utf16Hex,
  ]),
  CryptoAlgorithmChoice('HMAC-SHA3-256', [
    CryptoMode.hmacSha3_256Base32,
    CryptoMode.hmacSha3_256Base58,
    CryptoMode.hmacSha3_256Base64,
    CryptoMode.hmacSha3_256Gb18030Bytes,
    CryptoMode.hmacSha3_256GbkBytes,
    CryptoMode.hmacSha3_256Utf8Bytes,
    CryptoMode.hmacSha3_256Hex,
    CryptoMode.hmacSha3_256Unicode,
    CryptoMode.hmacSha3_256UrlEncode,
    CryptoMode.hmacSha3_256Utf16Hex,
  ]),
  CryptoAlgorithmChoice('HMAC-SM3', [
    CryptoMode.hmacSm3Base32,
    CryptoMode.hmacSm3Base58,
    CryptoMode.hmacSm3Base64,
    CryptoMode.hmacSm3Gb18030Bytes,
    CryptoMode.hmacSm3GbkBytes,
    CryptoMode.hmacSm3Utf8Bytes,
    CryptoMode.hmacSm3Hex,
    CryptoMode.hmacSm3Unicode,
    CryptoMode.hmacSm3UrlEncode,
    CryptoMode.hmacSm3Utf16Hex,
  ]),
  CryptoAlgorithmChoice('MD5', [
    CryptoMode.md5Base32,
    CryptoMode.md5Base58,
    CryptoMode.md5Base64,
    CryptoMode.md5Gb18030Bytes,
    CryptoMode.md5GbkBytes,
    CryptoMode.md5Utf8Bytes,
    CryptoMode.md5Hex,
    CryptoMode.md5Unicode,
    CryptoMode.md5UrlEncode,
    CryptoMode.md5Utf16Hex,
  ]),
  CryptoAlgorithmChoice('PBKDF2-HMAC-SHA256', [
    CryptoMode.pbkdf2Base32,
    CryptoMode.pbkdf2Base58,
    CryptoMode.pbkdf2Base64,
    CryptoMode.pbkdf2Gb18030Bytes,
    CryptoMode.pbkdf2GbkBytes,
    CryptoMode.pbkdf2Utf8Bytes,
    CryptoMode.pbkdf2Hex,
    CryptoMode.pbkdf2Unicode,
    CryptoMode.pbkdf2UrlEncode,
    CryptoMode.pbkdf2Utf16Hex,
  ]),
  CryptoAlgorithmChoice('RC4', [
    CryptoMode.rc4Base32,
    CryptoMode.rc4Base58,
    CryptoMode.rc4Base64,
    CryptoMode.rc4Gb18030Bytes,
    CryptoMode.rc4GbkBytes,
    CryptoMode.rc4Utf8Bytes,
    CryptoMode.rc4Hex,
    CryptoMode.rc4Unicode,
    CryptoMode.rc4UrlEncode,
    CryptoMode.rc4Utf16Hex,
  ]),
  CryptoAlgorithmChoice('RSA-OAEP-SHA256', [
    CryptoMode.rsaOaepBase32,
    CryptoMode.rsaOaepBase58,
    CryptoMode.rsaOaepBase64,
    CryptoMode.rsaOaepGb18030Bytes,
    CryptoMode.rsaOaepGbkBytes,
    CryptoMode.rsaOaepUtf8Bytes,
    CryptoMode.rsaOaepHex,
    CryptoMode.rsaOaepUnicode,
    CryptoMode.rsaOaepUrlEncode,
    CryptoMode.rsaOaepUtf16Hex,
  ]),
  CryptoAlgorithmChoice('scrypt', [
    CryptoMode.scryptBase32,
    CryptoMode.scryptBase58,
    CryptoMode.scryptBase64,
    CryptoMode.scryptGb18030Bytes,
    CryptoMode.scryptGbkBytes,
    CryptoMode.scryptUtf8Bytes,
    CryptoMode.scryptHex,
    CryptoMode.scryptUnicode,
    CryptoMode.scryptUrlEncode,
    CryptoMode.scryptUtf16Hex,
  ]),
  CryptoAlgorithmChoice('SHA-256', [
    CryptoMode.sha256Base32,
    CryptoMode.sha256Base58,
    CryptoMode.sha256Base64,
    CryptoMode.sha256Gb18030Bytes,
    CryptoMode.sha256GbkBytes,
    CryptoMode.sha256Utf8Bytes,
    CryptoMode.sha256Hex,
    CryptoMode.sha256Unicode,
    CryptoMode.sha256UrlEncode,
    CryptoMode.sha256Utf16Hex,
  ]),
  CryptoAlgorithmChoice('SHA-512', [
    CryptoMode.sha512Base32,
    CryptoMode.sha512Base58,
    CryptoMode.sha512Base64,
    CryptoMode.sha512Gb18030Bytes,
    CryptoMode.sha512GbkBytes,
    CryptoMode.sha512Utf8Bytes,
    CryptoMode.sha512Hex,
    CryptoMode.sha512Unicode,
    CryptoMode.sha512UrlEncode,
    CryptoMode.sha512Utf16Hex,
  ]),
  CryptoAlgorithmChoice('SHA3-256', [
    CryptoMode.sha3_256Base32,
    CryptoMode.sha3_256Base58,
    CryptoMode.sha3_256Base64,
    CryptoMode.sha3_256Gb18030Bytes,
    CryptoMode.sha3_256GbkBytes,
    CryptoMode.sha3_256Utf8Bytes,
    CryptoMode.sha3_256Hex,
    CryptoMode.sha3_256Unicode,
    CryptoMode.sha3_256UrlEncode,
    CryptoMode.sha3_256Utf16Hex,
  ]),
  CryptoAlgorithmChoice('SM3', [
    CryptoMode.sm3Base32,
    CryptoMode.sm3Base58,
    CryptoMode.sm3Base64,
    CryptoMode.sm3Gb18030Bytes,
    CryptoMode.sm3GbkBytes,
    CryptoMode.sm3Utf8Bytes,
    CryptoMode.sm3Hex,
    CryptoMode.sm3Unicode,
    CryptoMode.sm3UrlEncode,
    CryptoMode.sm3Utf16Hex,
  ]),
  CryptoAlgorithmChoice('SM4-CBC + HMAC-SM3', [
    CryptoMode.sm4CbcHmacBase32,
    CryptoMode.sm4CbcHmacBase58,
    CryptoMode.sm4CbcHmacBase64,
    CryptoMode.sm4CbcHmacGb18030Bytes,
    CryptoMode.sm4CbcHmacGbkBytes,
    CryptoMode.sm4CbcHmacUtf8Bytes,
    CryptoMode.sm4CbcHmacHex,
    CryptoMode.sm4CbcHmacUnicode,
    CryptoMode.sm4CbcHmacUrlEncode,
    CryptoMode.sm4CbcHmacUtf16Hex,
  ]),
  CryptoAlgorithmChoice('SM4-GCM', [
    CryptoMode.sm4GcmBase32,
    CryptoMode.sm4GcmBase58,
    CryptoMode.sm4GcmBase64,
    CryptoMode.sm4GcmGb18030Bytes,
    CryptoMode.sm4GcmGbkBytes,
    CryptoMode.sm4GcmUtf8Bytes,
    CryptoMode.sm4GcmHex,
    CryptoMode.sm4GcmUnicode,
    CryptoMode.sm4GcmUrlEncode,
    CryptoMode.sm4GcmUtf16Hex,
  ]),
  CryptoAlgorithmChoice('XChaCha20-Poly1305', [
    CryptoMode.xchacha20Poly1305Base32,
    CryptoMode.xchacha20Poly1305Base58,
    CryptoMode.xchacha20Poly1305Base64,
    CryptoMode.xchacha20Poly1305Gb18030Bytes,
    CryptoMode.xchacha20Poly1305GbkBytes,
    CryptoMode.xchacha20Poly1305Utf8Bytes,
    CryptoMode.xchacha20Poly1305Hex,
    CryptoMode.xchacha20Poly1305Unicode,
    CryptoMode.xchacha20Poly1305UrlEncode,
    CryptoMode.xchacha20Poly1305Utf16Hex,
  ]),
  CryptoAlgorithmChoice('编码转换', [
    CryptoMode.base32,
    CryptoMode.base58,
    CryptoMode.base64,
    CryptoMode.gb18030Bytes,
    CryptoMode.gbkBytes,
    CryptoMode.utf8Bytes,
    CryptoMode.hex,
    CryptoMode.unicode,
    CryptoMode.urlEncode,
    CryptoMode.utf16Hex,
  ]),
];

const _legacyModeAliases = <CryptoAlgorithmChoice>[
  CryptoAlgorithmChoice('MD5', [
    CryptoMode.md5Upper16,
    CryptoMode.md5Upper32,
    CryptoMode.md5Lower16,
    CryptoMode.md5Lower32,
  ]),
];

final List<CryptoAlgorithmChoice> cryptoAlgorithmChoices =
    List.unmodifiable(_legacyCryptoAlgorithmChoices);

CryptoAlgorithmChoice _choiceForMode(CryptoMode mode) {
  if (mode.index < _legacyModeCount) {
    for (final choice in _legacyCryptoAlgorithmChoices) {
      if (choice.modes.contains(mode)) return choice;
    }
  }
  for (final choice in _legacyCryptoAlgorithmChoices) {
    if (choice.modes.contains(mode)) return choice;
  }
  for (final choice in _legacyModeAliases) {
    if (choice.modes.contains(mode)) return choice;
  }
  final label = mode.label;
  if (const {
    'HEX',
    'BASE64',
    'Byte[ ] (UTF-8)',
    'Byte[ ] (GBK)',
    'Byte[ ] (GB18030/GBK兼容)',
    'UniCode',
    'BASE32',
    'BASE58',
    'URL Encode',
    'UTF-16 (HEX)',
  }.contains(label)) {
    return _legacyCryptoAlgorithmChoices.firstWhere(
      (choice) => choice.label == '编码转换',
    );
  }
  final open = label.indexOf(' (');
  final algorithm = open < 0 ? label : label.substring(0, open);
  return _legacyCryptoAlgorithmChoices.firstWhere(
    (choice) => choice.label == algorithm,
    orElse: () => _legacyModeAliases.firstWhere(
      (choice) => choice.label == algorithm,
      orElse: () => throw StateError('未注册的加密模式: ${mode.label}'),
    ),
  );
}

extension CryptoModePresentation on CryptoMode {
  String get algorithmLabel => _choiceForMode(this).label;
  CryptoOperationSpec get operationSpec {
    final algorithm = algorithmLabel;
    if (algorithm == '编码转换') {
      return const CryptoOperationSpec(
        kind: CryptoOperationKind.conversion,
        primaryLabel: '编码',
        secondaryLabel: '解码',
        description: '在文本与二进制表示之间转换',
      );
    }
    if (_encryptionAlgorithms.contains(algorithm)) {
      return const CryptoOperationSpec(
        kind: CryptoOperationKind.encryption,
        primaryLabel: '加密',
        secondaryLabel: '解密',
        description: '可逆处理，使用相同密钥或密钥对恢复内容',
      );
    }
    if (algorithm.startsWith('HMAC-')) {
      return const CryptoOperationSpec(
        kind: CryptoOperationKind.keyedDigest,
        primaryLabel: '生成 HMAC',
        secondaryLabel: null,
        description: '带密钥的单向摘要，生成结果后不支持反向还原',
      );
    }
    if (_derivationAlgorithms.contains(algorithm)) {
      return const CryptoOperationSpec(
        kind: CryptoOperationKind.derivation,
        primaryLabel: '生成派生结果',
        secondaryLabel: null,
        description: '单向密钥派生，生成结果后不支持反向还原',
      );
    }
    if (algorithm == 'ECDSA-SHA256 签名') {
      return const CryptoOperationSpec(
        kind: CryptoOperationKind.signature,
        primaryLabel: '生成签名',
        secondaryLabel: null,
        description: '数字签名，生成签名后不支持反向还原',
      );
    }
    if (_digestAlgorithms.contains(algorithm)) {
      return const CryptoOperationSpec(
        kind: CryptoOperationKind.digest,
        primaryLabel: '生成摘要',
        secondaryLabel: null,
        description: '单向摘要，生成结果后不支持反向还原',
      );
    }
    throw StateError('未注册的操作类型: $algorithm');
  }

  String get formatLabel {
    final label = this == CryptoMode.utf8Bytes
        ? 'Byte[ ] (UTF-8)'
        : this == CryptoMode.gbkBytes
            ? 'Byte[ ] (GBK)'
            : this == CryptoMode.gb18030Bytes
                ? 'Byte[ ] (GB18030/GBK兼容)'
                : this == CryptoMode.md5Upper32
                    ? '大写32位'
                    : this == CryptoMode.md5Lower32
                        ? '小写32位'
                        : this == CryptoMode.md5Upper16
                            ? '大写16位'
                            : this == CryptoMode.md5Lower16
                                ? '小写16位'
                                : algorithmLabel == '编码转换'
                                    ? this.label
                                    : this.label.substring(
                                          this.label.indexOf('(') + 1,
                                          this.label.lastIndexOf(')'),
                                        );
    return label;
  }
}

class CryptoEngine {
  static String transform({
    required String input,
    required CryptoMode mode,
    required bool encode,
    String key = '',
  }) {
    if (input.isEmpty) return '';
    if (mode.isDigest && !encode) {
      throw FormatException(mode.oneWayErrorMessage);
    }

    try {
      if (encode) {
        return _encode(input, mode, key);
      }
      return _decode(input, mode, key);
    } on FormatException {
      rethrow;
    } catch (error) {
      throw FormatException('Error: $error');
    }
  }

  /// Creates random key material valid for the selected mode.
  ///
  /// DES modes receive a generated eight-character secret. User supplied DES
  /// passwords may use any non-empty length and are derived to DES key bytes;
  /// RC4, AES-GCM, HMAC and KDF modes receive a 24 character secret,
  /// RSA-OAEP receives a 1024 bit JWK style key pair and ECDSA receives a
  /// secp256r1 private key with its matching public point.
  static String generateKey(CryptoMode mode) {
    if (!mode.needsKey) {
      throw const FormatException('该模式无需密钥');
    }
    if (mode.needsDesKey) return ModernCrypto.generateKeyForMode('des');
    if (mode.algorithmLabel == 'RSA-OAEP-SHA256') {
      return ModernCrypto.generateKeyForMode('rsa');
    }
    if (mode.algorithmLabel == 'ECDSA-SHA256 签名') {
      return ModernCrypto.generateKeyForMode('ecdsa');
    }
    return ModernCrypto.generateKeyForMode('password');
  }

  static String _encode(String input, CryptoMode mode, String key) {
    switch (mode) {
      case CryptoMode.hex:
        return _hexEncode(Uint8List.fromList(utf8.encode(input)));
      case CryptoMode.base64:
        return base64Encode(utf8.encode(input));
      case CryptoMode.utf8Bytes:
        return _arrayToString(utf8.encode(input));
      case CryptoMode.gbkBytes:
        return _arrayToString(LegacyGbk.encode(input));
      case CryptoMode.unicode:
        return input.codeUnits
            .map((unit) => '\\u${unit.toRadixString(16)}')
            .join();
      case CryptoMode.desBase64:
        return base64Encode(_desCrypt(
          Uint8List.fromList(utf8.encode(input)),
          key,
          encrypt: true,
        ));
      case CryptoMode.desHex:
        return _hexEncode(_desCrypt(
          Uint8List.fromList(utf8.encode(input)),
          key,
          encrypt: true,
        ));
      case CryptoMode.desBytes:
        return _arrayToString(_desCrypt(
          Uint8List.fromList(utf8.encode(input)),
          key,
          encrypt: true,
        ));
      case CryptoMode.md5Upper32:
        return _md5(input).toUpperCase();
      case CryptoMode.md5Lower32:
        return _md5(input).toLowerCase();
      case CryptoMode.md5Upper16:
        return _md5(input).substring(8, 24).toUpperCase();
      case CryptoMode.md5Lower16:
        return _md5(input).substring(8, 24).toLowerCase();
      case CryptoMode.rc4Hex:
        return _hexEncode(_rc4(utf8.encode(input), key));
      case CryptoMode.rc4Base64:
        return base64Encode(_rc4(utf8.encode(input), key));
      case CryptoMode.rc4Bytes:
        return _arrayToString(_rc4(utf8.encode(input), key));
      case CryptoMode.aesGcmBase64:
        return base64Encode(_aesGcmEncrypt(utf8.encode(input), key));
      case CryptoMode.aesGcmHex:
        return _hexEncode(_aesGcmEncrypt(utf8.encode(input), key));
      case CryptoMode.aesGcmBytes:
        return _arrayToString(_aesGcmEncrypt(utf8.encode(input), key));
      case CryptoMode.chacha20Poly1305Base64:
        return _modernEncoded(
          ModernCrypto.chacha20Poly1305Encrypt(key, utf8.encode(input)),
          'BASE64',
        );
      case CryptoMode.chacha20Poly1305Hex:
        return _modernEncoded(
          ModernCrypto.chacha20Poly1305Encrypt(key, utf8.encode(input)),
          'HEX',
        );
      case CryptoMode.chacha20Poly1305Bytes:
        return _modernEncoded(
          ModernCrypto.chacha20Poly1305Encrypt(key, utf8.encode(input)),
          'BYTES',
        );
      case CryptoMode.xchacha20Poly1305Base64:
        return _modernEncoded(
          ModernCrypto.xChaCha20Poly1305Encrypt(key, utf8.encode(input)),
          'BASE64',
        );
      case CryptoMode.xchacha20Poly1305Hex:
        return _modernEncoded(
          ModernCrypto.xChaCha20Poly1305Encrypt(key, utf8.encode(input)),
          'HEX',
        );
      case CryptoMode.xchacha20Poly1305Bytes:
        return _modernEncoded(
          ModernCrypto.xChaCha20Poly1305Encrypt(key, utf8.encode(input)),
          'BYTES',
        );
      case CryptoMode.sm4GcmBase64:
        return _modernEncoded(
            ModernCrypto.sm4GcmEncrypt(key, utf8.encode(input)), 'BASE64');
      case CryptoMode.sm4GcmHex:
        return _modernEncoded(
            ModernCrypto.sm4GcmEncrypt(key, utf8.encode(input)), 'HEX');
      case CryptoMode.sm4GcmBytes:
        return _modernEncoded(
            ModernCrypto.sm4GcmEncrypt(key, utf8.encode(input)), 'BYTES');
      case CryptoMode.aesCbcHmacBase64:
        return _modernEncoded(
          ModernCrypto.aesCbcHmacEncrypt(key, utf8.encode(input)),
          'BASE64',
        );
      case CryptoMode.aesCbcHmacHex:
        return _modernEncoded(
          ModernCrypto.aesCbcHmacEncrypt(key, utf8.encode(input)),
          'HEX',
        );
      case CryptoMode.aesCbcHmacBytes:
        return _modernEncoded(
          ModernCrypto.aesCbcHmacEncrypt(key, utf8.encode(input)),
          'BYTES',
        );
      case CryptoMode.sm4CbcHmacBase64:
        return _modernEncoded(
          ModernCrypto.sm4CbcHmacEncrypt(key, utf8.encode(input)),
          'BASE64',
        );
      case CryptoMode.sm4CbcHmacHex:
        return _modernEncoded(
          ModernCrypto.sm4CbcHmacEncrypt(key, utf8.encode(input)),
          'HEX',
        );
      case CryptoMode.sm4CbcHmacBytes:
        return _modernEncoded(
          ModernCrypto.sm4CbcHmacEncrypt(key, utf8.encode(input)),
          'BYTES',
        );
      case CryptoMode.aesCtrHmacBase64:
        return _modernEncoded(
          ModernCrypto.aesCtrHmacEncrypt(key, utf8.encode(input)),
          'BASE64',
        );
      case CryptoMode.aesCtrHmacHex:
        return _modernEncoded(
          ModernCrypto.aesCtrHmacEncrypt(key, utf8.encode(input)),
          'HEX',
        );
      case CryptoMode.aesCtrHmacBytes:
        return _modernEncoded(
          ModernCrypto.aesCtrHmacEncrypt(key, utf8.encode(input)),
          'BYTES',
        );
      case CryptoMode.sha256Hex:
      case CryptoMode.sha256Base64:
      case CryptoMode.sha256Bytes:
        return _modernEncoded(
          ModernCrypto.digest(pc.SHA256Digest(), utf8.encode(input)),
          mode.formatLabel,
        );
      case CryptoMode.sha512Hex:
      case CryptoMode.sha512Base64:
      case CryptoMode.sha512Bytes:
        return _modernEncoded(
          ModernCrypto.digest(pc.SHA512Digest(), utf8.encode(input)),
          mode.formatLabel,
        );
      case CryptoMode.sha3_256Hex:
      case CryptoMode.sha3_256Base64:
      case CryptoMode.sha3_256Bytes:
        return _modernEncoded(
          ModernCrypto.digest(pc.SHA3Digest(256), utf8.encode(input)),
          mode.formatLabel,
        );
      case CryptoMode.blake2b512Hex:
      case CryptoMode.blake2b512Base64:
      case CryptoMode.blake2b512Bytes:
        return _modernEncoded(
          ModernCrypto.digest(pc.Blake2bDigest(), utf8.encode(input)),
          mode.formatLabel,
        );
      case CryptoMode.sm3Hex:
      case CryptoMode.sm3Base64:
      case CryptoMode.sm3Bytes:
        return _modernEncoded(
          ModernCrypto.digest(pc.SM3Digest(), utf8.encode(input)),
          mode.formatLabel,
        );
      case CryptoMode.hmacSha256Hex:
      case CryptoMode.hmacSha256Base64:
      case CryptoMode.hmacSha256Bytes:
        return _modernEncoded(
          ModernCrypto.hmacSha256(key, utf8.encode(input)),
          mode.formatLabel,
        );
      case CryptoMode.hmacSha3_256Hex:
      case CryptoMode.hmacSha3_256Base64:
      case CryptoMode.hmacSha3_256Bytes:
        return _modernEncoded(
          ModernCrypto.hmacSha3(key, utf8.encode(input)),
          mode.formatLabel,
        );
      case CryptoMode.hmacSm3Hex:
      case CryptoMode.hmacSm3Base64:
      case CryptoMode.hmacSm3Bytes:
        return _modernEncoded(
          ModernCrypto.hmacSm3(key, utf8.encode(input)),
          mode.formatLabel,
        );
      case CryptoMode.pbkdf2Base64:
        return base64Encode(ModernCrypto.pbkdf2(key, utf8.encode(input)));
      case CryptoMode.pbkdf2Hex:
        return _hexEncode(ModernCrypto.pbkdf2(key, utf8.encode(input)));
      case CryptoMode.pbkdf2Bytes:
        return _arrayToString(ModernCrypto.pbkdf2(key, utf8.encode(input)));
      case CryptoMode.scryptBase64:
        return base64Encode(ModernCrypto.scrypt(key, utf8.encode(input)));
      case CryptoMode.scryptHex:
        return _hexEncode(ModernCrypto.scrypt(key, utf8.encode(input)));
      case CryptoMode.scryptBytes:
        return _arrayToString(ModernCrypto.scrypt(key, utf8.encode(input)));
      case CryptoMode.argon2idBase64:
        return base64Encode(ModernCrypto.argon2id(key, utf8.encode(input)));
      case CryptoMode.argon2idHex:
        return _hexEncode(ModernCrypto.argon2id(key, utf8.encode(input)));
      case CryptoMode.argon2idBytes:
        return _arrayToString(ModernCrypto.argon2id(key, utf8.encode(input)));
      case CryptoMode.rsaOaepBase64:
        return base64Encode(
          ModernCrypto.rsaOaepEncrypt(key, utf8.encode(input)),
        );
      case CryptoMode.rsaOaepHex:
        return _hexEncode(ModernCrypto.rsaOaepEncrypt(key, utf8.encode(input)));
      case CryptoMode.rsaOaepBytes:
        return _arrayToString(
          ModernCrypto.rsaOaepEncrypt(key, utf8.encode(input)),
        );
      case CryptoMode.ecdsaSignBase64:
        return base64Encode(ModernCrypto.ecdsaSign(key, utf8.encode(input)));
      case CryptoMode.ecdsaSignHex:
        return _hexEncode(ModernCrypto.ecdsaSign(key, utf8.encode(input)));
      case CryptoMode.ecdsaSignBytes:
        return _arrayToString(ModernCrypto.ecdsaSign(key, utf8.encode(input)));
      case CryptoMode.base32:
        return ModernCrypto.base32Encode(utf8.encode(input));
      case CryptoMode.base58:
        return ModernCrypto.base58Encode(utf8.encode(input));
      case CryptoMode.urlEncode:
        return Uri.encodeQueryComponent(input);
      case CryptoMode.utf16Hex:
        return ModernCrypto.utf16HexEncode(input);
      case CryptoMode.gb18030Bytes:
        return _arrayToString(LegacyGbk.encode(input));
      default:
        return _encodeUniform(input, mode, key);
    }
  }

  static String _decode(String input, CryptoMode mode, String key) {
    switch (mode) {
      case CryptoMode.hex:
        return utf8.decode(_hexDecode(input), allowMalformed: true);
      case CryptoMode.base64:
        return utf8.decode(base64Decode(input.trim()), allowMalformed: true);
      case CryptoMode.utf8Bytes:
        return utf8.decode(_parseByteArray(input), allowMalformed: true);
      case CryptoMode.gbkBytes:
        return LegacyGbk.decode(_parseByteArray(input));
      case CryptoMode.unicode:
        return _unicodeDecode(input);
      case CryptoMode.desBase64:
        return utf8.decode(
          _desCrypt(base64Decode(input.trim()), key, encrypt: false),
          allowMalformed: true,
        );
      case CryptoMode.desHex:
        return utf8.decode(
          _desCrypt(_hexDecode(input), key, encrypt: false),
          allowMalformed: true,
        );
      case CryptoMode.desBytes:
        return utf8.decode(
          _desCrypt(_parseByteArray(input), key, encrypt: false),
          allowMalformed: true,
        );
      case CryptoMode.md5Upper32:
      case CryptoMode.md5Lower32:
      case CryptoMode.md5Upper16:
      case CryptoMode.md5Lower16:
        throw FormatException(mode.oneWayErrorMessage);
      case CryptoMode.rc4Hex:
        return utf8.decode(_rc4(_hexDecode(input), key), allowMalformed: true);
      case CryptoMode.rc4Base64:
        return utf8.decode(
          _rc4(base64Decode(input.trim()), key),
          allowMalformed: true,
        );
      case CryptoMode.rc4Bytes:
        return utf8.decode(_rc4(_parseByteArray(input), key),
            allowMalformed: true);
      case CryptoMode.aesGcmBase64:
        return utf8.decode(
          _aesGcmDecrypt(base64Decode(input.trim()), key),
          allowMalformed: true,
        );
      case CryptoMode.aesGcmHex:
        return utf8.decode(_aesGcmDecrypt(_hexDecode(input), key),
            allowMalformed: true);
      case CryptoMode.aesGcmBytes:
        return utf8.decode(_aesGcmDecrypt(_parseByteArray(input), key),
            allowMalformed: true);
      case CryptoMode.chacha20Poly1305Base64:
      case CryptoMode.chacha20Poly1305Hex:
      case CryptoMode.chacha20Poly1305Bytes:
        return utf8.decode(
          ModernCrypto.chacha20Poly1305Decrypt(
            key,
            _modernDecoded(input, mode.formatLabel),
          ),
          allowMalformed: true,
        );
      case CryptoMode.xchacha20Poly1305Base64:
      case CryptoMode.xchacha20Poly1305Hex:
      case CryptoMode.xchacha20Poly1305Bytes:
        return utf8.decode(
          ModernCrypto.xChaCha20Poly1305Decrypt(
            key,
            _modernDecoded(input, mode.formatLabel),
          ),
          allowMalformed: true,
        );
      case CryptoMode.sm4GcmBase64:
      case CryptoMode.sm4GcmHex:
      case CryptoMode.sm4GcmBytes:
        return utf8.decode(
          ModernCrypto.sm4GcmDecrypt(
              key, _modernDecoded(input, mode.formatLabel)),
          allowMalformed: true,
        );
      case CryptoMode.aesCbcHmacBase64:
      case CryptoMode.aesCbcHmacHex:
      case CryptoMode.aesCbcHmacBytes:
        return utf8.decode(
          ModernCrypto.aesCbcHmacDecrypt(
              key, _modernDecoded(input, mode.formatLabel)),
          allowMalformed: true,
        );
      case CryptoMode.sm4CbcHmacBase64:
      case CryptoMode.sm4CbcHmacHex:
      case CryptoMode.sm4CbcHmacBytes:
        return utf8.decode(
          ModernCrypto.sm4CbcHmacDecrypt(
              key, _modernDecoded(input, mode.formatLabel)),
          allowMalformed: true,
        );
      case CryptoMode.aesCtrHmacBase64:
      case CryptoMode.aesCtrHmacHex:
      case CryptoMode.aesCtrHmacBytes:
        return utf8.decode(
          ModernCrypto.aesCtrHmacDecrypt(
              key, _modernDecoded(input, mode.formatLabel)),
          allowMalformed: true,
        );
      case CryptoMode.sha256Hex:
      case CryptoMode.sha256Base64:
      case CryptoMode.sha256Bytes:
      case CryptoMode.sha512Hex:
      case CryptoMode.sha512Base64:
      case CryptoMode.sha512Bytes:
      case CryptoMode.sha3_256Hex:
      case CryptoMode.sha3_256Base64:
      case CryptoMode.sha3_256Bytes:
      case CryptoMode.blake2b512Hex:
      case CryptoMode.blake2b512Base64:
      case CryptoMode.blake2b512Bytes:
      case CryptoMode.sm3Hex:
      case CryptoMode.sm3Base64:
      case CryptoMode.sm3Bytes:
      case CryptoMode.hmacSha256Hex:
      case CryptoMode.hmacSha256Base64:
      case CryptoMode.hmacSha256Bytes:
      case CryptoMode.hmacSha3_256Hex:
      case CryptoMode.hmacSha3_256Base64:
      case CryptoMode.hmacSha3_256Bytes:
      case CryptoMode.hmacSm3Hex:
      case CryptoMode.hmacSm3Base64:
      case CryptoMode.hmacSm3Bytes:
      case CryptoMode.pbkdf2Base64:
      case CryptoMode.pbkdf2Hex:
      case CryptoMode.pbkdf2Bytes:
      case CryptoMode.scryptBase64:
      case CryptoMode.scryptHex:
      case CryptoMode.scryptBytes:
      case CryptoMode.argon2idBase64:
      case CryptoMode.argon2idHex:
      case CryptoMode.argon2idBytes:
      case CryptoMode.ecdsaSignBase64:
      case CryptoMode.ecdsaSignHex:
      case CryptoMode.ecdsaSignBytes:
        throw FormatException(mode.oneWayErrorMessage);
      case CryptoMode.rsaOaepBase64:
      case CryptoMode.rsaOaepHex:
      case CryptoMode.rsaOaepBytes:
        return utf8.decode(
          ModernCrypto.rsaOaepDecrypt(
              key, _modernDecoded(input, mode.formatLabel)),
          allowMalformed: true,
        );
      case CryptoMode.base32:
        return utf8.decode(ModernCrypto.base32Decode(input),
            allowMalformed: true);
      case CryptoMode.base58:
        return utf8.decode(ModernCrypto.base58Decode(input),
            allowMalformed: true);
      case CryptoMode.urlEncode:
        return Uri.decodeQueryComponent(input);
      case CryptoMode.utf16Hex:
        return ModernCrypto.utf16HexDecode(input);
      case CryptoMode.gb18030Bytes:
        return LegacyGbk.decode(_parseByteArray(input));
      default:
        return _decodeUniform(input, mode, key);
    }
  }

  static String _encodeUniform(String input, CryptoMode mode, String key) {
    final bytes = _uniformBytes(input, mode.algorithmLabel, key, encrypt: true);
    return _encodeBytes(bytes, mode.formatLabel);
  }

  static String _decodeUniform(String input, CryptoMode mode, String key) {
    final bytes = _decodeBytes(input, mode.formatLabel);
    final plain = _uniformBytes(
      '',
      mode.algorithmLabel,
      key,
      encrypted: bytes,
    );
    return utf8.decode(plain, allowMalformed: true);
  }

  static Uint8List _uniformBytes(
    String input,
    String algorithm,
    String key, {
    bool encrypt = false,
    Uint8List? encrypted,
  }) {
    final data = encrypted ?? Uint8List.fromList(utf8.encode(input));
    if (encrypt) {
      switch (algorithm) {
        case 'DES':
          return _desCrypt(data, key, encrypt: true);
        case 'RC4':
          return _rc4(data, key);
        case 'AES-256-GCM':
          return _aesGcmEncrypt(data, key);
        case 'ChaCha20-Poly1305':
          return ModernCrypto.chacha20Poly1305Encrypt(key, data);
        case 'XChaCha20-Poly1305':
          return ModernCrypto.xChaCha20Poly1305Encrypt(key, data);
        case 'SM4-GCM':
          return ModernCrypto.sm4GcmEncrypt(key, data);
        case 'AES-CBC + HMAC-SHA256':
          return ModernCrypto.aesCbcHmacEncrypt(key, data);
        case 'SM4-CBC + HMAC-SM3':
          return ModernCrypto.sm4CbcHmacEncrypt(key, data);
        case 'AES-CTR + HMAC-SHA256':
          return ModernCrypto.aesCtrHmacEncrypt(key, data);
        case 'SHA-256':
          return ModernCrypto.digest(pc.SHA256Digest(), data);
        case 'SHA-512':
          return ModernCrypto.digest(pc.SHA512Digest(), data);
        case 'SHA3-256':
          return ModernCrypto.digest(pc.SHA3Digest(256), data);
        case 'BLAKE2b-512':
          return ModernCrypto.digest(pc.Blake2bDigest(), data);
        case 'SM3':
          return ModernCrypto.digest(pc.SM3Digest(), data);
        case 'HMAC-SHA256':
          return ModernCrypto.hmacSha256(key, data);
        case 'HMAC-SHA3-256':
          return ModernCrypto.hmacSha3(key, data);
        case 'HMAC-SM3':
          return ModernCrypto.hmacSm3(key, data);
        case 'PBKDF2-HMAC-SHA256':
          return ModernCrypto.pbkdf2(key, data);
        case 'scrypt':
          return ModernCrypto.scrypt(key, data);
        case 'Argon2id':
          return ModernCrypto.argon2id(key, data);
        case 'RSA-OAEP-SHA256':
          return ModernCrypto.rsaOaepEncrypt(key, data);
        case 'ECDSA-SHA256 签名':
          return ModernCrypto.ecdsaSign(key, data);
        case 'MD5':
          return Uint8List.fromList(crypto.md5.convert(data).bytes);
        default:
          throw FormatException('未知算法: $algorithm');
      }
    }
    switch (algorithm) {
      case 'DES':
        return _desCrypt(data, key, encrypt: false);
      case 'RC4':
        return _rc4(data, key);
      case 'AES-256-GCM':
        return _aesGcmDecrypt(data, key);
      case 'ChaCha20-Poly1305':
        return ModernCrypto.chacha20Poly1305Decrypt(key, data);
      case 'XChaCha20-Poly1305':
        return ModernCrypto.xChaCha20Poly1305Decrypt(key, data);
      case 'SM4-GCM':
        return ModernCrypto.sm4GcmDecrypt(key, data);
      case 'AES-CBC + HMAC-SHA256':
        return ModernCrypto.aesCbcHmacDecrypt(key, data);
      case 'SM4-CBC + HMAC-SM3':
        return ModernCrypto.sm4CbcHmacDecrypt(key, data);
      case 'AES-CTR + HMAC-SHA256':
        return ModernCrypto.aesCtrHmacDecrypt(key, data);
      case 'RSA-OAEP-SHA256':
        return ModernCrypto.rsaOaepDecrypt(key, data);
      default:
        throw FormatException('$algorithm 是单向操作，仅支持生成结果');
    }
  }

  static String _encodeBytes(List<int> bytes, String format) {
    if (!_uniformFormatLabels.contains(format) && format != 'Byte[ ]') {
      throw FormatException('未知编码格式: $format');
    }
    switch (format) {
      case 'BASE32':
        return ModernCrypto.base32Encode(bytes);
      case 'BASE58':
        return ModernCrypto.base58Encode(bytes);
      case 'BASE64':
        return base64Encode(bytes);
      case 'Byte[ ]':
      case 'Byte[ ] (UTF-8)':
      case 'Byte[ ] (GBK)':
      case 'Byte[ ] (GB18030/GBK兼容)':
        return _arrayToString(bytes);
      case 'HEX':
        return _hexEncode(bytes);
      case 'UniCode':
        return bytes
            .map((byte) =>
                '\\u${(byte & 0xff).toRadixString(16).padLeft(4, '0')}')
            .join();
      case 'URL Encode':
        return _percentEncodeBytes(bytes);
      case 'UTF-16 (HEX)':
        return ModernCrypto.utf16HexEncode(String.fromCharCodes(bytes));
      default:
        throw FormatException('未知编码格式: $format');
    }
  }

  static Uint8List _decodeBytes(String input, String format) {
    switch (format) {
      case 'BASE32':
        return ModernCrypto.base32Decode(input);
      case 'BASE58':
        return ModernCrypto.base58Decode(input);
      case 'BASE64':
        return Uint8List.fromList(base64Decode(input.trim()));
      case 'Byte[ ]':
      case 'Byte[ ] (UTF-8)':
      case 'Byte[ ] (GBK)':
      case 'Byte[ ] (GB18030/GBK兼容)':
        return Uint8List.fromList(_parseByteArray(input));
      case 'HEX':
        return _hexDecode(input);
      case 'UniCode':
        return Uint8List.fromList(_unicodeDecode(input).codeUnits);
      case 'URL Encode':
        return _percentDecodeBytes(input);
      case 'UTF-16 (HEX)':
        return Uint8List.fromList(
          ModernCrypto.utf16HexDecode(input).codeUnits,
        );
      default:
        throw FormatException('未知编码格式: $format');
    }
  }

  static String _percentEncodeBytes(List<int> bytes) {
    const safe =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.!~*\'()';
    final out = StringBuffer();
    const digits = '0123456789ABCDEF';
    for (final byte in bytes) {
      final value = byte & 0xff;
      if (value < 128 && safe.contains(String.fromCharCode(value))) {
        out.writeCharCode(value);
      } else {
        out
          ..write('%')
          ..write(digits[value >> 4])
          ..write(digits[value & 15]);
      }
    }
    return out.toString();
  }

  static Uint8List _percentDecodeBytes(String input) {
    final out = <int>[];
    for (var i = 0; i < input.length; i++) {
      if (input[i] == '%') {
        if (i + 2 >= input.length) {
          throw const FormatException('URL Encode 格式无效');
        }
        final value = int.tryParse(input.substring(i + 1, i + 3), radix: 16);
        if (value == null) throw const FormatException('URL Encode 格式无效');
        out.add(value);
        i += 2;
      } else {
        out.add(input.codeUnitAt(i));
      }
    }
    return Uint8List.fromList(out);
  }

  static String _modernEncoded(List<int> bytes, String format) {
    switch (format) {
      case 'BASE64':
        return base64Encode(bytes);
      case 'HEX':
        return _hexEncode(bytes);
      case 'BYTES':
      case 'Byte[ ]':
        return _arrayToString(bytes);
      default:
        throw FormatException('未知二进制编码格式: $format');
    }
  }

  static Uint8List _modernDecoded(String input, String format) {
    switch (format) {
      case 'BASE64':
        return Uint8List.fromList(base64Decode(input.trim()));
      case 'HEX':
        return _hexDecode(input);
      case 'Byte[ ]':
        return Uint8List.fromList(_parseByteArray(input));
      default:
        throw FormatException('未知二进制编码格式: $format');
    }
  }

  static String _md5(String input) {
    return crypto.md5.convert(utf8.encode(input)).toString();
  }

  static Uint8List _aesKey(String key) {
    if (key.isEmpty) {
      throw const FormatException('请输入秘钥');
    }
    return Uint8List.fromList(crypto.sha256.convert(utf8.encode(key)).bytes);
  }

  static Uint8List _aesGcmEncrypt(List<int> data, String key) {
    final nonce = Uint8List.fromList(
      List<int>.generate(12, (_) => math.Random.secure().nextInt(256)),
    );
    final cipher = pc.GCMBlockCipher(pc.AESEngine())
      ..init(
        true,
        pc.AEADParameters<pc.KeyParameter>(
          pc.KeyParameter(_aesKey(key)),
          128,
          nonce,
          Uint8List(0),
        ),
      );
    final payload = cipher.process(Uint8List.fromList(data));
    return Uint8List.fromList(<int>[
      0x58,
      0x41,
      0x47,
      0x31,
      ...nonce,
      ...payload,
    ]);
  }

  static Uint8List _aesGcmDecrypt(List<int> encoded, String key) {
    const headerLength = 4;
    const nonceLength = 12;
    const tagLength = 16;
    if (encoded.length < headerLength + nonceLength + tagLength ||
        encoded[0] != 0x58 ||
        encoded[1] != 0x41 ||
        encoded[2] != 0x47 ||
        encoded[3] != 0x31) {
      throw const FormatException('AES-GCM 密文格式无效');
    }
    final nonce = Uint8List.fromList(
      encoded.sublist(headerLength, headerLength + nonceLength),
    );
    final payload =
        Uint8List.fromList(encoded.sublist(headerLength + nonceLength));
    final cipher = pc.GCMBlockCipher(pc.AESEngine())
      ..init(
        false,
        pc.AEADParameters<pc.KeyParameter>(
          pc.KeyParameter(_aesKey(key)),
          128,
          nonce,
          Uint8List(0),
        ),
      );
    try {
      return cipher.process(payload);
    } on pc.InvalidCipherTextException {
      throw const FormatException('AES-GCM 密钥错误或密文已损坏');
    }
  }

  static Uint8List _rc4(List<int> data, String key) {
    final keyBytes = utf8.encode(key);
    if (keyBytes.isEmpty) {
      throw const FormatException('请输入秘钥');
    }
    final state = List<int>.generate(256, (index) => index);
    var j = 0;
    for (var i = 0; i < 256; i++) {
      j = (j + state[i] + keyBytes[i % keyBytes.length]) & 0xff;
      final swap = state[i];
      state[i] = state[j];
      state[j] = swap;
    }

    var i = 0;
    j = 0;
    final output = Uint8List(data.length);
    for (var index = 0; index < data.length; index++) {
      i = (i + 1) & 0xff;
      j = (j + state[i]) & 0xff;
      final swap = state[i];
      state[i] = state[j];
      state[j] = swap;
      final keyByte = state[(state[i] + state[j]) & 0xff];
      output[index] = (data[index] ^ keyByte) & 0xff;
    }
    return output;
  }

  static Uint8List _desCrypt(
    List<int> data,
    String key, {
    required bool encrypt,
  }) {
    final keyBytes = utf8.encode(key);
    if (keyBytes.isEmpty) {
      throw const FormatException('请输入秘钥');
    }
    // Keep the legacy first-eight-byte behavior for existing 8-character
    // keys; other passwords use a deterministic SHA-256-derived DES key.
    final desKey = key.length == 8 && keyBytes.length >= 8
        ? Uint8List.fromList(keyBytes.take(8).toList())
        : Uint8List.fromList(
            crypto.sha256.convert(keyBytes).bytes.sublist(0, 8),
          );
    final cipher = pc.PaddedBlockCipherImpl(
      pc.PKCS7Padding(),
      pc.ECBBlockCipher(pc.DESedeEngine()),
    );
    cipher.init(
      encrypt,
      pc.PaddedBlockCipherParameters<pc.KeyParameter, Null>(
        // DESede with K1 = K2 = K3 is exactly single DES.
        // Android DESKeySpec reads the first eight UTF-8 bytes.
        pc.KeyParameter(Uint8List.fromList([
          ...desKey,
          ...desKey,
          ...desKey,
        ])),
        null,
      ),
    );
    return cipher.process(Uint8List.fromList(data));
  }

  static String _arrayToString(List<int> bytes) {
    final signed = bytes.map((value) => value > 127 ? value - 256 : value);
    return '[${signed.join(', ')}]';
  }

  static List<int> _parseByteArray(String input) {
    final normalized = input.replaceAll('[', '').replaceAll(']', '').trim();
    if (normalized.isEmpty) return <int>[];
    final parts = normalized.split(',');
    return parts.map((part) {
      final value = int.tryParse(part.trim());
      if (value == null || value < -128 || value > 127) {
        throw FormatException('Byte 数值须在 -128 到 127 之间: $part');
      }
      return value & 0xff;
    }).toList(growable: false);
  }

  static String _hexEncode(List<int> bytes) {
    const digits = '0123456789ABCDEF';
    final result = StringBuffer();
    for (final byte in bytes) {
      final value = byte & 0xff;
      result
        ..write(digits[(value >> 4) & 0x0f])
        ..write(digits[value & 0x0f]);
    }
    return result.toString();
  }

  static Uint8List _hexDecode(String input) {
    var value = input.trim();
    if (value.length.isOdd) value = '0$value';
    final output = Uint8List(value.length ~/ 2);
    for (var index = 0; index < output.length; index++) {
      final pair = value.substring(index * 2, index * 2 + 2);
      final parsed = int.tryParse(pair, radix: 16);
      if (parsed == null) throw FormatException('Invalid HEX: $pair');
      output[index] = parsed;
    }
    return output;
  }

  static String _unicodeDecode(String input) {
    return input.replaceAllMapped(
      RegExp(r'\\u([0-9a-fA-F]{1,4})'),
      (match) => String.fromCharCode(int.parse(match.group(1)!, radix: 16)),
    );
  }
}
