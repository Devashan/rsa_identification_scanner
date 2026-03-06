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
  group('RsaIdentificationScanner platform detection', () {
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    test('isSupported returns true for Android and iOS', () {
      final androidScanner = RsaIdentificationScanner(
        platformInfo: const _FakePlatformInfo(isAndroid: true),
      );
      final iosScanner = RsaIdentificationScanner(
        platformInfo: const _FakePlatformInfo(isIOS: true),
      );

      expect(androidScanner.isSupported(), isTrue);
      expect(iosScanner.isSupported(), isTrue);
    });

    test('isSupported returns true for web and false for unsupported desktop', () {
      final webScanner = RsaIdentificationScanner(
        platformInfo: const _FakePlatformInfo(isWeb: true),
      );
      final desktopScanner = RsaIdentificationScanner(
        platformInfo: const _FakePlatformInfo(isLinux: true),
      );

      expect(webScanner.isSupported(), isTrue);
      expect(desktopScanner.isSupported(), isFalse);
    });

    test('getPlatform resolves Android and iOS via target platform', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final androidScanner = RsaIdentificationScanner(
        platformInfo: const _FakePlatformInfo(isAndroid: true),
      );
      expect(androidScanner.getPlatform(), 'Android');

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final iosScanner = RsaIdentificationScanner(
        platformInfo: const _FakePlatformInfo(isIOS: true),
      );
      expect(iosScanner.getPlatform(), 'iOS');
    });

    test('getPlatform returns Web when running on web', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final webScanner = RsaIdentificationScanner(
        platformInfo: const _FakePlatformInfo(isWeb: true),
      );

      expect(webScanner.getPlatform(), 'Web');
    });
  });
}
