import 'dart:typed_data';

import 'package:pointycastle/export.dart' as pc;

/// SM4 block cipher engine used by ECB/CBC/GCM wrappers.
class Sm4Engine implements pc.BlockCipher {
  static const _mask = 0xffffffff;
  static const _sboxHex =
      'd690e9fe cce13db7 16b614c2 28fb2c05 2b679a76 2abe04c3 aa441326 '
      '49860699 9c4250f4 91ef987a 33540b43 edcfac62 e4b31ca9 c908e895 '
      '80df94fa 758f3fa6 4707a7fc f37317ba 83593c19 e6854fa8 686b81b2 '
      '7164da8b f8eb0f4b 70569d35 1e240e5e 6358d1a2 25227c3b 01217887 '
      'd4004657 9fd32752 4c3602e7 a0c4c89e eabf8ad2 40c738b5 a3f7f2ce '
      'f96115a1 e0ae5da4 9b341a55 ad933230 f58cb1e3 1df6e22e 8266ca60 '
      'c02923ab 0d534e6f d5db3745 defd8e2f 03ff6a72 6d6c5b51 8d1baf92 '
      'bbddbc7f 11d95c41 1f105ad8 0ac13188 a5cd7bbd 2d74d012 b8e5b4b0 '
      '8969974a 0c96777e 65b9f109 c56ec684 18f07dec 3adc4d20 79ee5f3e '
      'd7cb3948';
  static final List<int> _sbox = List<int>.generate(
    256,
    (index) => int.parse(
      _sboxHex.replaceAll(' ', '').substring(index * 2, index * 2 + 2),
      radix: 16,
    ),
    growable: false,
  );
  static const _fk = <int>[0xa3b1bac6, 0x56aa3350, 0x677d9197, 0xb27022dc];
  static const _ck = <int>[
    0x00070e15, 0x1c232a31, 0x383f464d, 0x545b6269,
    0x70777e85, 0x8c939aa1, 0xa8afb6bd, 0xc4cbd2d9,
    0xe0e7eef5, 0xfc030a11, 0x181f262d, 0x343b4249,
    0x50575e65, 0x6c737a81, 0x888f969d, 0xa4abb2b9,
    0xc0c7ced5, 0xdce3eaf1, 0xf8ff060d, 0x141b2229,
    0x30373e45, 0x4c535a61, 0x686f767d, 0x848b9299,
    0xa0a7aeb5, 0xbcc3cad1, 0xd8dfe6ed, 0xf4fb0209,
    0x10171e25, 0x2c333a41, 0x484f565d, 0x646b7279,
  ];

  late Uint32List _encryptKeys;
  late Uint32List _decryptKeys;
  var _initialized = false;
  var _forEncryption = true;

  @override
  String get algorithmName => 'SM4';

  @override
  int get blockSize => 16;

  @override
  void init(bool forEncryption, pc.CipherParameters? params) {
    if (params is! pc.KeyParameter || params.key.length != 16) {
      throw ArgumentError('SM4 requires a 16-byte key');
    }
    _forEncryption = forEncryption;
    _encryptKeys = Uint32List(32);
    _decryptKeys = Uint32List(32);
    final words = Uint32List(36);
    for (var i = 0; i < 4; i++) {
      words[i] = _readWord(params.key, i * 4) ^ _fk[i];
    }
    for (var i = 0; i < 32; i++) {
      words[i + 4] = (words[i] ^
              _linearKey(_substitute(words[i + 1] ^ words[i + 2] ^
                  words[i + 3] ^ _ck[i]))) &
          _mask;
      _encryptKeys[i] = words[i + 4];
      _decryptKeys[31 - i] = words[i + 4];
    }
    _initialized = true;
  }

  @override
  void reset() {}

  @override
  Uint8List process(Uint8List data) {
    if (data.length != blockSize) {
      throw ArgumentError('SM4 processes exactly one 16-byte block');
    }
    final out = Uint8List(blockSize);
    processBlock(data, 0, out, 0);
    return out;
  }

  @override
  int processBlock(Uint8List input, int inputOffset, Uint8List output,
      int outputOffset) {
    if (!_initialized) throw StateError('SM4 is not initialized');
    if (inputOffset < 0 || inputOffset + blockSize > input.length) {
      throw ArgumentError('SM4 input buffer is too short');
    }
    if (outputOffset < 0 || outputOffset + blockSize > output.length) {
      throw ArgumentError('SM4 output buffer is too short');
    }
    final x = Uint32List(36);
    for (var i = 0; i < 4; i++) {
      x[i] = _readWord(input, inputOffset + i * 4);
    }
    final keys = _forEncryption ? _encryptKeys : _decryptKeys;
    for (var i = 0; i < 32; i++) {
      x[i + 4] = (x[i] ^
              _linearData(_substitute(x[i + 1] ^ x[i + 2] ^
                  x[i + 3] ^ keys[i]))) &
          _mask;
    }
    _writeWord(x[35], output, outputOffset);
    _writeWord(x[34], output, outputOffset + 4);
    _writeWord(x[33], output, outputOffset + 8);
    _writeWord(x[32], output, outputOffset + 12);
    return blockSize;
  }

  static int _readWord(List<int> bytes, int offset) =>
      ((bytes[offset] & 0xff) << 24) |
      ((bytes[offset + 1] & 0xff) << 16) |
      ((bytes[offset + 2] & 0xff) << 8) |
      (bytes[offset + 3] & 0xff);

  static void _writeWord(int value, List<int> bytes, int offset) {
    bytes[offset] = (value >> 24) & 0xff;
    bytes[offset + 1] = (value >> 16) & 0xff;
    bytes[offset + 2] = (value >> 8) & 0xff;
    bytes[offset + 3] = value & 0xff;
  }

  static int _substitute(int value) {
    return (_sbox[(value >> 24) & 0xff] << 24) |
        (_sbox[(value >> 16) & 0xff] << 16) |
        (_sbox[(value >> 8) & 0xff] << 8) |
        _sbox[value & 0xff];
  }

  static int _rotateLeft(int value, int bits) {
    value &= _mask;
    return ((value << bits) | (value >>> (32 - bits))) & _mask;
  }

  static int _linearData(int value) =>
      value ^
      _rotateLeft(value, 2) ^
      _rotateLeft(value, 10) ^
      _rotateLeft(value, 18) ^
      _rotateLeft(value, 24);

  static int _linearKey(int value) =>
      value ^ _rotateLeft(value, 13) ^ _rotateLeft(value, 23);
}
