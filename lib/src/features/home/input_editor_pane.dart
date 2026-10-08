import 'dart:convert';

import 'package:flutter/material.dart';

class InputEditorPane extends StatelessWidget {
  const InputEditorPane({
    super.key,
    required this.controller,
    required this.height,
    required this.onImport,
    required this.onEmoji,
    required this.onClear,
  });

  final TextEditingController controller;
  final double height;
  final VoidCallback onImport;
  final VoidCallback onEmoji;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final text = value.text;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PaneHeader(
                title: '输入',
                count:
                    '${text.runes.length} 字符 · ${utf8.encode(text).length} 字节',
                action: TextButton.icon(
                  key: const ValueKey('import-text-file'),
                  onPressed: onImport,
                  icon: const Icon(Icons.folder_open, size: 18),
                  label: const Text('导入文本文件'),
                ),
              ),
              const SizedBox(height: 6),
              _EditorSurface(
                key: const ValueKey('editor-input'),
                controller: controller,
                height: height,
                hintText: '请输入需要处理的内容',
                clearTooltip: '清空原始',
                onClear: onClear,
                leading: IconButton(
                  tooltip: '表情',
                  onPressed: onEmoji,
                  icon: const Icon(Icons.emoji_emotions_outlined, size: 22),
                ),
              ),
            ],
          );
        },
      );
}

class _PaneHeader extends StatelessWidget {
  const _PaneHeader({
    required this.title,
    required this.count,
    required this.action,
  });

  final String title;
  final String count;
  final Widget action;

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 4,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextSpan(
                  text: '  $count',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: .62),
                  ),
                ),
              ],
            ),
          ),
          action,
        ],
      );
}

class _EditorSurface extends StatelessWidget {
  const _EditorSurface({
    super.key,
    required this.controller,
    required this.height,
    required this.hintText,
    required this.clearTooltip,
    required this.onClear,
    this.leading,
  });

  final TextEditingController controller;
  final double height;
  final String hintText;
  final String clearTooltip;
  final VoidCallback onClear;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outline, width: 1),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          TextField(
            controller: controller,
            expands: true,
            maxLines: null,
            minLines: null,
            textAlignVertical: TextAlignVertical.top,
            style: TextStyle(color: colors.onSurface, height: 1.35),
            decoration: InputDecoration(
              hintText: hintText,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (leading != null) leading! else const SizedBox(width: 48),
                IconButton(
                  tooltip: clearTooltip,
                  onPressed: controller.text.isEmpty ? null : onClear,
                  icon: const Icon(Icons.cancel_outlined, size: 22),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
