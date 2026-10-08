import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/crypto_engine.dart';

class OutputEditorPane extends StatelessWidget {
  const OutputEditorPane({
    super.key,
    required this.controller,
    required this.height,
    required this.sourceMode,
    required this.stale,
    required this.onCopy,
    required this.onShare,
    required this.onRestore,
    required this.onClear,
  });

  final TextEditingController controller;
  final double height;
  final CryptoMode sourceMode;
  final bool stale;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onRestore;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final text = value.text;
          final colors = Theme.of(context).colorScheme;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 2,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('输出结果',
                          style: Theme.of(context).textTheme.titleMedium),
                      if (text.isNotEmpty)
                        Text(
                          '${sourceMode.algorithmLabel} · ${sourceMode.formatLabel}',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurface.withValues(alpha: .65),
                          ),
                        ),
                    ],
                  ),
                  Wrap(
                    spacing: 0,
                    children: [
                      IconButton(
                        tooltip: '复制结果',
                        onPressed: text.isEmpty ? null : onCopy,
                        icon: const Icon(Icons.copy_outlined),
                      ),
                      IconButton(
                        tooltip: '分享结果',
                        onPressed: text.isEmpty ? null : onShare,
                        icon: const Icon(Icons.share_outlined),
                      ),
                      IconButton(
                        tooltip: '结果变原始',
                        onPressed: text.isEmpty ? null : onRestore,
                        icon: const Icon(Icons.input_outlined),
                      ),
                    ],
                  ),
                ],
              ),
              if (stale && text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 15, color: colors.tertiary),
                      const SizedBox(width: 4),
                      Text(
                        '当前算法已变化，结果仍来自上一次操作',
                        style: TextStyle(fontSize: 12, color: colors.tertiary),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
              _OutputSurface(
                controller: controller,
                height: height,
                onClear: onClear,
              ),
              if (text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${text.runes.length} 字符 · ${utf8.encode(text).length} 字节',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.onSurface.withValues(alpha: .55),
                    ),
                  ),
                ),
            ],
          );
        },
      );
}

class _OutputSurface extends StatelessWidget {
  const _OutputSurface({
    required this.controller,
    required this.height,
    required this.onClear,
  });

  final TextEditingController controller;
  final double height;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('editor-output'),
      height: height,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outline, width: 1),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          TextField(
            controller: controller,
            readOnly: true,
            expands: true,
            maxLines: null,
            minLines: null,
            textAlignVertical: TextAlignVertical.top,
            style: TextStyle(color: colors.onSurface, height: 1.35),
            decoration: const InputDecoration(
              hintText: '处理结果会显示在这里',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.all(12),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: IconButton(
              tooltip: '清空结果',
              onPressed: controller.text.isEmpty ? null : onClear,
              icon: const Icon(Icons.cancel_outlined, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}
