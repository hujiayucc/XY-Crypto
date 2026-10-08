import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Android bootstraps consent through our own channel, before plugin registration.
class PrivacyRuntime {
  PrivacyRuntime({bool? android, FlutterSecureStorage? storage})
      : android = android ?? Platform.isAndroid,
        _storage = storage ?? const FlutterSecureStorage();

  static const channel = MethodChannel('com.hujiayucc.decode/privacy');
  static const recordKey = 'legal_consent_record_v2';
  final bool android;
  final FlutterSecureStorage _storage;

  Future<bool> hasConsent(String version) async {
    try {
      final raw = android
          ? await channel.invokeMethod<String>('readConsent')
          : await _storage.read(key: recordKey);
      if (raw == null) return false;
      final record = jsonDecode(raw);
      return record is Map &&
          record['version'] == version &&
          record['acceptedAt'] is String &&
          DateTime.tryParse(record['acceptedAt'] as String) != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> accept(String version) async {
    final record = jsonEncode({
      'version': version,
      'acceptedAt': DateTime.now().toUtc().toIso8601String(),
    });
    if (android) {
      await channel.invokeMethod<void>('saveConsent', record);
    } else {
      await _storage.write(key: recordKey, value: record);
    }
  }

  Future<void> activate(String version) async {
    if (android) await channel.invokeMethod<void>('activate', version);
  }

  Future<void> revoke() async {
    if (android) {
      await channel.invokeMethod<void>('revokeConsent');
    } else {
      await _storage.delete(key: recordKey);
      // Remove the previous policy's legacy record as well.
      await _storage.delete(key: 'legal_consent_version');
      await _storage.delete(key: 'legal_consent_accepted_at');
    }
  }

  Future<void> exitApp() async {
    if (android) {
      await channel.invokeMethod<void>('exitApplication');
    } else {
      await SystemNavigator.pop();
    }
  }

  static Future<String> prepareScanner() async {
    if (!Platform.isAndroid) return 'ready';
    return await channel.invokeMethod<String>('prepareScanner') ?? 'denied';
  }

  static Future<bool> openPermissions() async {
    if (!Platform.isAndroid) return false;
    await channel.invokeMethod<void>('openAppSettings');
    return true;
  }
}
