import 'package:flutter/material.dart';

import '../../core/crypto_engine.dart';

enum KeySheetKind { des, aesGcm, password, json }

KeySheetKind keySheetKindOf(CryptoMode mode) {
  if (mode.needsDesKey) return KeySheetKind.des;
  if (mode.needsAesGcmKey) return KeySheetKind.aesGcm;
  if (mode.needsPasswordKey) return KeySheetKind.password;
  return KeySheetKind.json;
}

String keySheetTitle(KeySheetKind kind) => switch (kind) {
      KeySheetKind.des => '请输入DES秘钥',
      KeySheetKind.aesGcm => '请输入AES-GCM秘钥',
      KeySheetKind.password => '请输入秘钥',
      KeySheetKind.json => '请输入密钥 JSON',
    };

String keySheetRandomLabel(KeySheetKind kind) =>
    kind == KeySheetKind.json ? '随机密钥' : '随机秘钥';

int keySheetMaxLength(KeySheetKind kind) => switch (kind) {
      KeySheetKind.des || KeySheetKind.password => 256,
      _ => 8192,
    };

bool keySheetIsValid(KeySheetKind kind, String value) {
  final maxLength = keySheetMaxLength(kind);
  return value.isNotEmpty && value.length <= maxLength;
}

String keySheetValidationMessage(KeySheetKind kind) =>
    '请输入1至${keySheetMaxLength(kind)}个字符';

class KeySheetResult {
  const KeySheetResult(this.value, this.remember);

  final String value;
  final bool remember;
}

class KeyInputSheet extends StatefulWidget {
  const KeyInputSheet({
    super.key,
    required this.mode,
    required this.initialValue,
  });

  final CryptoMode mode;
  final String initialValue;

  KeySheetKind get kind => keySheetKindOf(mode);

  @override
  State<KeyInputSheet> createState() => _KeyInputSheetState();
}

class _KeyInputSheetState extends State<KeyInputSheet> {
  late final TextEditingController _editor;
  String? _error;
  bool _remember = false;
  bool _obscureText = true;

  @override
  void initState() {
    super.initState();
    _editor = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _editor.dispose();
    super.dispose();
  }

  bool get _isSecret =>
      widget.kind == KeySheetKind.des ||
      widget.kind == KeySheetKind.password ||
      widget.kind == KeySheetKind.aesGcm;

  void _fillRandomKey() {
    try {
      final generated = CryptoEngine.generateKey(widget.mode);
      setState(() {
        _editor.text = generated;
        _editor.selection = TextSelection.collapsed(offset: generated.length);
        _error = null;
      });
    } on FormatException catch (error) {
      setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(keySheetTitle(widget.kind)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const ValueKey('key-field'),
              controller: _editor,
              autofocus: true,
              obscureText: _isSecret && _obscureText,
              maxLines: _isSecret ? 1 : 4,
              maxLength: keySheetMaxLength(widget.kind),
              decoration: InputDecoration(
                errorText: _error,
                suffixIcon: _isSecret
                    ? IconButton(
                        key: const ValueKey('toggle-key-visibility'),
                        tooltip: _obscureText ? '显示密码' : '隐藏密码',
                        icon: Icon(
                          _obscureText
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () =>
                            setState(() => _obscureText = !_obscureText),
                      )
                    : null,
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _remember,
              title: const Text('在此设备记住密钥'),
              onChanged: (value) => setState(() => _remember = value ?? false),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              TextButton.icon(
                key: const ValueKey('random-key-button'),
                onPressed: _fillRandomKey,
                icon: const Icon(Icons.casino_outlined, size: 20),
                label: Text(keySheetRandomLabel(widget.kind)),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () {
                  if (!keySheetIsValid(widget.kind, _editor.text)) {
                    setState(
                        () => _error = keySheetValidationMessage(widget.kind));
                    return;
                  }
                  Navigator.pop(
                      context, KeySheetResult(_editor.text, _remember));
                },
                child: const Text('确定'),
              ),
            ],
          ),
        ],
      );
}
