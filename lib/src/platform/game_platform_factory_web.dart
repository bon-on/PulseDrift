import 'crazygames_platform.dart';
import 'game_platform.dart';
import 'gamepix_platform.dart';

const bool _crazyGamesBuild = bool.fromEnvironment('CRAZYGAMES');
const bool _gamePixBuild = bool.fromEnvironment('GAMEPIX');

/// Picks the portal adapter. CrazyGames wins over GamePix
/// (feature-gamepix-sdk). Tests only: [createGamePlatform] keeps the
/// selection on compile-time constants.
GamePlatform selectGamePlatform({
  required bool crazyGames,
  required bool gamePix,
}) {
  if (crazyGames) return CrazyGamesPlatform();
  if (gamePix) return GamePixPlatform();
  return const NoopGamePlatform();
}

/// One conditional expression over compile-time constants, so the unused
/// portal adapter is tree-shaken from each portal bundle (checked by the
/// build scripts).
GamePlatform createGamePlatform() => _crazyGamesBuild
    ? CrazyGamesPlatform()
    : _gamePixBuild
    ? GamePixPlatform()
    : const NoopGamePlatform();
