import 'package:flutter/foundation.dart';

import 'platform_info_stub.dart'
    if (dart.library.io) 'platform_info_io.dart' as platform_impl;

abstract interface class PlatformInfo {
  bool get isWeb;
  bool get isAndroid;
  bool get isIOS;
  bool get isMacOS;
  bool get isWindows;
  bool get isLinux;
}

/// Resolves platform info using conditional imports.
PlatformInfo getPlatformInfo() => platform_impl.getPlatformInfo();

/// Returns a display label for a given [PlatformInfo] instance.
String describePlatform(PlatformInfo platformInfo) {
  if (platformInfo.isWeb) {
    return 'Web';
  }

  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return 'Android';
    case TargetPlatform.iOS:
      return 'iOS';
    case TargetPlatform.macOS:
      return 'MacOS';
    case TargetPlatform.windows:
      return 'Windows';
    case TargetPlatform.linux:
      return 'Linux';
    case TargetPlatform.fuchsia:
      return 'Unknown';
  }
}
