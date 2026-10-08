import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:xy_crypto/xy_crypto.dart';

void main() {
  for (final file in ['android_vectors.json', 'apk_method_vectors.json']) {
    final data = jsonDecode(File('test/fixtures/$file').readAsStringSync()) as Map<String, dynamic>;
    final vectors = data['vectors'] as List<dynamic>;
    for (var i = 0; i < vectors.length; i++) {
      final row = vectors[i] as Map<String, dynamic>;
      final mode = CryptoMode.values[row['mode'] as int];
      test('$file vector $i ${mode.label}', () {
        final encoded = CryptoEngine.transform(input: row['input'] as String,
          mode: mode, encode: true, key: row['key'] as String);
        expect(encoded, row['expected']);
        if (!mode.isDigest) {
          expect(CryptoEngine.transform(input: encoded, mode: mode,
            encode: false, key: row['key'] as String), row['decoded']);
        }
      });
    }
  }
}
