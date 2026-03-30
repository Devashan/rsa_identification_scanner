import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rsa_identification_scanner/rsa_identification_scanner.dart';

class _FakePlatformInfo implements PlatformInfo {
  const _FakePlatformInfo({
    this.isWeb = false,
    this.isAndroid = false,
    this.isIOS = false,
    this.isMacOS = false,
    this.isWindows = false,
    this.isLinux = false,
  });

  @override
  final bool isWeb;

  @override
  final bool isAndroid;

  @override
  final bool isIOS;

  @override
  final bool isMacOS;

  @override
  final bool isWindows;

  @override
  final bool isLinux;
}

void main() {
  final scanner = RsaIdentificationScanner();

  const validNewFormatData =
      'DOE|JOHN|M|ZA|8001015009087|19800101|ZA|ID|20230101|DHA|1234567890|7';

  group('isRSAIdNewFormat', () {
    test('returns true for exactly 12 fields with required fields populated', () {
      expect(scanner.isRSAIdNewFormat(validNewFormatData), isTrue);
    });

    test('returns false for wrong length (11 fields)', () {
      const dataWith11Fields =
          'DOE|JOHN|M|ZA|8001015009087|19800101|ZA|ID|20230101|DHA|1234567890';

      expect(scanner.isRSAIdNewFormat(dataWith11Fields), isFalse);
    });

    test('returns false for wrong length (13 fields)', () {
      const dataWith13Fields =
          'DOE|JOHN|M|ZA|8001015009087|19800101|ZA|ID|20230101|DHA|1234567890|7|EXTRA';

      expect(scanner.isRSAIdNewFormat(dataWith13Fields), isFalse);
    });

    test('returns false when required fields are empty', () {
      const missingSurname =
          '|JOHN|M|ZA|8001015009087|19800101|ZA|ID|20230101|DHA|1234567890|7';
      const missingIdNumber =
          'DOE|JOHN|M|ZA||19800101|ZA|ID|20230101|DHA|1234567890|7';
      const missingDateOfBirth =
          'DOE|JOHN|M|ZA|8001015009087||ZA|ID|20230101|DHA|1234567890|7';

      expect(scanner.isRSAIdNewFormat(missingSurname), isFalse);
      expect(scanner.isRSAIdNewFormat(missingIdNumber), isFalse);
      expect(scanner.isRSAIdNewFormat(missingDateOfBirth), isFalse);
    });
  });

  group('extractScannedPayload', () {
    test('returns trimmed raw value when available', () {
      final payload = scanner.extractScannedPayload(
        rawValue:
            '  DOE|JOHN|M|ZA|8001015009087|19800101|ZA|ID|20230101|DHA|1234567890|7  ',
      );

      expect(payload, 'DOE|JOHN|M|ZA|8001015009087|19800101|ZA|ID|20230101|DHA|1234567890|7');
    });

    test('returns decoded text from raw bytes', () {
      final payload = scanner.extractScannedPayload(
        rawBytes: Uint8List.fromList('TEXT_PAYLOAD'.codeUnits),
      );

      expect(payload, 'TEXT_PAYLOAD');
    });

    test('returns base64 wrapped payload for binary bytes', () {
      final payload = scanner.extractScannedPayload(
        rawBytes: Uint8List.fromList(List<int>.generate(64, (index) => index)),
      );

      expect(payload, startsWith('BINARY_BASE64:'));
    });
  });

  group('isLikelyEncryptedBinaryLicenseData', () {
    test('returns true for non-UTF8 binary data with reasonable length', () {
      final bytes = Uint8List.fromList(List<int>.filled(40, 0xFF));

      expect(scanner.isLikelyEncryptedBinaryLicenseData(bytes), isTrue);
    });

    test('returns false for readable text data', () {
      final bytes = Uint8List.fromList(
        'DOE|JOHN|M|ZA|8001015009087|19800101|ZA|ID'.codeUnits,
      );

      expect(scanner.isLikelyEncryptedBinaryLicenseData(bytes), isFalse);
    });
  });

  group('parseRSAIdNewFormat', () {
    test('parses valid exactly-12 field input', () {
      final parsed = scanner.parseRSAIdNewFormat(validNewFormatData);

      expect(parsed, isNotNull);
      expect(parsed!.surname, 'DOE');
      expect(parsed.firstNames, 'JOHN');
      expect(parsed.idNumber, '8001015009087');
      expect(parsed.dateOfBirth, '19800101');
      expect(parsed.checkDigit, '7');
    });

    test('returns null for wrong-length input', () {
      const dataWith11Fields =
          'DOE|JOHN|M|ZA|8001015009087|19800101|ZA|ID|20230101|DHA|1234567890';

      expect(scanner.parseRSAIdNewFormat(dataWith11Fields), isNull);
    });

    test('trims each parsed field', () {
      const dataWithWhitespace =
          ' DOE | JOHN | M | ZA | 8001015009087 | 19800101 | ZA | ID | 20230101 | DHA | 1234567890 | 7 ';

      final parsed = scanner.parseRSAIdNewFormat(dataWithWhitespace);

      expect(parsed, isNotNull);
      expect(parsed!.surname, 'DOE');
      expect(parsed.firstNames, 'JOHN');
      expect(parsed.idNumber, '8001015009087');
      expect(parsed.checkDigit, '7');
    });
  });

  group('isSupported', () {
    test('returns true on Android, iOS, and Web', () {
      expect(
        RsaIdentificationScanner(
          platformInfo: const _FakePlatformInfo(isAndroid: true),
        ).isSupported(),
        isTrue,
      );
      expect(
        RsaIdentificationScanner(
          platformInfo: const _FakePlatformInfo(isIOS: true),
        ).isSupported(),
        isTrue,
      );
      expect(
        RsaIdentificationScanner(
          platformInfo: const _FakePlatformInfo(isWeb: true),
        ).isSupported(),
        isTrue,
      );
    });

    test('returns false on unsupported desktop-only platforms', () {
      expect(
        RsaIdentificationScanner(
          platformInfo: const _FakePlatformInfo(isMacOS: true),
        ).isSupported(),
        isFalse,
      );
      expect(
        RsaIdentificationScanner(
          platformInfo: const _FakePlatformInfo(isWindows: true),
        ).isSupported(),
        isFalse,
      );
      expect(
        RsaIdentificationScanner(
          platformInfo: const _FakePlatformInfo(isLinux: true),
        ).isSupported(),
        isFalse,
      );
    });
  });

  group('decodeBase64Payload', () {
    test('decodes base64 and ignores surrounding whitespace', () {
      final decoded = scanner.decodeBase64Payload('  SGVsbG8=\n');

      expect(decoded, Uint8List.fromList('Hello'.codeUnits));
    });

    test('throws FormatException with context for invalid base64', () {
      expect(
        () => scanner.decodeBase64Payload('not-base64!!'),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            startsWith('Invalid base64 payload:'),
          ),
        ),
      );
    });
  });

  group('extractEncryptedPayload', () {
    test('extracts 714-byte encrypted payload after 6-byte header', () {
      final bytes = Uint8List.fromList([
        0x01,
        0x9B,
        0x09,
        0x45,
        0x00,
        0x00,
        ...List<int>.generate(714, (index) => index % 256),
      ]);

      final extracted = scanner.extractEncryptedPayload(bytes);

      expect(extracted.length, 714);
      expect(extracted.first, 0);
      expect(extracted[1], 1);
      expect(extracted.last, 201);
    });

    test('throws when payload is not exactly 720 bytes', () {
      expect(
        () => scanner.extractEncryptedPayload(Uint8List.fromList(List<int>.filled(719, 0))),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws when two-byte padding marker is not 0x00 0x00', () {
      final invalidPadding = Uint8List.fromList([
        0x01,
        0x9B,
        0x09,
        0x45,
        0x00,
        0x01,
        ...List<int>.filled(714, 0),
      ]);

      expect(
        () => scanner.extractEncryptedPayload(invalidPadding),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('license decryption flow', () {
    test('detects version 1 bytes', () {
      final version = scanner.detectLicenseVersion(
        Uint8List.fromList([0x01, 0xE1, 0x02, 0x45, 0x00, 0x00]),
      );

      expect(version, SaLicenseVersion.version1);
    });

    test('detects version 2 bytes', () {
      final version = scanner.detectLicenseVersion(
        Uint8List.fromList([0x01, 0x9B, 0x09, 0x45, 0x00, 0x00]),
      );

      expect(version, SaLicenseVersion.version2);
    });

    test('throws for unknown version bytes', () {
      expect(
        () => scanner.detectLicenseVersion(Uint8List.fromList([1, 2, 3, 4])),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws UnsupportedError when key set for detected version is missing', () {
      final scannerWithoutV2Keys = RsaIdentificationScanner.withLicenseKeys(
        rsaKeySetsByVersion: const {
          SaLicenseVersion.version1: SaLicenseRsaKeySet(
            keyFor128ByteBlocksPem: '-----BEGIN PUBLIC KEY-----\nMFwwDQYJKoZIhvcNAQEBBQADSwAwSAJBAK2fA+J9M6J7fOv5N2V8J8LByfQYQf5Y\nJp0dVb0f9u9AKeY4b7kShQ0X9vNv4P8xL2i4s7hQOkQWf3Q5qjY6k5ECAwEAAQ==\n-----END PUBLIC KEY-----',
            keyFor74ByteBlockPem: '-----BEGIN PUBLIC KEY-----\nMFwwDQYJKoZIhvcNAQEBBQADSwAwSAJBAK2fA+J9M6J7fOv5N2V8J8LByfQYQf5Y\nJp0dVb0f9u9AKeY4b7kShQ0X9vNv4P8xL2i4s7hQOkQWf3Q5qjY6k5ECAwEAAQ==\n-----END PUBLIC KEY-----',
          ),
        },
      );

      final version2Bytes = Uint8List.fromList([
        0x01,
        0x9B,
        0x09,
        0x45,
        0x00,
        0x00,
        ...List<int>.filled(714, 0),
      ]);

      expect(
        () => scannerWithoutV2Keys.decryptLicenseBytes(version2Bytes),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('splits encrypted payload into expected 6 blocks', () {
      final encrypted = Uint8List.fromList(List<int>.filled(714, 0));
      final blocks = scanner.splitEncryptedBlocks(encrypted);

      expect(blocks.length, 6);
      expect(blocks.take(5).every((block) => block.length == 128), isTrue);
      expect(blocks.last.length, 74);
    });

    test('decrypts a zeroed payload into zeroed binary output', () {
      final licenseBytes = Uint8List.fromList([
        0x01,
        0x9B,
        0x09,
        0x45,
        0x00,
        0x00,
        ...List<int>.filled(714, 0),
      ]);

      final result = scanner.decryptLicenseBytes(licenseBytes);

      expect(result.version, SaLicenseVersion.version2);
      expect(result.decryptedPayload.length, 714);
      expect(result.decryptedPayload.every((byte) => byte == 0), isTrue);
      expect(result.decryptedPayloadBase64, base64Encode(List<int>.filled(714, 0)));
    });

    test('decrypts a version 1 zeroed payload into zeroed binary output', () {
      final licenseBytes = Uint8List.fromList([
        0x01,
        0xE1,
        0x02,
        0x45,
        0x00,
        0x00,
        ...List<int>.filled(714, 0),
      ]);

      final result = scanner.decryptLicenseBytes(licenseBytes);

      expect(result.version, SaLicenseVersion.version1);
      expect(result.decryptedPayload.length, 714);
      expect(result.decryptedPayload.every((byte) => byte == 0), isTrue);
      expect(result.decryptedPayloadBase64, base64Encode(List<int>.filled(714, 0)));
    });
  });
}
