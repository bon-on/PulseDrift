import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_drift/src/audio/sound_fx.dart';
import 'package:pulse_drift/src/audio/sound_mute_store.dart';
import 'package:pulse_drift/src/audio/web_sound_stub.dart';
import 'package:pulse_drift/src/game/game_screen.dart';
import 'package:pulse_drift/src/game/how_to_play.dart';
import 'package:pulse_drift/src/persistence/best_score_store.dart';
import 'package:pulse_drift/src/platform/game_platform.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeWeb extends WebSound {
  final List<String> calls = <String>[];
  bool allowLoop = true;

  @override
  void play(String assetKey, {double volume = 1}) =>
      calls.add('play:$assetKey');

  @override
  Future<bool> startLoop(String assetKey, {double volume = 1}) async {
    calls.add('startLoop:$assetKey:$allowLoop');
    return allowLoop;
  }

  @override
  void stopLoop(String assetKey) => calls.add('stopLoop:$assetKey');
}

class _MemoryMuteStore extends SoundMuteStore {
  bool muted = false;
  int writes = 0;

  @override
  Future<bool> loadMuted() async => muted;

  @override
  Future<void> saveMuted(bool value) async {
    muted = value;
    writes += 1;
  }
}

class _MutedPlatform extends NoopGamePlatform {
  _MutedPlatform();

  bool platformMuted = false;
  void Function()? listener;

  @override
  bool get isAudioMuted => platformMuted;

  @override
  void addAudioMuteListener(void Function() l) => listener = l;
}

class _SeenTutorial implements TutorialStore {
  @override
  Future<bool> isSeen() async => true;

  @override
  Future<void> markSeen() async {}
}

class _ZeroBest implements BestScoreStore {
  @override
  Future<int> loadBestScore() async => 0;

  @override
  Future<void> saveBestScore(int score) async {}
}

