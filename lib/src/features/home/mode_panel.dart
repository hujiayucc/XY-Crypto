import 'package:flutter/material.dart';

import '../../core/crypto_engine.dart';

class ModePanel extends StatelessWidget {
  const ModePanel({
    super.key,
    required this.mode,
    required this.wide,
    required this.onAlgorithm,
    required this.onEncoding,
    required this.onKey,
  });

  final CryptoMode mode;
  final bool wide;
  final VoidCallback? onAlgorithm;
  final VoidCallback? onEncoding;
  final VoidCallback? onKey;

  @override
  Widget build(BuildContext context) {
    final algorithm = _choiceButton(
      context,
      label: '算法',
      value: mode.algorithmLabel,
      onTap: onAlgorithm,
    );
    final encoding = _choiceButton(
      context,
      label: '编码方式',
      value: mode.formatLabel,
      onTap: onEncoding,
    );
    final keyState = mode.needsKey ? _KeyStateChip(onTap: onKey) : null;
    final description = Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        mode.operationSpec.description,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .68),
          fontSize: 12,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (wide)
          Row(
            children: [
              Expanded(child: algorithm),
              const SizedBox(width: 10),
              SizedBox(width: 210, child: encoding),
              if (keyState != null) ...[
                const SizedBox(width: 10),
                Flexible(child: keyState),
              ],
            ],
          )
        else ...[
          algorithm,
          const SizedBox(height: 8),
          encoding,
          if (keyState != null) ...[
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerLeft, child: keyState),
          ],
        ],
        description,
      ],
    );
  }

  Widget _choiceButton(
    BuildContext context, {
    required String label,
    required String value,
    required VoidCallback? onTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: '$label：$value',
      child: InkWell(
        key: ValueKey('choice-$label'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 48,
          padding: const EdgeInsets.only(left: 12, right: 2),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: onTap == null
                  ? colors.outline.withValues(alpha: .45)
                  : colors.outline,
            ),
          ),
          child: Row(
            children: [
              Text(
                '$label：',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: colors.onSurface.withValues(alpha: .7),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const Icon(Icons.arrow_drop_down, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _KeyStateChip extends StatelessWidget {
  const _KeyStateChip({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: '需要密钥',
      child: InkWell(
        key: const ValueKey('key-state'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.outline.withValues(alpha: .65)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.key_outlined, size: 18, color: colors.primary),
              const SizedBox(width: 6),
              const Flexible(
                child: Text(
                  '需要密钥',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
