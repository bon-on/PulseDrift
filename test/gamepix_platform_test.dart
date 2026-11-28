import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_drift/src/platform/game_platform.dart';

void main() {
  test('default no-op platform keeps Pages and mobile behaviour', () {
    const platform = NoopGamePlatform();
    expect(platform.allowsResultRegistration, isTrue);
    expect(platform.allowsAds, isTrue);
  });

  test('platforms without break ads or pause events stay inert', () async {
    const platform = NoopGamePlatform();
    await platform.initialize();
    platform.gameplayStart();
    platform.gameplayStop();
    platform.setPauseListener((_) => fail('no pause events expected'));
    platform.setPauseListener(null);
    expect(platform.showsRunBreakAds, isFalse);
    await platform.showRunBreakAd();
    expect(platform.isAudioMuted, isFalse);
  });

  test('the VM factory always returns the no-op platform', () {
    expect(createGamePlatform(), isA<NoopGamePlatform>());
  });
}
