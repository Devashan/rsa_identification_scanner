import 'platform_info.dart';

class _StubPlatformInfo implements PlatformInfo {
  const _StubPlatformInfo();

  @override
  bool get isWeb => true;

  @override
  bool get isAndroid => false;

  @override
  bool get isIOS => false;

  @override
  bool get isMacOS => false;

  @override
  bool get isWindows => false;

  @override
  bool get isLinux => false;
}

PlatformInfo getPlatformInfo() => const _StubPlatformInfo();
