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

enum SaLicenseVersion { version1, version2 }

class SaLicenseRsaKeySet {
  const SaLicenseRsaKeySet({
    required this.keyFor128ByteBlocksPem,
    required this.keyFor74ByteBlockPem,
  });

  final String keyFor128ByteBlocksPem;
  final String keyFor74ByteBlockPem;
}

class SaLicenseDecryptionResult {
  const SaLicenseDecryptionResult({
    required this.version,
    required this.decryptedPayload,
  });

  final SaLicenseVersion version;
  final Uint8List decryptedPayload;

  String get decryptedPayloadBase64 => base64Encode(decryptedPayload);
}

/// Scanner and parser utilities for RSA identification barcode payloads.
class RsaIdentificationScanner {
  RsaIdentificationScanner({PlatformInfo? platformInfo})
    : _platformInfo = platformInfo ?? getPlatformInfo(),
      _rsaKeySetsByVersion = {
        SaLicenseVersion.version2: const SaLicenseRsaKeySet(
          keyFor128ByteBlocksPem: _version2Key128Pem,
          keyFor74ByteBlockPem: _version2Key74Pem,
        ),
      };

  RsaIdentificationScanner.withLicenseKeys({
    PlatformInfo? platformInfo,
    Map<SaLicenseVersion, SaLicenseRsaKeySet>? rsaKeySetsByVersion,
  }) : _platformInfo = platformInfo ?? getPlatformInfo(),
       _rsaKeySetsByVersion =
           rsaKeySetsByVersion ?? {
             SaLicenseVersion.version2: const SaLicenseRsaKeySet(
               keyFor128ByteBlocksPem: _version2Key128Pem,
               keyFor74ByteBlockPem: _version2Key74Pem,
             ),
           };

  final PlatformInfo _platformInfo;
  final Map<SaLicenseVersion, SaLicenseRsaKeySet> _rsaKeySetsByVersion;

  bool isSupported() {
    return _platformInfo.isAndroid || _platformInfo.isIOS || _platformInfo.isWeb;
  }

