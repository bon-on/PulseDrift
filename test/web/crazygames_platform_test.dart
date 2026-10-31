// Run with: flutter test --platform chrome test/web
@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_drift/src/platform/crazygames_platform.dart';

/// Installs a fake `window.CrazyGames.SDK` and records the calls it receives.
class _FakeSdk {
  _FakeSdk({
    this.environment = 'local',
    this.initResult,
    this.withSettings = false,
  }) {
    final game = JSObject()
      ..setProperty(
        'gameplayStart'.toJS,
        (() => calls.add('gameplayStart')).toJS,
      )
      ..setProperty(
        'gameplayStop'.toJS,
        (() => calls.add('gameplayStop')).toJS,
      );
    if (withSettings) {
      game
        ..setProperty('settings'.toJS, _settings(muteAudio: false))
        ..setProperty(
          'addSettingsChangeListener'.toJS,
          ((JSFunction listener) => settingsListener = listener).toJS,
        );
    }
    final sdk = JSObject()
      ..setProperty('environment'.toJS, environment.toJS)
      ..setProperty('game'.toJS, game)
      ..setProperty(
        'init'.toJS,
        (() => (initResult ?? Future<void>.value()).toJS).toJS,
      );
    globalContext.setProperty(
      'CrazyGames'.toJS,
      JSObject()..setProperty('SDK'.toJS, sdk),
    );
  }

  final String environment;
  final Future<void>? initResult;
  final bool withSettings;
  final List<String> calls = <String>[];
  JSFunction? settingsListener;

  static JSObject _settings({required bool muteAudio}) =>
      JSObject()..setProperty('muteAudio'.toJS, muteAudio.toJS);

  void pushSettings({required bool muteAudio}) {
    settingsListener!.callAsFunction(null, _settings(muteAudio: muteAudio));
  }
}

void _removeSdk() => globalContext.delete('CrazyGames'.toJS);

void main() {
  tearDown(_removeSdk);

  test('missing SDK falls back to no-op', () async {
    _removeSdk();
    final platform = CrazyGamesPlatform();
    await platform.initialize();

    platform.gameplayStart();
    platform.gameplayStop();
  });

  test('disabled environment never calls the SDK', () async {
    final sdk = _FakeSdk(environment: 'disabled');
    final platform = CrazyGamesPlatform();
    await platform.initialize();

    platform.gameplayStart();
    expect(sdk.calls, isEmpty);
  });

  test('rejected init falls back to no-op', () async {
    final sdk = _FakeSdk(initResult: Future<void>.error('init failed'));
    final platform = CrazyGamesPlatform();
    await platform.initialize();

    platform.gameplayStart();
    expect(sdk.calls, isEmpty);
  });

  test('hung init times out and falls back to no-op', () async {
    final sdk = _FakeSdk(initResult: Completer<void>().future);
    final platform = CrazyGamesPlatform();
    await platform.initialize();

    platform.gameplayStart();
    expect(sdk.calls, isEmpty);
  });

  test('CrazyGames builds never offer leaderboard registration or ads', () {
    expect(CrazyGamesPlatform().allowsResultRegistration, isFalse);
    expect(CrazyGamesPlatform().allowsAds, isFalse);
  });

  test('gameplay events reach the SDK', () async {
    final sdk = _FakeSdk();
    final platform = CrazyGamesPlatform();
    await platform.initialize();

    platform.gameplayStart();
    platform.gameplayStop();
    expect(sdk.calls, <String>['gameplayStart', 'gameplayStop']);
  });

  test(
    'settings.muteAudio drives isAudioMuted and notifies listeners',
    () async {
      final sdk = _FakeSdk(withSettings: true);
      final platform = CrazyGamesPlatform();
      var notified = 0;
      platform.addAudioMuteListener(() => notified += 1);
      await platform.initialize();
      expect(platform.isAudioMuted, isFalse);

      sdk.pushSettings(muteAudio: true);
      expect(platform.isAudioMuted, isTrue);
      sdk.pushSettings(muteAudio: false);
      expect(platform.isAudioMuted, isFalse);
      expect(notified, 2);
    },
  );

  test('an SDK without settings stays audible', () async {
    _FakeSdk();
    final platform = CrazyGamesPlatform();
    await platform.initialize();
    expect(platform.isAudioMuted, isFalse);
    platform.gameplayStart();
  });
}
