import 'dart:convert';
import 'dart:typed_data';

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

class SaDrivingLicense {
  const SaDrivingLicense({
    required this.vehicleCodes,
    required this.surname,
    required this.initials,
    required this.prDPCode,
    required this.idCountryOfIssue,
    required this.licenseCountryOfIssue,
    required this.vehicleRestrictions,
    required this.licenseNumber,
    required this.idNumber,
    required this.idNumberType,
    required this.licenseCodeIssueDates,
    required this.driverRestrictionCodes,
    required this.prDPermitExpiryDate,
    required this.licenseIssueNumber,
    required this.birthdate,
    required this.licenseIssueDate,
    required this.licenseExpiryDate,
    required this.gender,
    required this.imageWidth,
    required this.imageHeight,
  });

  final List<String> vehicleCodes;
  final String surname;
  final String initials;
  final String prDPCode;
  final String idCountryOfIssue;
  final String licenseCountryOfIssue;
  final List<String> vehicleRestrictions;
  final String licenseNumber;
  final String idNumber;
  final String idNumberType;
  final List<String> licenseCodeIssueDates;
  final String driverRestrictionCodes;
  final String prDPermitExpiryDate;
  final String licenseIssueNumber;
  final String birthdate;
  final String licenseIssueDate;
  final String licenseExpiryDate;
  final String gender;
  final int imageWidth;
  final int imageHeight;

  @override
  String toString() {
    return 'Vehicle codes: $vehicleCodes\n'
        'Surname: $surname\n'
        'Initials: $initials\n'
        'PrDP Code: $prDPCode\n'
        'ID Country of Issue: $idCountryOfIssue\n'
        'License Country of Issue: $licenseCountryOfIssue\n'
        'Vehicle Restriction: $vehicleRestrictions\n'
        'License Number: $licenseNumber\n'
        'ID Number: $idNumber\n'
        'ID number type: $idNumberType\n'
        'License code issue date: $licenseCodeIssueDates\n'
        'Driver restriction codes: $driverRestrictionCodes\n'
        'PrDP permit expiry date: $prDPermitExpiryDate\n'
        'License issue number: $licenseIssueNumber\n'
        'Birthdate: $birthdate\n'
        'License Valid From: $licenseIssueDate\n'
        'License Valid To: $licenseExpiryDate\n'
        'Gender: $gender\n'
        'Image width: $imageWidth\n'
        'Image height: $imageHeight';
  }
}
