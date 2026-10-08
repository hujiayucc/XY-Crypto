import 'package:flutter/material.dart';

class HomeStatusBanner extends StatelessWidget {
  const HomeStatusBanner({
    super.key,
    required this.busy,
    required this.error,
    required this.message,
  });

  final bool busy;
  final String? error;
  final String? message;

  @override
  Widget build(BuildContext context) {
    if (!busy && error == null && message == null) {
      return const SizedBox.shrink();
    }
    final colors = Theme.of(context).colorScheme;
    final isError = error != null;
    final color = isError
        ? colors.error
        : busy
            ? colors.primary
            : Colors.green.shade700;
    final icon = isError
        ? Icons.error_outline
        : busy
            ? Icons.sync
            : Icons.check_circle_outline;
    final text = error ?? (busy ? '正在处理，请稍候' : message!);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(child: Text(text, style: TextStyle(color: color))),
            ],
          ),
          if (busy)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(
                minHeight: 2,
                color: color,
                backgroundColor: color.withValues(alpha: .15),
              ),
            ),
        ],
      ),
    );
  }
}
