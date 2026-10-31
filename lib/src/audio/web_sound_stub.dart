/// Non-web builds play sounds through the native shell audio channel.
class WebSound {
  void play(String assetKey, {double volume = 1}) {}

  Future<bool> startLoop(String assetKey, {double volume = 1}) async => false;

  void stopLoop(String assetKey) {}
}
