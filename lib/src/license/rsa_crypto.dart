import 'dart:convert';
import 'dart:typed_data';

/// Minimal RSA public key representation for raw modular operations.
class RsaPublicKey {
  /// Creates a public key from [modulus] and [exponent].
  const RsaPublicKey({required this.modulus, required this.exponent});

  final BigInt modulus;
  final BigInt exponent;

  /// Returns modulus length in bytes.
  int get modulusByteLength => (modulus.bitLength + 7) ~/ 8;

  /// Parses a PKCS#1 PEM encoded RSA public key.
  factory RsaPublicKey.fromPem(String pem) {
    final b64 = pem
        .replaceAll('-----BEGIN RSA PUBLIC KEY-----', '')
        .replaceAll('-----END RSA PUBLIC KEY-----', '')
        .replaceAll(RegExp(r'\s+'), '');

    final der = base64Decode(b64);
    final values = _parsePkcs1RsaPublicKey(der);

    return RsaPublicKey(modulus: values.$1, exponent: values.$2);
  }

  static (BigInt, BigInt) _parsePkcs1RsaPublicKey(Uint8List der) {
    var offset = 0;

    if (der[offset++] != 0x30) {
      throw const FormatException('RSA key DER must start with ASN.1 sequence.');
    }

    final seqLengthResult = _readDerLength(der, offset);
    final sequenceLength = seqLengthResult.$1;
    offset = seqLengthResult.$2;

    if (offset + sequenceLength > der.length) {
      throw const FormatException('Invalid DER sequence length for RSA key.');
    }

    final modulusResult = _readDerInteger(der, offset);
    final modulus = modulusResult.$1;
    offset = modulusResult.$2;

    final exponentResult = _readDerInteger(der, offset);
    final exponent = exponentResult.$1;

    return (modulus, exponent);
  }

  static (BigInt, int) _readDerInteger(Uint8List der, int offset) {
    if (der[offset++] != 0x02) {
      throw const FormatException('Expected ASN.1 INTEGER tag in RSA key DER.');
    }

    final lengthResult = _readDerLength(der, offset);
    final valueLength = lengthResult.$1;
    offset = lengthResult.$2;

    if (offset + valueLength > der.length) {
      throw const FormatException('Invalid ASN.1 INTEGER length in RSA key DER.');
    }

    final valueBytes = Uint8List.sublistView(der, offset, offset + valueLength);
    final unsignedBytes =
        valueBytes.isNotEmpty && valueBytes.first == 0x00
            ? Uint8List.sublistView(valueBytes, 1)
            : valueBytes;

    final value = bigIntFromBytes(unsignedBytes);
    return (value, offset + valueLength);
  }

  static (int, int) _readDerLength(Uint8List der, int offset) {
    final first = der[offset++];

    if ((first & 0x80) == 0) {
      return (first, offset);
    }

    final count = first & 0x7F;
    if (count == 0 || count > 4) {
      throw const FormatException('Unsupported DER length encoding.');
    }

    var length = 0;
    for (var i = 0; i < count; i++) {
      length = (length << 8) | der[offset++];
    }

    return (length, offset);
  }
}

/// Performs raw RSA public operation (`m = c^e mod n`) for one block.
Uint8List rsaRawPublicOperation(Uint8List ciphertext, RsaPublicKey key) {
  final keySize = key.modulusByteLength;
  if (ciphertext.length != keySize) {
    throw FormatException(
      'Ciphertext block length (${ciphertext.length}) does not match RSA modulus size ($keySize).',
    );
  }

  final input = bigIntFromBytes(ciphertext);
  final output = input.modPow(key.exponent, key.modulus);
  return bigIntToBytes(output, keySize);
}

/// Converts big-endian bytes into a [BigInt].
BigInt bigIntFromBytes(Uint8List bytes) {
  var result = BigInt.zero;
  for (final byte in bytes) {
    result = (result << 8) | BigInt.from(byte);
  }
  return result;
}

/// Converts [value] to a fixed-length big-endian byte array.
Uint8List bigIntToBytes(BigInt value, int length) {
  final result = Uint8List(length);
  var current = value;

  for (var i = length - 1; i >= 0; i--) {
    result[i] = (current & BigInt.from(0xFF)).toInt();
    current >>= 8;
  }

  return result;
}
