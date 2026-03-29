import 'package:flutter/material.dart';
import 'package:rsa_identification_scanner/rsa_identification_scanner.dart';
import 'package:mobile_scanner/mobile_scanner.dart'; // Import for BarcodeScanner + Format, etc.

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? _scannedValue;
  String _previousScannedValue = '';
  final RsaIdentificationScanner rsaScanner = RsaIdentificationScanner();

  String _formatNewIdRecord(NewIdFormatRecord? rsaData) {
    if (rsaData == null) {
      return 'Scanned RSA ID (New Format)\nUnable to parse fields.';
    }

    return 'Scanned RSA ID (New Format)\n'
        'Surname: ${rsaData.surname}\n'
        'First Names: ${rsaData.firstNames}\n'
        'Gender: ${rsaData.gender}\n'
        'Country Code: ${rsaData.countryCode}\n'
        'ID Number: ${rsaData.idNumber}\n'
        'Date of Birth: ${rsaData.dateOfBirth}\n'
        'Nationality: ${rsaData.nationality}\n'
        'ID Type: ${rsaData.idType}\n'
        'Issue Date: ${rsaData.issueDate}\n'
        'Issuer Code: ${rsaData.issuerCode}\n'
        'Personal Number: ${rsaData.personalNumber}\n'
        'Check Digit: ${rsaData.checkDigit}';
  }

  String _formatLicense(
    SaDrivingLicense parsedLicense,
    SaLicenseVersion version,
  ) {
    String joinOrNone(List<String> values) =>
        values.isEmpty ? '(none)' : values.join(', ');

    return 'Decrypted SA licence (${version.name})\n'
        'Vehicle Codes: ${joinOrNone(parsedLicense.vehicleCodes)}\n'
        'Surname: ${parsedLicense.surname}\n'
        'Initials: ${parsedLicense.initials}\n'
        'PrDP Code: ${parsedLicense.prDPCode}\n'
        'ID Country of Issue: ${parsedLicense.idCountryOfIssue}\n'
        'License Country of Issue: ${parsedLicense.licenseCountryOfIssue}\n'
        'Vehicle Restrictions: ${joinOrNone(parsedLicense.vehicleRestrictions)}\n'
        'License Number: ${parsedLicense.licenseNumber}\n'
        'ID Number: ${parsedLicense.idNumber}\n'
        'ID Number Type: ${parsedLicense.idNumberType}\n'
        'License Code Issue Dates: ${joinOrNone(parsedLicense.licenseCodeIssueDates)}\n'
        'Driver Restriction Codes: ${parsedLicense.driverRestrictionCodes}\n'
        'PrDP Permit Expiry Date: ${parsedLicense.prDPermitExpiryDate}\n'
        'License Issue Number: ${parsedLicense.licenseIssueNumber}\n'
        'Birthdate: ${parsedLicense.birthdate}\n'
        'License Issue Date: ${parsedLicense.licenseIssueDate}\n'
        'License Expiry Date: ${parsedLicense.licenseExpiryDate}\n'
        'Gender: ${parsedLicense.gender}\n'
        'Image Width: ${parsedLicense.imageWidth}\n'
        'Image Height: ${parsedLicense.imageHeight}';
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RSA ID Scanner Example',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('RSA ID Scanner Example')),
        body: Column(
          children: [
            Expanded(
              flex: 4,
              child: RsaScannerView(
                formats: const [
                  BarcodeFormat.all,
                ], // Example: Only scan QR codes
                torchEnabled: false,
                autoZoom: true,
                onScanResult: (capture) {
                  if (capture.barcodes.isNotEmpty) {
                    final barcode = capture.barcodes.first;
                    final payload = rsaScanner.extractScannedPayload(
                      rawValue: barcode.rawValue,
                      rawBytes: barcode.rawBytes,
                    );
                    if (payload == null) return;

                    if (payload == _previousScannedValue) {
                      // Duplicate scan, ignore.
                      return;
                    }
                    _previousScannedValue = payload;

                    if (barcode.rawBytes != null &&
                        rsaScanner.isLikelyEncryptedBinaryLicenseData(
                          barcode.rawBytes!,
                        )) {
                      try {
                        final decrypted = rsaScanner.decryptLicenseBytes(
                          barcode.rawBytes!,
                        );
                        final parsedLicense = rsaScanner
                            .parseDecryptedLicensePayload(
                              decrypted.decryptedPayload,
                            );

                        debugPrint('Parsed person info from license:');
                        debugPrint('Surname: ${parsedLicense.surname}');
                        debugPrint('Initials: ${parsedLicense.initials}');
                        debugPrint('ID Number: ${parsedLicense.idNumber}');
                        debugPrint('Birthdate: ${parsedLicense.birthdate}');
                        debugPrint('Gender: ${parsedLicense.gender}');
                        debugPrint(
                          'License Number: ${parsedLicense.licenseNumber}',
                        );

                        setState(() {
                          _scannedValue = _formatLicense(
                            parsedLicense,
                            decrypted.version,
                          );
                        });
                        return;
                      } on Object catch (error) {
                        setState(() {
                          _scannedValue =
                              'Failed to decrypt licence payload: $error';
                        });
                        return;
                      }
                    }

                    setState(() {
                      _scannedValue = payload;
                    });

                    if (rsaScanner.isRSAIdNewFormat(payload)) {
                      final rsaData = rsaScanner.parseRSAIdNewFormat(payload);
                      print('Surname: ${rsaData?.surname}');
                      print('First Names: ${rsaData?.firstNames}');

                      setState(() {
                        _scannedValue = _formatNewIdRecord(rsaData);
                      });
                    }
                  }
                },
              ),
            ),
            Expanded(
              flex: 3,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  _scannedValue == null
                      ? 'Scan an RSA ID/Driving License or barcode'
                      : 'Scanned Value:\n$_scannedValue',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
