import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'sound_mute_store.dart';
import 'web_sound_stub.dart' if (dart.library.js_interop) 'web_sound_web.dart';

/// One-shot sound effects. Each maps to `assets/audio/<name>.wav`.
enum Sfx {
  pulsePass('pulse_pass', 'playPulsePass', 0.78),
  crash('crash', 'playCrash', 0.8);

  const Sfx(this.fileName, this.nativeMethod, this.volume);

  final String fileName;
  final String nativeMethod;
  final double volume;

  String get assetKey => 'assets/audio/$fileName.wav';
}

const String backgroundLoopAsset = 'assets/audio/background_loop.wav';
const double _loopVolume = 0.28;

/// Plays effects and the background loop on web and native shells.
///
/// Nothing here throws or blocks the UI. Playback is silent while the
/// effective mute is on: the player's own choice ([userMuted]) or the portal
/// platform's.
class SoundFx {
  SoundFx({
    bool Function()? isPlatformMuted,
    this.store = const SoundMuteStore(),
    WebSound? webSound,
    MethodChannel? channel,
    bool? isWeb,
  }) : _isPlatformMuted = isPlatformMuted ?? _never,
       _webSound = webSound ?? WebSound(),
       _channel = channel ?? const MethodChannel('pulse_drift/audio'),
       _isWeb = isWeb ?? kIsWeb;

  final SoundMuteStore store;
  final bool Function() _isPlatformMuted;
  final WebSound _webSound;
  final MethodChannel _channel;
  final bool _isWeb;

  bool _userMuted = false;
  bool _userTouched = false;
  // The stored mute choice is read first so a muted player never hears the
  // loop flash on at launch.
  bool _loaded = false;
  bool _loopWanted = false;
  bool _loopRunning = false;
  bool _loopStarting = false;
  // Browsers only allow audio after a user gesture; the loop waits for one.
  bool _userInteracted = false;
  // False while the app or browser tab is hidden; the loop must not keep
  // playing in the background (the game itself freezes there).
  bool _appVisible = true;

  static bool _never() => false;

  bool get userMuted => _userMuted;

  bool get muted => _userMuted || _isPlatformMuted();

  /// Loads the stored choice. A toggle made meanwhile wins.
  Future<void> initialize() async {
    var stored = false;
    try {
      stored = await store.loadMuted();
    } catch (_) {}
    _loaded = true;
    if (!_userTouched) _userMuted = stored;
    _applyLoop();
  }

  Future<void> setUserMuted(bool value) async {
    _userTouched = true;
    _loaded = true;
    _userMuted = value;
    _applyLoop();
    await store.saveMuted(value);
  }

  /// Call when the platform mute may have changed.
  void refreshMute() => _applyLoop();

  /// Call when the app or browser tab is hidden or shown again.
  void setAppVisible(bool visible) {
    if (_appVisible == visible) return;
    _appVisible = visible;
    _applyLoop();
  }

  /// Call on pointer or key input; unlocks web audio for the loop and retries
  /// a loop the browser refused earlier.
  void onUserInput() {
    _userInteracted = true;
    if (_isWeb && _loopWanted && !_loopRunning) _applyLoop();
  }

  void play(Sfx sfx) {
    if (!_loaded || muted) return;
    if (_isWeb) {
      _webSound.play(sfx.assetKey, volume: sfx.volume);
      return;
    }
    _invoke(sfx.nativeMethod);
  }

  void startBackgroundLoop() {
    _loopWanted = true;
    _applyLoop();
  }

  void stopBackgroundLoop() {
    _loopWanted = false;
    _applyLoop();
  }

  void dispose() {
    _loopWanted = false;
    _stopLoopPlayback();
    if (!_isWeb) _invoke('disposeAudio');
  }

  void _applyLoop() {
    if (!_loopWanted || muted || !_appVisible) {
      _stopLoopPlayback();
      return;
    }
    if (!_loaded || _loopRunning || _loopStarting) return;
    if (_isWeb) {
      if (!_userInteracted) return;
      _loopStarting = true;
      _webSound.startLoop(backgroundLoopAsset, volume: _loopVolume).then((ok) {
        _loopStarting = false;
        if (!ok) return;
        _loopRunning = true;
        // State may have changed while the browser was starting playback.
        if (!_loopWanted || muted || !_appVisible) _stopLoopPlayback();
      });
      return;
    }
    _loopRunning = true;
    _invoke('startBackgroundLoop');
  }

  void _stopLoopPlayback() {
    if (!_loopRunning) return;
    _loopRunning = false;
    if (_isWeb) {
      _webSound.stopLoop(backgroundLoopAsset);
    } else {
      _invoke('stopBackgroundLoop');
    }
  }

  void _invoke(String method) {
    try {
      _channel.invokeMethod<void>(method).catchError((Object _) {});
    } catch (_) {
      // Audio is optional where the native channel is unavailable.
    }
  }
}
