import 'dart:convert';
import 'dart:typed_data';

import 'license/default_license_keys.dart';
import 'license/rsa_crypto.dart';
import 'models.dart';
import 'platform/platform_info.dart';

/// Scanner and parser utilities for RSA identification barcode payloads.
class RsaIdentificationScanner {
  RsaIdentificationScanner({PlatformInfo? platformInfo})
    : _platformInfo = platformInfo ?? getPlatformInfo(),
      _rsaKeySetsByVersion = _defaultKeySetByVersion;

  RsaIdentificationScanner.withLicenseKeys({
    PlatformInfo? platformInfo,
    Map<SaLicenseVersion, SaLicenseRsaKeySet>? rsaKeySetsByVersion,
  }) : _platformInfo = platformInfo ?? getPlatformInfo(),
       _rsaKeySetsByVersion = rsaKeySetsByVersion ?? _defaultKeySetByVersion;

  static const Map<SaLicenseVersion, SaLicenseRsaKeySet> _defaultKeySetByVersion = {
    SaLicenseVersion.version1: SaLicenseRsaKeySet(
      keyFor128ByteBlocksPem: version1Key128Pem,
      keyFor74ByteBlockPem: version1Key74Pem,
    ),
    SaLicenseVersion.version2: SaLicenseRsaKeySet(
      keyFor128ByteBlocksPem: version2Key128Pem,
      keyFor74ByteBlockPem: version2Key74Pem,
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

    final key128 = RsaPublicKey.fromPem(keySet.keyFor128ByteBlocksPem);
    final key74 = RsaPublicKey.fromPem(keySet.keyFor74ByteBlockPem);

    final output = BytesBuilder(copy: false);
    for (final block in encryptedBlocks) {
      final key = block.length == 128 ? key128 : key74;
      final decrypted = rsaRawPublicOperation(block, key);
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

  SaDrivingLicense decryptAndParseLicenseBytes(Uint8List data) {
    final decrypted = decryptLicenseBytes(data);
    return parseDecryptedLicensePayload(decrypted.decryptedPayload);
  }

  SaDrivingLicense decryptAndParseLicenseBase64(String base64Payload) {
    final decrypted = decryptLicenseBase64(base64Payload);
    return parseDecryptedLicensePayload(decrypted.decryptedPayload);
  }

  SaDrivingLicense parseDecryptedLicensePayload(Uint8List decryptedPayload) {
    final markerIndex = decryptedPayload.indexOf(0x82);
    if (markerIndex < 0 || markerIndex + 1 >= decryptedPayload.length) {
      throw const FormatException('Could not find SA license payload section marker (0x82).');
    }

    var index = markerIndex + 2;

    final vehicleCodesResult = _readStrings(decryptedPayload, index, 4);
    final vehicleCodes = vehicleCodesResult.$1;
    index = vehicleCodesResult.$2;

    final surnameResult = _readString(decryptedPayload, index);
    final surname = surnameResult.$1;
    index = surnameResult.$2;
    var delimiter = surnameResult.$3;

    final initialsResult = _readString(decryptedPayload, index);
    final initials = initialsResult.$1;
    index = initialsResult.$2;
    delimiter = initialsResult.$3;

    var prDPCode = '';
    if (delimiter == 0xE0) {
      final prdpResult = _readString(decryptedPayload, index);
      prDPCode = prdpResult.$1;
      index = prdpResult.$2;
    }

    final idCountryResult = _readString(decryptedPayload, index);
    final idCountryOfIssue = idCountryResult.$1;
    index = idCountryResult.$2;

    final licenseCountryResult = _readString(decryptedPayload, index);
    final licenseCountryOfIssue = licenseCountryResult.$1;
    index = licenseCountryResult.$2;

    final vehicleRestrictionsResult = _readStrings(decryptedPayload, index, 4);
    final vehicleRestrictions = vehicleRestrictionsResult.$1;
    index = vehicleRestrictionsResult.$2;

    final licenseNumberResult = _readString(decryptedPayload, index);
    final licenseNumber = licenseNumberResult.$1;
    index = licenseNumberResult.$2;

    if (index + 13 > decryptedPayload.length) {
      throw const FormatException('Unexpected end of payload while reading ID number.');
    }
    final idNumber = String.fromCharCodes(Uint8List.sublistView(decryptedPayload, index, index + 13));
    index += 13;

    final idNumberType = decryptedPayload[index].toString().padLeft(2, '0');
    index += 1;

    final nibbleQueue = <int>[];
    while (index < decryptedPayload.length) {
      final currentByte = decryptedPayload[index++];
      if (currentByte == 0x57) {
        break;
      }

      nibbleQueue.add(currentByte >> 4);
      nibbleQueue.add(currentByte & 0x0F);
    }

    final licenseCodeIssueDates = _readNibbleDateList(nibbleQueue, 4);
    final driverRestrictionCodes = '${nibbleQueue.removeAt(0)}${nibbleQueue.removeAt(0)}';
    final prDPermitExpiryDate = _readNibbleDateString(nibbleQueue);
    final licenseIssueNumber = '${nibbleQueue.removeAt(0)}${nibbleQueue.removeAt(0)}';
    final birthdate = _readNibbleDateString(nibbleQueue);
    final licenseIssueDate = _readNibbleDateString(nibbleQueue);
    final licenseExpiryDate = _readNibbleDateString(nibbleQueue);

    final genderCode = '${nibbleQueue.removeAt(0)}${nibbleQueue.removeAt(0)}';
    final gender = genderCode == '01' ? 'male' : 'female';

    index += 3;
    if (index + 3 >= decryptedPayload.length) {
      throw const FormatException('Unexpected end of payload while reading image metadata.');
    }

    final imageWidth = decryptedPayload[index];
    index += 2;
    final imageHeight = decryptedPayload[index];

    return SaDrivingLicense(
      vehicleCodes: vehicleCodes,
      surname: surname,
      initials: initials,
      prDPCode: prDPCode,
      idCountryOfIssue: idCountryOfIssue,
      licenseCountryOfIssue: licenseCountryOfIssue,
      vehicleRestrictions: vehicleRestrictions,
      licenseNumber: licenseNumber,
      idNumber: idNumber,
      idNumberType: idNumberType,
      licenseCodeIssueDates: licenseCodeIssueDates,
      driverRestrictionCodes: driverRestrictionCodes,
      prDPermitExpiryDate: prDPermitExpiryDate,
      licenseIssueNumber: licenseIssueNumber,
      birthdate: birthdate,
      licenseIssueDate: licenseIssueDate,
      licenseExpiryDate: licenseExpiryDate,
      gender: gender,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
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

List<String> _readNibbleDateList(List<int> nibbleQueue, int length) {
  final dateList = <String>[];
  for (var i = 0; i < length; i++) {
    final date = _readNibbleDateString(nibbleQueue);
    if (date.isNotEmpty) {
      dateList.add(date);
    }
  }
  return dateList;
}

String _readNibbleDateString(List<int> nibbleQueue) {
  if (nibbleQueue.isEmpty) {
    throw const FormatException('Unexpected end of nibble queue while reading date.');
  }

  final m = nibbleQueue.removeAt(0);
  if (m == 10) {
    return '';
  }

  if (nibbleQueue.length < 7) {
    throw const FormatException('Invalid nibble queue length for date value.');
  }

  final c = nibbleQueue.removeAt(0);
  final d = nibbleQueue.removeAt(0);
  final y = nibbleQueue.removeAt(0);
  final m1 = nibbleQueue.removeAt(0);
  final m2 = nibbleQueue.removeAt(0);
  final d1 = nibbleQueue.removeAt(0);
  final d2 = nibbleQueue.removeAt(0);

  return '$m$c$d$y/$m1$m2/$d1$d2';
}

(List<String>, int) _readStrings(Uint8List data, int index, int length) {
  final strings = <String>[];
  var i = 0;
  while (i < length) {
    final valueBuffer = StringBuffer();
    while (true) {
      final currentByte = data[index++];
      if (currentByte == 0xE0) {
        break;
      } else if (currentByte == 0xE1) {
        if (valueBuffer.isNotEmpty) {
          i += 1;
        }
        break;
      }
      valueBuffer.writeCharCode(currentByte);
    }
    i += 1;
    if (valueBuffer.isNotEmpty) {
      strings.add(valueBuffer.toString());
    }
  }

  return (strings, index);
}

(String, int, int) _readString(Uint8List data, int index) {
  final valueBuffer = StringBuffer();
  var delimiter = 0xE0;

  while (true) {
    final currentByte = data[index++];
    if (currentByte == 0xE0 || currentByte == 0xE1) {
      delimiter = currentByte;
      break;
    }
    valueBuffer.writeCharCode(currentByte);
  }

  return (valueBuffer.toString(), index, delimiter);
}
