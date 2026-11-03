import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'crazygames_prefs_store.dart';
import 'game_platform.dart';

/// CrazyGames HTML5 SDK v3 adapter. The SDK script is injected into the
/// bundle by `tool/build_crazygames.sh`.
///
/// Any SDK failure downgrades to no-op behaviour so the game stays playable.
class CrazyGamesPlatform extends GamePlatform {
  CrazyGamesPlatform();

  static const Duration _initTimeout = Duration(seconds: 5);

  _Sdk? _sdk;

  /// Replaces the page reload done on a login/logout (tests only).
  @visibleForTesting
  void Function()? reloadOverride;
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
    await _useCloudSave(sdk);
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

  /// Routes shared_preferences through the SDK Data module so logged-in
  /// players keep progress across devices. Any failure keeps localStorage.
  Future<void> _useCloudSave(_Sdk sdk) async {
    if (SharedPreferencesStorePlatform.instance is CloudPrefsStore) return;
    try {
      final data = sdk.data;
      final user = sdk.user;
      if (data == null || user == null) return;
      // A login or logout swaps the Data module to another player's data;
      // reload so stale in-memory values never overwrite it. The listener is
      // registered before the initial user is known so no switch is missed;
      // early events are compared once the cloud store is active. Without an
      // active cloud store there is nothing to protect, so no reload.
      var cloudActive = false;
      String? initialName;
      var sawEarlyEvent = false;
      String? earlyName;
      user.addAuthListener(
        ((_User? changed) {
          final name = changed?.username;
          if (!cloudActive) {
            sawEarlyEvent = true;
            earlyName = name;
            return;
          }
          if (name != initialName) _reload();
        }).toJS,
      );
      final initial = await user.getUser().toDart.timeout(_initTimeout);
      initialName = initial?.username;
      SharedPreferencesStorePlatform.instance = await CloudPrefsStore.load(
        cloud: _JsCloudData(data),
        local: SharedPreferencesStorePlatform.instance,
        localStamp: _LocalStorageData(),
        owner: initialName,
      );
      cloudActive = true;
      if (sawEarlyEvent && earlyName != initialName) _reload();
    } catch (error) {
      debugPrint('CrazyGames data module unavailable: $error');
    }
  }

  void _reload() {
    final reload = reloadOverride;
    if (reload != null) {
      reload();
      return;
    }
    globalContext
        .getProperty<JSObject>('location'.toJS)
        .callMethod<JSAny?>('reload'.toJS);
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
  external _DataModule? get data;
  external _UserModule? get user;
}

extension type _DataModule._(JSObject _) implements JSObject {
  external String? getItem(String key);
  external void setItem(String key, String value);
}

extension type _UserModule._(JSObject _) implements JSObject {
  external JSPromise<_User?> getUser();
  external void addAuthListener(JSFunction listener);
}

extension type _User._(JSObject _) implements JSObject {
  external String? get username;
}

class _LocalStorageData implements CloudData {
  JSObject get _storage =>
      globalContext.getProperty<JSObject>('localStorage'.toJS);

  @override
  String? getItem(String key) =>
      _storage.callMethod<JSString?>('getItem'.toJS, key.toJS)?.toDart;

  @override
  void setItem(String key, String value) =>
      _storage.callMethod<JSAny?>('setItem'.toJS, key.toJS, value.toJS);
}

class _JsCloudData implements CloudData {
  _JsCloudData(this._data);

  final _DataModule _data;

  @override
  String? getItem(String key) => _data.getItem(key);

  @override
  void setItem(String key, String value) => _data.setItem(key, value);
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
