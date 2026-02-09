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
                    if (barcode.rawValue != null) {
                      setState(() {
                        _scannedValue = barcode.rawValue;
                        if (_scannedValue != _previousScannedValue) {
                          _previousScannedValue = _scannedValue;
                        } else {
                          // Duplicate scan, ignore
                          return;
                        }
                        // Check if new RSA ID format
                        if (rsaScanner.isRSAIdNewFormat(_scannedValue!)) {
                          // Process RSA ID
                          final rsaData = rsaScanner.parseRSAIdNewFormat(
                            _scannedValue!,
                          );
                          print('Surname: ${rsaData?.surname}');
                          print('First Names: ${rsaData?.firstNames}');
                        }
                      });
                      // You might want to navigate away or stop the scanner here
                      // For simplicity, we'll just display the value.
                      // print('Scanned: ${barcode.rawValue}');
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
