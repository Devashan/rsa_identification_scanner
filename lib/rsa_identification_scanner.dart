import 'dart:convert';
import 'dart:typed_data';

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

    if (parts.length != 12) {
      return false;
    }

    const requiredFieldIndexes = [0, 4, 5];
    for (final index in requiredFieldIndexes) {
      if (parts[index].trim().isEmpty) {
        return false;
      }
    }

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

  /// Returns a scan payload from text and/or raw bytes.
  ///
  /// This is useful for South African driving licence PDF417 barcodes where
  /// scanners often provide encrypted binary bytes without a UTF-8 `rawValue`.
  ///
  /// If the bytes can be represented as plain text, text is returned.
  /// Otherwise the bytes are encoded as a `BINARY_BASE64:<payload>` string.
  String? extractScannedPayload({
    String? rawValue,
    Uint8List? rawBytes,
    bool preferRawValue = true,
  }) {
    final normalizedRawValue = rawValue?.trim();
    final hasRawValue = normalizedRawValue != null && normalizedRawValue.isNotEmpty;

    if (preferRawValue && hasRawValue) {
      return normalizedRawValue;
    }

    if (rawBytes == null || rawBytes.isEmpty) {
      return hasRawValue ? normalizedRawValue : null;
    }

    final utf8Decoded = _tryDecodeUtf8(rawBytes);
    if (utf8Decoded != null && _isMostlyPrintableText(utf8Decoded)) {
      return utf8Decoded.trim();
    }

    if (!preferRawValue && hasRawValue) {
      return normalizedRawValue;
    }

    return 'BINARY_BASE64:${base64Encode(rawBytes)}';
  }

  /// Heuristic check for encrypted/binary SA licence payloads.
  bool isLikelyEncryptedBinaryLicenseData(Uint8List rawBytes) {
    if (rawBytes.length < 32) {
      return false;
    }

    final asUtf8 = _tryDecodeUtf8(rawBytes);
    if (asUtf8 == null) {
      return true;
    }

    return !_isMostlyPrintableText(asUtf8);
  }

  String? _tryDecodeUtf8(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return null;
    }
  }

  bool _isMostlyPrintableText(String text) {
    if (text.isEmpty) {
      return false;
    }

    var printable = 0;
    for (final rune in text.runes) {
      final isPrintableAscii = rune >= 32 && rune <= 126;
      final isWhitespace = rune == 9 || rune == 10 || rune == 13;
      if (isPrintableAscii || isWhitespace) {
        printable++;
      }
    }

    return printable / text.runes.length >= 0.9;
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
