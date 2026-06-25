import 'package:flutter/services.dart';

class AudioController {
  static const MethodChannel _channel = MethodChannel('pulse_drift/audio');

  Future<void> initialize() async {}

  Future<void> startBackgroundLoop() async {
    await _invoke('startBackgroundLoop');
  }

  Future<void> stopBackgroundLoop() async {
    await _invoke('stopBackgroundLoop');
  }

  Future<void> playPulsePass() async {
    await _invoke('playPulsePass');
  }

  Future<void> dispose() async => _invoke('disposeAudio');

  Future<void> _invoke(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } on MissingPluginException {
      // Audio is optional on platforms where the native channel is unavailable.
    } on PlatformException {
      // Audio failures should not interrupt gameplay flow.
    }
  }
}
