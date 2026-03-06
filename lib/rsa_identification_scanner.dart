import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'src/platform/platform_info.dart';

typedef NewIdFormatRecord = ({
  String surname,
  String firstNames,
  String gender,
  String countryCode,
  String idNumber,
  String dateOfBirth,
  String nationality,
  String idType,
  String issueDate,
  String issuerCode,
  String personalNumber,
  String checkDigit,
});

/// A Calculator.
class RsaIdentificationScanner {
  RsaIdentificationScanner({PlatformInfo? platformInfo})
    : _platformInfo = platformInfo ?? getPlatformInfo();

  final PlatformInfo _platformInfo;

  bool isSupported() {
    return _platformInfo.isAndroid || _platformInfo.isIOS || _platformInfo.isWeb;
  }

  bool isRSAIdNewFormat(String data) {
    if (data.trim().isEmpty) return false;

    final parts = data.split('|');
    if (parts.length < 12) return false; // Not enough parts for new format
    return true;
  }

  NewIdFormatRecord? parseRSAIdNewFormat(String data) {
    if (!isRSAIdNewFormat(data)) {
      return null;
    }

    final parts = data.split('|');
    return (
      surname: parts[0],
      firstNames: parts[1],
      gender: parts[2],
      countryCode: parts[3],
      idNumber: parts[4],
      dateOfBirth: parts[5],
      nationality: parts[6],
      idType: parts[7],
      issueDate: parts[8],
      issuerCode: parts[9],
      personalNumber: parts[10],
      checkDigit: parts[11],
    );
  }

  String getPlatform() {
    return describePlatform(_platformInfo);
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
