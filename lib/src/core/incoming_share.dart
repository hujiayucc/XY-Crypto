import 'dart:async';

import 'package:flutter/services.dart';

typedef IncomingShareHandler = FutureOr<void> Function(String text);

/// Consumes pending OS content only when started after privacy consent.
class IncomingShareService {
  IncomingShareService({required this.onText});

  static const _channel = MethodChannel('com.hujiayucc.decode/share');
  final IncomingShareHandler onText;
  bool _active = false;
  int _generation = 0;

  Future<void> start() async {
    if (_active) return;
    _active = true;
    final generation = ++_generation;
    _channel.setMethodCallHandler((call) async {
      if (_active &&
          generation == _generation &&
          call.method == 'sharedText' &&
          call.arguments is String) {
        await onText(call.arguments as String);
      }
      return null;
    });
    try {
      final initial =
          await _channel.invokeMethod<String>('getInitialSharedText');
      if (_active &&
          generation == _generation &&
          initial != null &&
          initial.trim().isNotEmpty) {
        await onText(initial);
      }
    } on MissingPluginException {
      // Apple platforms use app_links instead of this native channel.
    } on PlatformException {
      // The native host may still be shutting down after consent withdrawal.
    }
  }

  Future<void> stop() async {
    dispose();
    try {
      await _channel.invokeMethod<void>('stopReceiving');
    } on MissingPluginException {
      // No native text-share channel on this platform.
    } on PlatformException {
      // The engine may already have stopped.
    }
  }

  void dispose() {
    _active = false;
    _generation++;
    _channel.setMethodCallHandler(null);
  }
}
