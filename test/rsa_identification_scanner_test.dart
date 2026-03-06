import 'package:flutter_test/flutter_test.dart';

import 'package:rsa_identification_scanner/rsa_identification_scanner.dart';

void main() {
  group('isRSAIdNewFormat', () {
    test('returns true for payload with exactly 12 fields', () {
      final scanner = RsaIdentificationScanner();
      const payload =
          'DOE|JOHN JAMES|M|ZAF|9001015009087|1990-01-01|SA|ID|2020-01-01|DHA|1234567890|7';

      expect(scanner.isRSAIdNewFormat(payload), isTrue);
    });

    test('returns false for malformed payload with fewer than 12 fields', () {
      final scanner = RsaIdentificationScanner();
      const payload = 'DOE|JOHN|M|ZAF|9001015009087';

      expect(scanner.isRSAIdNewFormat(payload), isFalse);
    });

    test('returns false for empty-like payload values', () {
      final scanner = RsaIdentificationScanner();

      expect(scanner.isRSAIdNewFormat(''), isFalse);
      expect(scanner.isRSAIdNewFormat('   '), isFalse);
      expect(scanner.isRSAIdNewFormat('null'), isFalse);
    });
  });

  group('parseRSAIdNewFormat', () {
    test('parses and maps the first 12 fields from a valid payload', () {
      final scanner = RsaIdentificationScanner();
      const payload =
          'DOE|JOHN JAMES|M|ZAF|9001015009087|1990-01-01|SA|ID|2020-01-01|DHA|1234567890|7';

      final result = scanner.parseRSAIdNewFormat(payload);

      expect(result, isNotNull);
      expect(result!.surname, 'DOE');
      expect(result.firstNames, 'JOHN JAMES');
      expect(result.gender, 'M');
      expect(result.countryCode, 'ZAF');
      expect(result.idNumber, '9001015009087');
      expect(result.dateOfBirth, '1990-01-01');
      expect(result.nationality, 'SA');
      expect(result.idType, 'ID');
      expect(result.issueDate, '2020-01-01');
      expect(result.issuerCode, 'DHA');
      expect(result.personalNumber, '1234567890');
      expect(result.checkDigit, '7');
    });

    test('returns null for malformed payload', () {
      final scanner = RsaIdentificationScanner();
      const malformed = 'DOE|JOHN|M|ZAF|9001015009087';

      expect(scanner.parseRSAIdNewFormat(malformed), isNull);
    });

    test('returns null for empty-like payload values', () {
      final scanner = RsaIdentificationScanner();

      expect(scanner.parseRSAIdNewFormat(''), isNull);
      expect(scanner.parseRSAIdNewFormat('   '), isNull);
      expect(scanner.parseRSAIdNewFormat('null'), isNull);
    });
  });

  group('getPlatform', () {
    test('returns a recognized platform label', () {
      final scanner = RsaIdentificationScanner();
      const knownPlatforms = {
        'Android',
        'iOS',
        'MacOS',
        'Windows',
        'Linux',
        'Web',
        'Unknown',
      };

      expect(knownPlatforms.contains(scanner.getPlatform()), isTrue);
    });
  });
}
