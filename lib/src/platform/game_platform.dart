import 'game_platform_factory_stub.dart'
    if (dart.library.js_interop) 'game_platform_factory_web.dart'
    as platform_factory;

/// Hooks a distribution portal needs from the game loop.
///
/// Mobile and plain web builds use [NoopGamePlatform]; CrazyGames web builds
/// (`--dart-define=CRAZYGAMES=true`) use the SDK-backed implementation, and
/// GamePix web builds (`--dart-define=GAMEPIX=true`) use [NoopGamePlatform.gamePix]
/// (no SDK, no external network, no ads).
abstract class GamePlatform {
  const GamePlatform();

  Future<void> initialize();

  void gameplayStart();

  void gameplayStop();

  /// Whether the portal asks the game to stay silent (CrazyGames
  /// `settings.muteAudio`). Combined with the player's own mute toggle.
  bool get isAudioMuted => false;

  /// Calls [listener] when [isAudioMuted] may have changed.
  void addAudioMuteListener(void Function() listener) {}

  /// Whether ad networks (AdMob) may be used. Portal builds never show ads.
  bool get allowsAds;

  /// Whether the post-game prompt to submit scores to the Bon-on leaderboard
  /// may be shown. Portal builds keep players on the portal.
  bool get allowsResultRegistration;
}

class NoopGamePlatform extends GamePlatform {
  const NoopGamePlatform({
    this.allowsAds = true,
    this.allowsResultRegistration = true,
  });

  /// GamePix portal build: SDK-free, no ads, no result upload.
  const NoopGamePlatform.gamePix()
    : allowsAds = false,
      allowsResultRegistration = false;

  @override
  Future<void> initialize() async {}

  @override
  void gameplayStart() {}

  @override
  void gameplayStop() {}

  @override
  final bool allowsAds;

  @override
  final bool allowsResultRegistration;
}

GamePlatform createGamePlatform() => platform_factory.createGamePlatform();
