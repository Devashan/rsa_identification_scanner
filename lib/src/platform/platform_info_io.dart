import 'dart:io';

import 'platform_info.dart';

class _IoPlatformInfo implements PlatformInfo {
  const _IoPlatformInfo();

  @override
  bool get isWeb => false;

  @override
  bool get isAndroid => Platform.isAndroid;

  @override
  bool get isIOS => Platform.isIOS;

  @override
  bool get isMacOS => Platform.isMacOS;

  @override
  bool get isWindows => Platform.isWindows;

  @override
  bool get isLinux => Platform.isLinux;
}

PlatformInfo getPlatformInfo() => const _IoPlatformInfo();
