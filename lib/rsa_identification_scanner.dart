import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// A Calculator.
class RsaIdentificationScanner {
  /// Returns [value] plus 1.
  int addOne(int value) => value + 1;

  String getPlatform() {
    return Platform.isAndroid
        ? "Android"
        : Platform.isIOS
        ? "iOS"
        : Platform.isMacOS
        ? "MacOS"
        : Platform.isWindows
        ? "Windows"
        : Platform.isLinux
        ? "Linux"
        : kIsWeb
        ? "Web"
        : "Unknown";
  }
}

class RsaScannerView extends StatefulWidget {
  final List<BarcodeFormat> formats;
  final Size? cameraResolution;
  final DetectionSpeed detectionSpeed;
  final int detectionTimeoutMs;
  final bool returnImage;
  final bool torchEnabled;
  final bool invertImage;
  final bool autoZoom;
  final Function(BarcodeCapture) onScanResult;

  const RsaScannerView({
    super.key,
    this.formats = const [],
    this.cameraResolution,
    this.detectionSpeed = DetectionSpeed.normal,
    this.detectionTimeoutMs = 250,
    this.returnImage = false,
    this.torchEnabled = false,
    this.invertImage = false,
    this.autoZoom = false,
    required this.onScanResult,
  });

  @override
  State<RsaScannerView> createState() => _RsaScannerViewState();
}

class _RsaScannerViewState extends State<RsaScannerView> {
  late MobileScannerController controller;

  @override
  void initState() {
    super.initState();
    controller = MobileScannerController(
      cameraResolution: widget.cameraResolution,
      detectionSpeed: widget.detectionSpeed,
      detectionTimeoutMs: widget.detectionTimeoutMs,
      formats: widget.formats,
      returnImage: widget.returnImage,
      torchEnabled: widget.torchEnabled,
      invertImage: widget.invertImage,
      autoZoom: widget.autoZoom,
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MobileScanner(
      controller: controller,
      onDetect: (capture) {
        widget.onScanResult(capture);
      },
    );
  }
}
