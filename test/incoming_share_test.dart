import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xy_encrypt_app/src/core/incoming_share.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.hujiayucc.decode/share');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('dispose discards a late initial link response', () async {
    final pending = Completer<String?>();
    messenger.setMockMethodCallHandler(channel, (_) => pending.future);
    final texts = <String>[];
    final service = IncomingShareService(onText: texts.add);
    final start = service.start();
    service.dispose();
    pending.complete('xyd://share?type=0&text=old');
    await start;
    expect(texts, isEmpty);
  });

  test('start is idempotent and stop disables native receiving', () async {
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return call.method == 'getInitialSharedText' ? 'hello' : null;
    });
    final texts = <String>[];
    final service = IncomingShareService(onText: texts.add);
    await service.start();
    await service.start();
    expect(texts, ['hello']);
    await service.stop();
    expect(calls, ['getInitialSharedText', 'stopReceiving']);
    await service.start();
    expect(texts, ['hello', 'hello']);
    await service.stop();
  });
}
