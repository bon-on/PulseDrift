import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

/// Plays bundled sound assets with browser audio elements on web builds.
class WebSound {
  final Map<String, _Audio> _cache = <String, _Audio>{};

  _Audio _audio(String assetKey) => _cache.putIfAbsent(
    assetKey,
    () => _Audio(ui_web.assetManager.getAssetUrl(assetKey)),
  );

  void play(String assetKey, {double volume = 1}) {
    try {
      final audio = _audio(assetKey);
      audio.volume = volume;
      audio.currentTime = 0;
      // Rejections (autoplay policy, decode errors) must not break input.
      audio.play().toDart.ignore();
    } catch (_) {}
  }

  /// Starts [assetKey] on repeat. Completes with false when the browser
  /// refuses (autoplay policy), so the caller can retry after user input.
  Future<bool> startLoop(String assetKey, {double volume = 1}) async {
    try {
      final audio = _audio(assetKey);
      audio.loop = true;
      audio.volume = volume;
      await audio.play().toDart;
      return true;
    } catch (_) {
      return false;
    }
  }

  void stopLoop(String assetKey) {
    try {
      _cache[assetKey]?.pause();
    } catch (_) {}
  }
}

@JS('Audio')
extension type _Audio._(JSObject _) implements JSObject {
  external factory _Audio(String src);
  external JSPromise<JSAny?> play();
  external void pause();
  external set currentTime(num value);
  external set volume(num value);
  external set loop(bool value);
}
