# RSA Identification Scanner

`rsa_identification_scanner` is a Flutter package for scanning South African RSA ID barcode payloads and parsing the new pipe-delimited format into a typed record.

It provides:
- `RsaScannerView`: a ready-to-use camera scanner widget built on `mobile_scanner`.
- `RsaIdentificationScanner`: helper methods to detect and parse RSA ID barcode content, including encrypted/binary South African driving licence payload handling.

## Installation

Add the package to your app:

```yaml
dependencies:
  rsa_identification_scanner: ^0.0.1
```

Then fetch dependencies:

```bash
flutter pub get
```

## Setup

### 1) Import the package

```dart
import 'package:rsa_identification_scanner/rsa_identification_scanner.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
```

### 2) Configure platform permissions

`RsaScannerView` uses the device camera via `mobile_scanner`, so camera permissions are required.

- **Android**: ensure camera permission is available in your app manifest:

```xml
<uses-permission android:name="android.permission.CAMERA" />
```

- **iOS**: add `NSCameraUsageDescription` to `Info.plist` with a user-facing explanation.

## Scanner usage

```dart
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final scanner = RsaIdentificationScanner();
  String? scanned;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan RSA ID')),
      body: RsaScannerView(
        formats: const [BarcodeFormat.all],
        autoZoom: true,
        onScanResult: (capture) {
          if (capture.barcodes.isEmpty) return;
          final code = capture.barcodes.first.rawValue;
          if (code == null) return;

          setState(() => scanned = code);

          if (scanner.isRSAIdNewFormat(code)) {
            final parsed = scanner.parseRSAIdNewFormat(code);
            debugPrint('ID Number: ${parsed?.idNumber}');
          }
        },
      ),
    );
  }
}
```


## Handling encrypted binary SA driving licence payloads

Some scanners return South African driving licence PDF417 data as encrypted binary bytes where `rawValue` is empty or unreadable. Use `extractScannedPayload` to normalize either text or bytes:

```dart
onScanResult: (capture) {
  if (capture.barcodes.isEmpty) return;
  final barcode = capture.barcodes.first;

  final payload = scanner.extractScannedPayload(
    rawValue: barcode.rawValue,
    rawBytes: barcode.rawBytes,
  );

  if (payload == null) return;

  if (payload.startsWith('BINARY_BASE64:')) {
    debugPrint('Encrypted binary licence payload detected');
    // Send payload to your backend decrypt/verify service.
    return;
  }

  if (scanner.isRSAIdNewFormat(payload)) {
    final parsed = scanner.parseRSAIdNewFormat(payload);
    debugPrint('ID Number: ${parsed?.idNumber}');
  }
}
```

## RSA parse example (`parseRSAIdNewFormat`)

```dart
final scanner = RsaIdentificationScanner();

const sample =
    'DOE|JANE ANN|F|ZAF|9001014800082|1990-01-01|RSA|ID|2022-05-11|DHA|1234567890|7';

final parsed = scanner.parseRSAIdNewFormat(sample);

if (parsed != null) {
  print(parsed.surname);      // DOE
  print(parsed.firstNames);   // JANE ANN
  print(parsed.idNumber);     // 9001014800082
  print(parsed.dateOfBirth);  // 1990-01-01
}
```


## Decrypting South African driving licence payloads (binary PDF417)

For 720-byte encrypted licence payloads (or base64-encoded equivalents), you can now run the full decode flow:

```dart
final scanner = RsaIdentificationScanner();

// From scanner bytes:
final result = scanner.decryptLicenseBytes(rawLicenseBytes);

// Or from base64:
final resultFromBase64 = scanner.decryptLicenseBase64(base64Payload);

print(result.version); // SaLicenseVersion.version2, etc.
print(result.decryptedPayload.length); // 714
print(result.decryptedPayloadBase64); // Useful for debugging/fixtures
```

What is validated:
- Total input length is exactly 720 bytes.
- The 2-byte marker after version is `00 00`.
- Encrypted payload is split into fixed blocks: 128x5 and 74x1.
- RSA public-key raw operation is used (`NO_PADDING` equivalent).

By default, the scanner includes built-in key sets for both version 1 and version 2 payloads.  
If you need to override these keys (for testing or custom environments), construct with custom key sets:

```dart
final scanner = RsaIdentificationScanner.withLicenseKeys(
  rsaKeySetsByVersion: {
    SaLicenseVersion.version1: const SaLicenseRsaKeySet(
      keyFor128ByteBlocksPem: '-----BEGIN RSA PUBLIC KEY-----...'
      '-----END RSA PUBLIC KEY-----',
      keyFor74ByteBlockPem: '-----BEGIN RSA PUBLIC KEY-----...'
      '-----END RSA PUBLIC KEY-----',
    ),
    SaLicenseVersion.version2: const SaLicenseRsaKeySet(
      keyFor128ByteBlocksPem: '-----BEGIN RSA PUBLIC KEY-----...'
      '-----END RSA PUBLIC KEY-----',
      keyFor74ByteBlockPem: '-----BEGIN RSA PUBLIC KEY-----...'
      '-----END RSA PUBLIC KEY-----',
    ),
  },
);
```

## Known limitations

- `isRSAIdNewFormat` validates structure only (12 pipe-delimited fields and required indexes), not full data correctness.
- `parseRSAIdNewFormat` does not verify check digits or cryptographic authenticity; it only maps fields by index.
- `RsaIdentificationScanner.isSupported()` returns support for Android, iOS, and web, but camera behavior depends on platform/browser/device capabilities.
- Duplicate barcode filtering and scan throttling are app-level concerns and should be handled in your `onScanResult` callback.
