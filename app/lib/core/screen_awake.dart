import 'package:flutter/services.dart';

/// Keeps the screen on during an exercise (FLAG_KEEP_SCREEN_ON through the existing platform
/// channel; no wakelock package, to keep the APK small).
abstract class ScreenAwake {
  Future<void> set(bool on);
}

class ChannelScreenAwake implements ScreenAwake {
  const ChannelScreenAwake();
  static const _channel = MethodChannel('app/device');
  @override
  Future<void> set(bool on) async {
    try {
      await _channel.invokeMethod<void>('keepScreenOn', on);
    } on MissingPluginException {
      // not on Android (tests/desktop)
    }
  }
}

class NoopScreenAwake implements ScreenAwake {
  const NoopScreenAwake();
  @override
  Future<void> set(bool on) async {}
}
