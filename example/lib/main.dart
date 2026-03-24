import 'package:flutter/material.dart';
import 'package:rsa_identification_scanner/rsa_identification_scanner.dart';
import 'package:mobile_scanner/mobile_scanner.dart'; // Import for BarcodeFormat, etc.

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
  String? _previousScannedValue = '';
  RsaIdentificationScanner rsaScanner = RsaIdentificationScanner();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
                        final parsedLicense = rsaScanner.parseDecryptedLicensePayload(
                          decrypted.decryptedPayload,
                        );

                        debugPrint('Parsed person info from license:');
                        debugPrint('Surname: ${parsedLicense.surname}');
                        debugPrint('Initials: ${parsedLicense.initials}');
                        debugPrint('ID Number: ${parsedLicense.idNumber}');
                        debugPrint('Birthdate: ${parsedLicense.birthdate}');
                        debugPrint('Gender: ${parsedLicense.gender}');
                        debugPrint('License Number: ${parsedLicense.licenseNumber}');

                        setState(() {
                          _scannedValue = 'Decrypted SA licence (${decrypted.version.name})\n'
                              'Name: ${parsedLicense.initials} ${parsedLicense.surname}\n'
                              'ID: ${parsedLicense.idNumber}\n'
                              'DOB: ${parsedLicense.birthdate}\n'
                              'Gender: ${parsedLicense.gender}\n'
                              'License: ${parsedLicense.licenseNumber}';
                        });
                        return;
                      } on Object catch (error) {
                        setState(() {
                          _scannedValue = 'Failed to decrypt licence payload: $error';
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
                    }
                  }
                },
              ),
            ),
            Expanded(
              flex: 1,
              child: Center(
                child: Text(
                  _scannedValue == null
                      ? 'Scan an RSA ID or barcode'
                      : 'Scanned Value: $_scannedValue',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
