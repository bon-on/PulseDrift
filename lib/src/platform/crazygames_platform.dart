import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';

import 'game_platform.dart';

/// CrazyGames HTML5 SDK v3 adapter. The SDK script is injected into the
/// bundle by `tool/build_crazygames.sh`.
///
/// Any SDK failure downgrades to no-op behaviour so the game stays playable.
class CrazyGamesPlatform extends GamePlatform {
  CrazyGamesPlatform();

  static const Duration _initTimeout = Duration(seconds: 5);

  _Sdk? _sdk;
  bool _settingsMuted = false;
  final List<void Function()> _muteListeners = <void Function()>[];

  @override
  Future<void> initialize() async {
    final sdk = _findSdk();
    if (sdk == null) {
      debugPrint('CrazyGames SDK not found; running without it.');
      return;
    }
    try {
      // A hung init (blocked SDK requests) must not keep the game from starting.
      await sdk.init().toDart.timeout(_initTimeout);
      final environment = sdk.environment;
      if (environment != 'crazygames' && environment != 'local') {
        debugPrint('CrazyGames SDK environment "$environment"; disabled.');
        return;
      }
      _sdk = sdk;
    } catch (error) {
      debugPrint('CrazyGames SDK init failed: $error');
      _sdk = null;
      return;
    }
    _watchSettings(sdk);
  }

  void _watchSettings(_Sdk sdk) {
    // Older SDK builds may lack settings; the game then simply stays audible.
    try {
      _applySettings(sdk.game.settings);
      sdk.game.addSettingsChangeListener(
        ((_Settings? settings) {
          _applySettings(settings);
          for (final listener in List.of(_muteListeners)) {
            listener();
          }
        }).toJS,
      );
    } catch (error) {
      debugPrint('CrazyGames settings unavailable: $error');
    }
  }

  void _applySettings(_Settings? settings) {
    _settingsMuted = settings?.muteAudio ?? false;
  }

  @override
  bool get isAudioMuted => _settingsMuted;

  @override
  void addAudioMuteListener(void Function() listener) =>
      _muteListeners.add(listener);

  @override
  void gameplayStart() => _call((sdk) => sdk.game.gameplayStart());

  @override
  void gameplayStop() => _call((sdk) => sdk.game.gameplayStop());

  @override
  bool get allowsAds => false;

  @override
  bool get allowsResultRegistration => false;

  void _call(void Function(_Sdk sdk) action) {
    final sdk = _sdk;
    if (sdk == null) {
      return;
    }
    try {
      action(sdk);
    } catch (error) {
      debugPrint('CrazyGames SDK call failed: $error');
    }
  }

  static _Sdk? _findSdk() {
    try {
      final crazyGames = globalContext.getProperty<JSObject?>(
        'CrazyGames'.toJS,
      );
      return crazyGames?.getProperty<_Sdk?>('SDK'.toJS);
    } catch (_) {
      return null;
    }
  }
}

extension type _Sdk._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> init();
  external String get environment;
  external _GameModule get game;
}

extension type _GameModule._(JSObject _) implements JSObject {
  external void gameplayStart();
  external void gameplayStop();
  external _Settings? get settings;
  external void addSettingsChangeListener(JSFunction listener);
}

extension type _Settings._(JSObject _) implements JSObject {
  external bool? get muteAudio;
}
