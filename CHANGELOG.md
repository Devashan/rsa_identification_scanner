## 0.0.2

- Added `extractScannedPayload` to normalize scanner output from text (`rawValue`) or binary bytes (`rawBytes`).
- Added encrypted/binary SA driving licence payload detection via `isLikelyEncryptedBinaryLicenseData`.
- Expanded tests and README examples for encrypted binary barcode handling.

## 0.0.1

- Initial release of `rsa_identification_scanner`.
- Added `RsaScannerView`, a configurable camera scanner widget powered by `mobile_scanner`.
- Added `RsaIdentificationScanner` utilities, including `isRSAIdNewFormat` and `parseRSAIdNewFormat` for pipe-delimited RSA ID payloads.
- Added example Flutter app demonstrating barcode scanning and parsed field extraction.
