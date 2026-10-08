import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/crypto_engine.dart';
import '../../core/share_codec.dart';

String _transform(Map<String, Object> job) => CryptoEngine.transform(
      input: job['input']! as String,
      mode: CryptoMode.values[job['mode']! as int],
      encode: job['encode']! as bool,
      key: job['key']! as String,
    );

typedef KeyReader = Future<String> Function(CryptoMode mode);
typedef KeyWriter = Future<void> Function(CryptoMode mode, String key);
typedef KeyDeleter = Future<void> Function();

class HomeController extends ChangeNotifier {
  HomeController({
    FlutterSecureStorage? storage,
    KeyReader? keyReader,
    KeyWriter? keyWriter,
    KeyDeleter? keyDeleter,
    bool usePlatformStorage = true,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _usePlatformStorage = usePlatformStorage,
        _keyReader = keyReader,
        _keyWriter = keyWriter,
        _keyDeleter = keyDeleter;
  final FlutterSecureStorage _storage;
  final bool _usePlatformStorage;
  final KeyReader? _keyReader;
  final KeyWriter? _keyWriter;
  final KeyDeleter? _keyDeleter;
  CryptoMode _mode = CryptoMode.hex;
  CryptoMode _outputMode = CryptoMode.hex;
  String _input = '';
  String _output = '';
  bool _busy = false;
  bool _disposed = false;
  int _revision = 0;
  String? _error;
  String? _statusMessage;
  bool _outputStale = false;
  bool _outputWasEncoded = false;
  String _outputKey = '';
  String _shareText = '';
  CryptoMode _shareMode = CryptoMode.hex;
  String _shareKey = '';
  bool _shareIsEncrypted = false;

  bool get outputWasEncoded => _outputWasEncoded;
  String get outputKey => _outputKey;
  String get shareText => _shareText.isEmpty ? _output : _shareText;
  CryptoMode get shareMode => _shareMode;
  String get shareKey => _shareKey;
  bool get shareIsEncrypted => _shareIsEncrypted;

  CryptoMode get mode => _mode;
  CryptoMode get outputMode => _outputMode;
  String get input => _input;
  String get output => _output;
  bool get busy => _busy;
  String? get error => _error;
  String? get statusMessage => _statusMessage;
  bool get outputStale => _outputStale;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  set input(String value) {
    _input = value;
    if (_shareText.isNotEmpty && _shareText != value) {
      _shareText = '';
      _shareMode = _mode;
      _shareKey = '';
      _shareIsEncrypted = false;
    }
    _revision++;
    _error = null;
    _statusMessage = null;
    _notify();
  }

  void setMode(CryptoMode value) {
    _mode = value;
    _revision++;
    _error = null;
    _statusMessage = null;
    _outputStale = _output.isNotEmpty && _outputMode != value;
    _notify();
  }

  Future<bool> importText(String text, {bool allowPlainText = true}) async {
    final imported = ShareCodec.decode(text);
    if (imported == null) {
      if (!allowPlainText) return false;
      setImportedText(text);
      return true;
    }
    _mode = imported.mode;
    _input = imported.text;
    _output = '';
    _outputStale = false;
    _outputWasEncoded = false;
    _outputKey = '';
    _shareText = imported.isEncryptedPayload ? imported.text : '';
    _shareMode = imported.mode;
    _shareKey = imported.key ?? '';
    _shareIsEncrypted = imported.isEncryptedPayload;
    _revision++;
    _error = null;
    _statusMessage = null;
    _notify();

    final importRevision = _revision;
    if (imported.isEncryptedPayload) {
      String key = imported.key ?? '';
      if (key.isEmpty) {
        try {
          key = await readKey(imported.mode);
        } catch (_) {
          key = '';
        }
      }
      if (_disposed || _revision != importRevision) return false;
      if (key.isEmpty) {
        _statusMessage = '密文已导入，请输入密钥后解密';
        _notify();
        return true;
      }
      await run(encode: false, key: key);
      if (_disposed || _revision != importRevision) return false;
      if (_output.isNotEmpty) {
        _outputKey = key;
        _shareText = imported.text;
        _shareMode = imported.mode;
        _shareKey = key;
        _shareIsEncrypted = true;
        _statusMessage = '密文已导入并完成解密';
        _notify();
      }
    }
    return true;
  }

  void setImportedText(String text) {
    _input = text;
    _output = '';
    _outputStale = false;
    _outputWasEncoded = false;
    _outputKey = '';
    _shareText = '';
    _shareMode = _mode;
    _shareKey = '';
    _shareIsEncrypted = false;
    _revision++;
    _error = null;
    _statusMessage = null;
    _notify();
  }

  String _keyName(CryptoMode value) {
    if (value.needsDesKey) return 'despassword';
    if (value.needsAesGcmKey) return 'aesgcmpassword';
    if (value.needsRc4Key) return 'rc4password';
    if (value.needsPasswordKey) return 'modernpassword';
    return 'modernkeyjson';
  }

  Future<String> readKey(CryptoMode value) async {
    if (_keyReader != null) return _keyReader(value);
    return await _storage.read(key: _keyName(value)) ?? '';
  }

  Future<void> rememberKey(CryptoMode value, String key) async {
    if (_keyWriter != null) {
      await _keyWriter(value, key);
      return;
    }
    await _storage.write(key: _keyName(value), value: key);
  }

  Future<void> clearRememberedKeys() async {
    if (_keyDeleter != null) {
      await _keyDeleter();
      return;
    }
    if (!_usePlatformStorage) return;
    if (_keyWriter != null || _keyReader != null) {
      throw StateError('当前密钥存储由外部测试适配器提供');
    }
    for (final key in const [
      'despassword',
      'aesgcmpassword',
      'rc4password',
      'modernpassword',
      'modernkeyjson',
    ]) {
      await _storage.delete(key: key);
    }
  }

  void clearSessionData() {
    _input = '';
    _output = '';
    _outputStale = false;
    _outputWasEncoded = false;
    _outputKey = '';
    _shareText = '';
    _shareMode = _mode;
    _shareKey = '';
    _shareIsEncrypted = false;
    _error = null;
    _statusMessage = null;
    _revision++;
    _notify();
  }

  void clearInput() {
    input = '';
  }

  void clearOutput() {
    _output = '';
    _outputStale = false;
    _outputWasEncoded = false;
    _outputKey = '';
    _shareText = '';
    _shareMode = _mode;
    _shareKey = '';
    _shareIsEncrypted = false;
    _error = null;
    _statusMessage = null;
    _revision++;
    _notify();
  }

  void restoreOutputToInput() {
    _input = _output;
    _output = '';
    _outputStale = false;
    _outputWasEncoded = false;
    _outputKey = '';
    _shareText = '';
    _shareMode = _mode;
    _shareKey = '';
    _shareIsEncrypted = false;
    _error = null;
    _statusMessage = '结果已替换到输入';
    _revision++;
    _notify();
  }

  Future<void> run({required bool encode, String key = ''}) async {
    if (_busy || _input.isEmpty) return;
    final revision = _revision;
    final selectedMode = _mode;
    final job = <String, Object>{
      'input': _input,
      'mode': selectedMode.index,
      'encode': encode,
      'key': key,
    };
    _busy = true;
    _error = null;
    _statusMessage = null;
    _notify();
    try {
      final result = await compute(_transform, job);
      if (!_disposed && _revision == revision) {
        _output = result;
        _outputMode = selectedMode;
        _outputStale = false;
        _outputWasEncoded = encode;
        _outputKey = key;
        if (encode) {
          _shareText = result;
          _shareMode = selectedMode;
          _shareKey = key;
          _shareIsEncrypted =
              selectedMode.operationSpec.kind == CryptoOperationKind.encryption;
        } else if (_shareIsEncrypted &&
            _shareText == _input &&
            key.isNotEmpty) {
          _shareKey = key;
        }
        _statusMessage = '处理完成';
      }
    } on FormatException catch (error) {
      if (_revision == revision) _error = error.message;
    } catch (error) {
      if (_revision == revision) _error = error.toString();
    } finally {
      _busy = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
