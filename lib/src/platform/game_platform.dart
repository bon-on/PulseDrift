import 'game_platform_factory_stub.dart'
    if (dart.library.js_interop) 'game_platform_factory_web.dart'
    as platform_factory;

/// Hooks a distribution portal needs from the game loop.
///
/// Mobile and plain web builds use [NoopGamePlatform]; CrazyGames web builds
/// (`--dart-define=CRAZYGAMES=true`) use the CrazyGames SDK adapter and
/// GamePix web builds (`--dart-define=GAMEPIX=true`) the GamePix SDK v3
/// adapter (feature-gamepix-sdk).
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

  /// Registers a callback for portal pause/resume requests (GamePix Player
  /// overlays and ads); null unregisters. Platforms without such events
  /// ignore it.
  void setPauseListener(void Function(bool paused)? listener) {}

  /// Whether [showRunBreakAd] may show an ad, so callers only wait for it on
  /// such platforms (feature-gamepix-sdk).
  bool get showsRunBreakAds => false;

  /// Shows an ad between runs. Completes when the ad ends, fails or is
  /// skipped (cooldown), so callers can always continue afterwards.
  Future<void> showRunBreakAd() async {}

  /// Whether ad networks (AdMob) may be used. Portal builds never show AdMob
  /// ads (GamePix shows its own break ads through [showRunBreakAd]).
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
