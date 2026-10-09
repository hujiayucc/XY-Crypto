import 'package:flutter_test/flutter_test.dart';
import 'package:xy_crypto/xy_crypto.dart';

void main() {
  test('accepts xyd links from external applications', () {
    final uri = ShareCodec.encode(CryptoMode.hex, '4142');
    expect(ShareCodec.isShareLink(uri.toString()), isTrue);
    expect(ShareCodec.findShareLink('打开：${uri.toString()}。'), uri.toString());
    final decoded = ShareCodec.decode(uri.toString());
    expect(decoded, isNotNull);
    expect(decoded!.mode, CryptoMode.hex);
    expect(decoded.text, '4142');
  });

  test('rejects an xyd URI with an unsupported host', () {
    expect(ShareCodec.isShareLink('xyd://other?type=0&text=4142'), isFalse);
    expect(ShareCodec.findShareLink('xyd://other?type=0&text=4142'), isNull);
  });

  test('wraps the xyd payload in a website fragment', () {
    final web = ShareCodec.encodeWebShare(CryptoMode.hex, '4142');
    expect(web.toString(), startsWith('https://app.hujiayucc.cn/share#'));
    expect(web.query, isEmpty);
    expect(web.toString(), contains('#xyd%3A%2F%2Fshare'));
    expect(ShareCodec.decode(Uri.decodeComponent(web.fragment)), isNotNull);
    expect(ShareCodec.findShareLink('打开：${web.toString()}'), Uri.decodeComponent(web.fragment));
  });
}
