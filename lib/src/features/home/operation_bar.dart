import 'package:flutter/material.dart';

import '../../core/crypto_engine.dart';

class OperationBar extends StatelessWidget {
  const OperationBar({
    super.key,
    required this.spec,
    required this.busy,
    required this.wide,
    required this.onPrimary,
    required this.onSecondary,
  });

  final CryptoOperationSpec spec;
  final bool busy;
  final bool wide;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) {
    final primary = FilledButton.icon(
      onPressed: busy ? null : onPrimary,
      icon: Icon(_iconFor(spec.kind)),
      label: Text(spec.primaryLabel),
    );
    final secondaryLabel = spec.secondaryLabel;
    if (!spec.supportsSecondary || secondaryLabel == null) {
      return SizedBox(
        width: wide ? 150 : double.infinity,
        child: primary,
      );
    }

    final secondary = OutlinedButton.icon(
      onPressed: busy ? null : onSecondary,
      icon: const Icon(Icons.lock_open_outlined),
      label: Text(secondaryLabel),
    );
    if (wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [primary, const SizedBox(height: 10), secondary],
      );
    }
    return Row(
      children: [
        Expanded(child: primary),
        const SizedBox(width: 10),
        Expanded(child: secondary),
      ],
    );
  }

  IconData _iconFor(CryptoOperationKind kind) => switch (kind) {
        CryptoOperationKind.conversion => Icons.transform,
        CryptoOperationKind.encryption => Icons.lock_outline,
        CryptoOperationKind.digest => Icons.tag,
        CryptoOperationKind.keyedDigest => Icons.key_outlined,
        CryptoOperationKind.derivation => Icons.password_outlined,
        CryptoOperationKind.signature => Icons.draw_outlined,
      };
}
