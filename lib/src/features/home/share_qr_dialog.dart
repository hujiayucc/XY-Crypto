import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:zxing2/qrcode.dart';
import '../../core/share_codec.dart';

class ShareQrDialog extends StatelessWidget {
  const ShareQrDialog({
    super.key,
    required this.code,
    required this.link,
    this.onCopy,
  });

  final QRCode code;
  final String link;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('二维码分享'),
      content: SizedBox(
        width: 300,
        height: 350,
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: CustomPaint(painter: _QrPainter(code)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${ShareCodec.encodedPayloadLength(Uri.parse(link))} / 5000',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            const Text('使用扫一扫识别后可直接导入'),
          ],
        ),
      ),
      actions: [
        if (onCopy != null)
          TextButton(
            onPressed: () {
              onCopy!();
              Navigator.pop(context);
            },
            child: const Text('复制链接'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.code);

  final QRCode code;

  @override
  void paint(Canvas canvas, Size size) {
    final matrix = code.matrix!;
    final background = Paint()..color = Colors.white;
    final foreground = Paint()..color = Colors.black;
    canvas.drawRect(Offset.zero & size, background);

    final moduleCount = matrix.width + 8;
    final scale = math.min(size.width, size.height) / moduleCount;
    final left = (size.width - matrix.width * scale) / 2;
    final top = (size.height - matrix.height * scale) / 2;
    for (var y = 0; y < matrix.height; y++) {
      for (var x = 0; x < matrix.width; x++) {
        if (matrix.get(x, y) != 1) continue;
        final x0 = left + x * scale;
        final y0 = top + y * scale;
        canvas.drawRect(
          Rect.fromLTRB(x0, y0, x0 + scale + 0.5, y0 + scale + 0.5),
          foreground,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrPainter oldDelegate) => false;
}