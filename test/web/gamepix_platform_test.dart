// Run with: flutter test --platform chrome test/web
@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_drift/src/platform/crazygames_platform.dart';
import 'package:pulse_drift/src/platform/game_platform.dart';
import 'package:pulse_drift/src/platform/game_platform_factory_web.dart'
    as web_factory;
import 'package:pulse_drift/src/platform/gamepix_platform.dart';

void main() {
  test('default web build keeps the no-op platform with ads and upload', () {
    final platform = web_factory.selectGamePlatform(
      crazyGames: false,
      gamePix: false,
    );
    expect(platform, isA<NoopGamePlatform>());
    expect(platform.allowsResultRegistration, isTrue);
    expect(platform.allowsAds, isTrue);
  });

  test('GamePix build uses the SDK adapter without AdMob or upload', () {
    final platform = web_factory.selectGamePlatform(
      crazyGames: false,
      gamePix: true,
    );
    expect(platform, isA<GamePixPlatform>());
    expect(platform.allowsResultRegistration, isFalse);
    expect(platform.allowsAds, isFalse);
  });

  test('CrazyGames adapter is only selected for CRAZYGAMES', () {
    expect(
      web_factory.selectGamePlatform(crazyGames: true, gamePix: false),
      isA<CrazyGamesPlatform>(),
    );
    expect(
      web_factory.selectGamePlatform(crazyGames: true, gamePix: true),
      isA<CrazyGamesPlatform>(),
    );
    expect(
      web_factory.selectGamePlatform(crazyGames: false, gamePix: true),
      isNot(isA<CrazyGamesPlatform>()),
    );
  });

  test('the running test build uses the no-op platform', () {
    expect(web_factory.createGamePlatform(), isA<NoopGamePlatform>());
  });
}
