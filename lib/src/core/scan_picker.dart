import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:zxing2/qrcode.dart';
import 'privacy_runtime.dart';
import '../features/legal/legal_consent.dart';

Future<String?> pickQrImage() async {
  final selection =
      await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
  if (selection == null) return null;
  final file = selection.files.single;
  final data = file.bytes ??
      (file.path == null ? null : await File(file.path!).readAsBytes());
  if (data == null) throw const FormatException('图片读取失败');
  if (data.length > 20 * 1024 * 1024) {
    throw const FormatException('请选择小于 20 MB 的图片');
  }
  var image = img.decodeImage(data);
  if (image == null) throw const FormatException('请选择 PNG 或 JPEG 图片');
  if (image.width > 2048 || image.height > 2048) {
    image = img.copyResize(image,
        width: image.width >= image.height ? 2048 : null,
        height: image.height > image.width ? 2048 : null);
  }
  final pixels = Int32List(image.width * image.height);
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);
      pixels[y * image.width + x] = (255 << 24) |
          (pixel.r.toInt() << 16) |
          (pixel.g.toInt() << 8) |
          pixel.b.toInt();
    }
  }
  final source = RGBLuminanceSource(image.width, image.height, pixels);
  return QRCodeReader().decode(BinaryBitmap(HybridBinarizer(source))).text;
}

enum ScanSource { camera, image }

Future<ScanSource?> showScanDisclosure(BuildContext context) =>
    showDialog<ScanSource>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('选择二维码识别方式'),
        content: SingleChildScrollView(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              const Text(
                  '相机仅用于识别二维码，不保存录像。Android 相机扫码使用 Google ML Kit，在本机识别图像；该 SDK 会为诊断和使用情况分析处理设备型号、系统版本、应用信息、每次安装标识符、性能指标和事件信息，并可能经 HTTPS 发送给 Google。'),
              const SizedBox(height: 12),
              const Text('选择图片识别使用本地解码，无需相机或 ML Kit。取消或拒绝相机权限不影响本地加解密。'),
              TextButton(
                  onPressed: () => Navigator.of(dialogContext).push(
                      MaterialPageRoute<void>(
                          builder: (_) => const LegalDocumentPage(
                              document: LegalDocument.sdk))),
                  child: const Text('查看第三方 SDK 与组件清单')),
            ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, ScanSource.image),
              child: const Text('选择图片')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, ScanSource.camera),
              child: const Text('同意并使用相机')),
        ],
      ),
    );

Future<String?> scanText(BuildContext context) async {
  if (Platform.isWindows || Platform.isLinux) return pickQrImage();
  final hasPermission = await PrivacyRuntime.hasCameraPermission();
  if (!context.mounted) return null;
  if (!hasPermission) {
    final source = await showScanDisclosure(context);
    if (!context.mounted || source == null) return null;
    if (source == ScanSource.image) return pickQrImage();
  }
  final permission = await PrivacyRuntime.prepareScanner();
  if (!context.mounted) return null;
  if (permission != 'ready') {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('相机未获准或正在授权。本地加解密仍可使用，也可选择图片识别；权限可在隐私中心管理。')));
    return null;
  }
  return Navigator.of(context)
      .push<String>(MaterialPageRoute(builder: (_) => const _ScanPage()));
}

class _ScanPage extends StatefulWidget {
  const _ScanPage();
  @override
  State<_ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<_ScanPage> {
  bool _finished = false;
  bool _picking = false;
  void _accept(String value) {
    if (_finished || value.isEmpty || !mounted) return;
    _finished = true;
    Navigator.pop(context, value);
  }

  Future<void> _pick() async {
    setState(() => _picking = true);
    try {
      final text = await pickQrImage();
      if (text != null) _accept(text);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('识别失败：$error')));
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('扫一扫'), actions: [
          IconButton(
              tooltip: '从图片识别',
              onPressed: _picking ? null : _pick,
              icon: const Icon(Icons.photo_library_outlined)),
        ]),
        body: MobileScanner(
            errorBuilder: (context, error, child) => Center(
                child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('相机暂未可用。你仍可选择二维码图片，或返回首页使用本地加解密。'),
                      TextButton(
                          onPressed: _picking ? null : _pick,
                          child: const Text('选择图片')),
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('返回首页')),
                    ]))),
            onDetect: (capture) {
              if (_picking || _finished) return;
              for (final barcode in capture.barcodes) {
                final value = barcode.rawValue;
                if (value != null && value.isNotEmpty) {
                  _accept(value);
                  return;
                }
              }
            }),
      );
}