const _loop = 'assets/audio/background_loop.wav';

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('web playback', () {
    test('plays effects and respects user mute', () async {
      final web = _FakeWeb();
      final fx = SoundFx(webSound: web, isWeb: true, store: _MemoryMuteStore());
      await fx.initialize();
      fx.play(Sfx.pulsePass);
      fx.play(Sfx.crash);
      expect(web.calls, [
        'play:assets/audio/pulse_pass.wav',
        'play:assets/audio/crash.wav',
      ]);
      web.calls.clear();
      unawaited(fx.setUserMuted(true));
      fx.play(Sfx.crash);
      expect(web.calls, isEmpty);
    });

    test('respects platform mute', () async {
      final web = _FakeWeb();
      var platformMuted = true;
      final fx = SoundFx(
        webSound: web,
        isWeb: true,
        isPlatformMuted: () => platformMuted,
        store: _MemoryMuteStore(),
      );
      await fx.initialize();
      fx.play(Sfx.pulsePass);
      expect(web.calls, isEmpty);
      platformMuted = false;
      fx.play(Sfx.pulsePass);
      expect(web.calls, hasLength(1));
    });

    test('loop waits for the first user input', () async {
      final web = _FakeWeb();
      final fx = SoundFx(webSound: web, isWeb: true, store: _MemoryMuteStore());
      await fx.initialize();
      fx.startBackgroundLoop();
      await _settle();
      expect(web.calls, isEmpty);
      fx.onUserInput();
      await _settle();
      expect(web.calls, ['startLoop:$_loop:true']);
      fx.onUserInput();
      await _settle();
      expect(web.calls, hasLength(1));
    });

    test('a refused loop is retried on the next input', () async {
      final web = _FakeWeb()..allowLoop = false;
      final fx = SoundFx(webSound: web, isWeb: true, store: _MemoryMuteStore());
      await fx.initialize();
      fx.startBackgroundLoop();
      fx.onUserInput();
      await _settle();
      web.allowLoop = true;
      fx.onUserInput();
      await _settle();
      expect(web.calls, ['startLoop:$_loop:false', 'startLoop:$_loop:true']);
    });

    test('muting stops the loop and unmuting resumes it', () async {
      final web = _FakeWeb();
      final fx = SoundFx(webSound: web, isWeb: true, store: _MemoryMuteStore());
      await fx.initialize();
      fx.startBackgroundLoop();
      fx.onUserInput();
      await _settle();
      web.calls.clear();
      await fx.setUserMuted(true);
      expect(web.calls, ['stopLoop:$_loop']);
      web.calls.clear();
      await fx.setUserMuted(false);
      await _settle();
      expect(web.calls, ['startLoop:$_loop:true']);
    });

    test('crash stops the loop; restart starts it again', () async {
      final web = _FakeWeb();
      final fx = SoundFx(webSound: web, isWeb: true, store: _MemoryMuteStore());
      await fx.initialize();
      fx.startBackgroundLoop();
      fx.onUserInput();
      await _settle();
      web.calls.clear();
      fx.stopBackgroundLoop();
      fx.play(Sfx.crash);
      fx.startBackgroundLoop();
      await _settle();
      expect(web.calls, [
        'stopLoop:$_loop',
        'play:assets/audio/crash.wav',
        'startLoop:$_loop:true',
      ]);
    });
  });

  group('native playback', () {
    late List<String> calls;

    setUp(() {
      calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('pulse_drift/audio'), (
            call,
          ) async {
            calls.add(call.method);
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('pulse_drift/audio'),
            null,
          );
    });

    test('keeps the existing method names and honors mute', () async {
      final fx = SoundFx(isWeb: false, store: _MemoryMuteStore());
      await fx.initialize();
      fx.startBackgroundLoop();
      fx.play(Sfx.pulsePass);
      fx.play(Sfx.crash);
      await _settle();
      expect(calls, ['startBackgroundLoop', 'playPulsePass', 'playCrash']);
      calls.clear();
      await fx.setUserMuted(true);
      fx.play(Sfx.pulsePass);
      await _settle();
      expect(calls, ['stopBackgroundLoop']);
    });

    test('a missing native channel is swallowed', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('pulse_drift/audio'),
            null,
          );
      final fx = SoundFx(isWeb: false, store: _MemoryMuteStore());
      await fx.initialize();
      fx.startBackgroundLoop();
      fx.play(Sfx.crash);
      fx.dispose();
      await _settle();
    });
  });

  test('mute choice persists under sound_muted_v1', () async {
    SharedPreferences.setMockInitialValues({});
    const store = SoundMuteStore();
    expect(await store.loadMuted(), isFalse);
    await store.saveMuted(true);
    expect(await store.loadMuted(), isTrue);
    expect(
      (await SharedPreferences.getInstance()).getBool('sound_muted_v1'),
      isTrue,
    );
    final fx = SoundFx(isWeb: true, webSound: _FakeWeb(), store: store);
    await fx.initialize();
    expect(fx.userMuted, isTrue);
  });

  test('every audio asset used by SoundFx exists and is bundled', () {
    final paths = <String>{
      for (final sfx in Sfx.values) sfx.assetKey,
      backgroundLoopAsset,
    };
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('- assets/audio/'),
    );
    for (final path in paths) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
    expect(File('assets/audio/crash.wav').lengthSync(), lessThan(40 * 1024));
  });

  testWidgets('toggle flips icon, persists and follows platform mute', (
    tester,
  ) async {
    final store = _MemoryMuteStore();
    final platform = _MutedPlatform();
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('pulse_drift/audio'), (
          call,
        ) async {
          calls.add(call.method);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('pulse_drift/audio'),
            null,
          ),
    );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          platform: platform,
          tutorialStore: _SeenTutorial(),
          bestScoreStore: _ZeroBest(),
          soundMuteStore: store,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    expect(find.byTooltip('Sound on'), findsOneWidget);
    expect(calls, contains('startBackgroundLoop'));

    calls.clear();
    await tester.tap(find.byIcon(Icons.volume_up_rounded));
    await tester.pump();
    expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
    expect(find.byTooltip('Sound off'), findsOneWidget);
    expect(store.muted, isTrue);
    expect(calls, ['stopBackgroundLoop']);

    calls.clear();
    await tester.tap(find.byIcon(Icons.volume_off_rounded));
    await tester.pump();
    expect(store.muted, isFalse);
    expect(calls, ['startBackgroundLoop']);

    calls.clear();
    platform.platformMuted = true;
    platform.listener!();
    await tester.pump();
    expect(calls, ['stopBackgroundLoop']);
    // The header fits next to the extra button without overflowing.
    expect(tester.takeException(), isNull);
  });

  test('nothing plays before the stored mute is read', () async {
    final web = _FakeWeb();
    final gate = Completer<bool>();
    final store = _GatedStore(gate.future);
    final fx = SoundFx(webSound: web, isWeb: true, store: store);
    fx.startBackgroundLoop();
    fx.onUserInput();
    fx.play(Sfx.crash);
    await _settle();
    expect(web.calls, isEmpty);
    final init = fx.initialize();
    gate.complete(true);
    await init;
    await _settle();
    expect(web.calls, isEmpty);
    expect(fx.userMuted, isTrue);
  });

  test('a toggle made before the stored value loads wins', () async {
    final gate = Completer<bool>();
    final fx = SoundFx(
      webSound: _FakeWeb(),
      isWeb: true,
      store: _GatedStore(gate.future),
    );
    final init = fx.initialize();
    await fx.setUserMuted(false);
    gate.complete(true);
    await init;
    expect(fx.userMuted, isFalse);
  });
}

class _GatedStore extends SoundMuteStore {
  _GatedStore(this.value);

  final Future<bool> value;

  @override
  Future<bool> loadMuted() => value;

  @override
  Future<void> saveMuted(bool muted) async {}
}