  bool isRSAIdNewFormat(String data) {
    if (data.trim().isEmpty) return false;

    final parts = data.split('|').map((part) => part.trim()).toList(growable: false);

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

    final parts = data.split('|').map((part) => part.trim()).toList(growable: false);
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

  SaLicenseVersion detectLicenseVersion(Uint8List data) {
    if (data.length < 4) {
      throw const FormatException('License data must include at least 4 bytes for version detection.');
    }

    if (_bytesEqualAt(data, const [0x01, 0x9B, 0x09, 0x45])) {
      return SaLicenseVersion.version2;
    }

    if (_bytesEqualAt(data, const [0x01, 0xE1, 0x02, 0x45])) {
      return SaLicenseVersion.version1;
    }

    throw FormatException(
      'Unknown South African license version bytes: ${_toHex(data.sublist(0, 4))}.',
    );
  }

  Uint8List decodeBase64Payload(String base64Payload) {
    try {
      final decoded = base64Decode(base64Payload.trim());
      return Uint8List.fromList(decoded);
    } on FormatException catch (error) {
      throw FormatException('Invalid base64 payload: ${error.message}');
    }
  }

  Uint8List extractEncryptedPayload(Uint8List data) {
    if (data.length != 720) {
      throw FormatException('South African license payload must be exactly 720 bytes; got ${data.length}.');
    }

    if (data[4] != 0x00 || data[5] != 0x00) {
      throw const FormatException('Expected 2-byte padding marker 0x00 0x00 after version bytes.');
    }

    return Uint8List.sublistView(data, 6);
  }

  List<Uint8List> splitEncryptedBlocks(Uint8List encryptedPayload) {
    if (encryptedPayload.length != 714) {
      throw FormatException('Encrypted payload must be exactly 714 bytes; got ${encryptedPayload.length}.');
    }

    final blocks = <Uint8List>[];
    var offset = 0;

    for (var i = 0; i < 5; i++) {
      blocks.add(Uint8List.sublistView(encryptedPayload, offset, offset + 128));
      offset += 128;
    }

    blocks.add(Uint8List.sublistView(encryptedPayload, offset, offset + 74));
    return blocks;
  }

  SaLicenseDecryptionResult decryptLicenseBytes(Uint8List data) {
    final version = detectLicenseVersion(data);
    final keySet = _rsaKeySetsByVersion[version];
    if (keySet == null) {
      throw UnsupportedError(
        'No RSA key set configured for $version. '
        'Provide keys via RsaIdentificationScanner.withLicenseKeys.',
      );
    }

    final encryptedPayload = extractEncryptedPayload(data);
    final encryptedBlocks = splitEncryptedBlocks(encryptedPayload);

    final key128 = _RsaPublicKey.fromPem(keySet.keyFor128ByteBlocksPem);
    final key74 = _RsaPublicKey.fromPem(keySet.keyFor74ByteBlockPem);

    final output = BytesBuilder(copy: false);
    for (final block in encryptedBlocks) {
      final key = block.length == 128 ? key128 : key74;
      final decrypted = _rsaRawPublicOperation(block, key);
      output.add(decrypted);
    }

    return SaLicenseDecryptionResult(
      version: version,
      decryptedPayload: output.toBytes(),
    );
  }

  SaLicenseDecryptionResult decryptLicenseBase64(String base64Payload) {
    final data = decodeBase64Payload(base64Payload);
    return decryptLicenseBytes(data);
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

  bool _bytesEqualAt(Uint8List data, List<int> expected) {
    if (data.length < expected.length) {
      return false;
    }

    for (var i = 0; i < expected.length; i++) {
      if (data[i] != expected[i]) {
        return false;
      }
    }

    return true;
  }

  String _toHex(Uint8List bytes) {
    final buffer = StringBuffer();
    for (final byte in bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}

class _RsaPublicKey {
  const _RsaPublicKey({required this.modulus, required this.exponent});

  final BigInt modulus;
  final BigInt exponent;

  int get modulusByteLength => (modulus.bitLength + 7) ~/ 8;

  factory _RsaPublicKey.fromPem(String pem) {
    final b64 = pem
        .replaceAll('-----BEGIN RSA PUBLIC KEY-----', '')
        .replaceAll('-----END RSA PUBLIC KEY-----', '')
        .replaceAll(RegExp(r'\s+'), '');

    final der = base64Decode(b64);
    final values = _parsePkcs1RsaPublicKey(der);

    return _RsaPublicKey(modulus: values.$1, exponent: values.$2);
  }

  static (BigInt, BigInt) _parsePkcs1RsaPublicKey(Uint8List der) {
    var offset = 0;

    if (der[offset++] != 0x30) {
      throw const FormatException('RSA key DER must start with ASN.1 sequence.');
    }

    final seqLengthResult = _readDerLength(der, offset);
    final sequenceLength = seqLengthResult.$1;
    offset = seqLengthResult.$2;

    if (offset + sequenceLength > der.length) {
      throw const FormatException('Invalid DER sequence length for RSA key.');
    }

    final modulusResult = _readDerInteger(der, offset);
    final modulus = modulusResult.$1;
    offset = modulusResult.$2;

    final exponentResult = _readDerInteger(der, offset);
    final exponent = exponentResult.$1;

    return (modulus, exponent);
  }

  static (BigInt, int) _readDerInteger(Uint8List der, int offset) {
    if (der[offset++] != 0x02) {
      throw const FormatException('Expected ASN.1 INTEGER tag in RSA key DER.');
    }

    final lengthResult = _readDerLength(der, offset);
    final valueLength = lengthResult.$1;
    offset = lengthResult.$2;

    if (offset + valueLength > der.length) {
      throw const FormatException('Invalid ASN.1 INTEGER length in RSA key DER.');
    }

    final valueBytes = Uint8List.sublistView(der, offset, offset + valueLength);
    final unsignedBytes =
        valueBytes.isNotEmpty && valueBytes.first == 0x00
            ? Uint8List.sublistView(valueBytes, 1)
            : valueBytes;

    final value = _bigIntFromBytes(unsignedBytes);
    return (value, offset + valueLength);
  }

  static (int, int) _readDerLength(Uint8List der, int offset) {
    final first = der[offset++];

    if ((first & 0x80) == 0) {
      return (first, offset);
    }

    final count = first & 0x7F;
    if (count == 0 || count > 4) {
      throw const FormatException('Unsupported DER length encoding.');
    }

    var length = 0;
    for (var i = 0; i < count; i++) {
      length = (length << 8) | der[offset++];
    }

    return (length, offset);
  }
}

Uint8List _rsaRawPublicOperation(Uint8List ciphertext, _RsaPublicKey key) {
  final keySize = key.modulusByteLength;
  if (ciphertext.length != keySize) {
    throw FormatException(
      'Ciphertext block length (${ciphertext.length}) does not match RSA modulus size ($keySize).',
    );
  }

  final input = _bigIntFromBytes(ciphertext);
  final output = input.modPow(key.exponent, key.modulus);
  return _bigIntToBytes(output, keySize);
}

BigInt _bigIntFromBytes(Uint8List bytes) {
  var result = BigInt.zero;
  for (final byte in bytes) {
    result = (result << 8) | BigInt.from(byte);
  }
  return result;
}

Uint8List _bigIntToBytes(BigInt value, int length) {
  final result = Uint8List(length);
  var current = value;

  for (var i = length - 1; i >= 0; i--) {
    result[i] = (current & BigInt.from(0xFF)).toInt();
    current >>= 8;
  }

  return result;
}

const String _version2Key128Pem = '''
-----BEGIN RSA PUBLIC KEY-----
MIGWAoGBAMqfGO9sPz+kxaRh/qVKsZQGul7NdG1gonSS3KPXTjtcHTFfexA4MkGA
mwKeu9XeTRFgMMxX99WmyaFvNzuxSlCFI/foCkx0TZCFZjpKFHLXryxWrkG1Bl9+
+gKTvTJ4rWk1RvnxYhm3n/Rxo2NoJM/822Oo7YBZ5rmk8NuJU4HLAhAYcJLaZFTO
sYU+aRX4RmoF
-----END RSA PUBLIC KEY-----
''';

const String _version2Key74Pem = '''
-----BEGIN RSA PUBLIC KEY-----
MF8CSwC0BKDfEdHKz/GhoEjU1XP5U6YsWD10klknVhpteh4rFAQlJq9wtVBUc5Dq
bsdI0w/bga20kODDahmGtASy9fae9dobZj5ZUJEw5wIQMJz+2XGf4qXiDJu0R2U4
Kw==
-----END RSA PUBLIC KEY-----
''';

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
