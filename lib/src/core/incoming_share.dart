import 'dart:async';

import 'package:flutter/services.dart';

typedef IncomingShareHandler = FutureOr<void> Function(String text);

class IncomingShareService {
  IncomingShareService({required this.onText});

  static const _channel = MethodChannel('com.hujiayucc.decode/share');
  final IncomingShareHandler onText;

  Future<void> start() async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'sharedText' && call.arguments is String) {
        await onText(call.arguments as String);
      }
      return null;
    });
    try {
      final initial =
          await _channel.invokeMethod<String>('getInitialSharedText');
      if (initial != null && initial.trim().isNotEmpty) await onText(initial);
    } on MissingPluginException {
      // URI links remain available through app_links on other platforms.
    } on PlatformException {
      // A platform can omit ACTION_SEND support without affecting URI links.
    }
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
  }
}