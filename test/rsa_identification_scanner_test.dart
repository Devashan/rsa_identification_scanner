import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rsa_identification_scanner/rsa_identification_scanner.dart';
import 'package:rsa_identification_scanner/src/platform/platform_info.dart';

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
  });
}
