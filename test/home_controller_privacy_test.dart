import 'package:flutter_test/flutter_test.dart';
import 'package:xy_encrypt_app/src/features/home/home_controller.dart';

void main() {
  test('Clearing remembered keys deletes only the app key slots', () async {
    final deleted = <String>[];
    final controller = HomeController(
      keyDeleter: () async => deleted.add('app-keys'),
    );

    await controller.clearRememberedKeys();

    expect(deleted, ['app-keys']);
    controller.dispose();
  });

  test('Clearing keys is a no-op for memory-only controllers', () async {
    final controller = HomeController(usePlatformStorage: false);

    await expectLater(controller.clearRememberedKeys(), completes);
    controller.dispose();
  });
}
