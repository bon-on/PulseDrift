import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_drift/src/audio/sound_mute_store.dart';
import 'package:pulse_drift/src/game/game_controller.dart';
import 'package:pulse_drift/src/game/game_painter.dart';
import 'package:pulse_drift/src/game/game_screen.dart';
import 'package:pulse_drift/src/game/how_to_play.dart';
import 'package:pulse_drift/src/meta/drift_progress.dart';
import 'package:pulse_drift/src/meta/drift_theme.dart';
import 'package:pulse_drift/src/meta/progress_store.dart';
import 'package:pulse_drift/src/persistence/best_score_store.dart';
import 'package:pulse_drift/src/platform/game_platform.dart';

class _Seen implements TutorialStore {
  @override
  Future<bool> isSeen() async => true;

  @override
  Future<void> markSeen() async {}
}

class _Unmuted extends SoundMuteStore {
  @override
  Future<bool> loadMuted() async => false;

  @override
  Future<void> saveMuted(bool muted) async {}
}

class _Best implements BestScoreStore {
  int value = 0;

  @override
  Future<int> loadBestScore() async => value;

  @override
  Future<void> saveBestScore(int score) async => value = score;
}

class _Platform extends NoopGamePlatform {
  _Platform() : super(allowsAds: false, allowsResultRegistration: false);

  final List<String> events = <String>[];

  @override
  void gameplayStart() => events.add('start');

  @override
  void gameplayStop() => events.add('stop');
}

class _GatedProgressStore extends MemoryProgressStore {
  _GatedProgressStore(super.value);

  final Completer<void> gate = Completer<void>();

  @override
  Future<DriftProgress> load() async {
    await gate.future;
    return value;
  }
}

class _BrokenProgressStore extends ProgressStore {
  @override
  Future<DriftProgress> load() async => throw StateError('disk');

  @override
  Future<void> save(DriftProgress progress) async => throw StateError('disk');
}

DriftProgress _progressAt(int xp, [DriftTheme theme = DriftTheme.neon]) =>
    DriftProgress(totalXp: xp, bestSeconds: 0, runs: 0, selectedTheme: theme);

Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  ProgressStore? progress,
  GamePlatform? platform,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: GameScreen(
        platform: platform ?? _Platform(),
        tutorialStore: _Seen(),
        bestScoreStore: _Best(),
        progressStore: progress ?? MemoryProgressStore(),
        random: math.Random(5),
        soundMuteStore: _Unmuted(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
}

GameController _game(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.byWidgetPredicate((w) => w is CustomPaint && w.painter is GamePainter),
  );
  return (paint.painter! as GamePainter).controller;
}

/// Starts a run, dodges until it scores, then idles into a wall and waits
/// for the summary.
Future<void> _playToSummary(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.space);
  await tester.pump();
  final game = _game(tester);
  for (var i = 0; i < 2400 && !game.isGameOver; i++) {
    final next = game.gates.where((g) => !g.scored);
    if (game.score < 30 && next.isNotEmpty) {
      game.handlePointerX(game.laneCenters[next.first.openLanes.first]);
    }
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(game.isGameOver, isTrue);
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(find.text('Play again'), findsOneWidget);
}

void main() {
  for (final size in const [Size(1280, 720), Size(1366, 768), Size(390, 844)]) {
    testWidgets('ready, run, summary and themes fit at $size', (tester) async {
      await _pump(
        tester,
        size: size,
        progress: MemoryProgressStore(_progressAt(5000)),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Tap / press Space to start'), findsOneWidget);
      expect(find.byTooltip('How to play'), findsOneWidget);
      expect(find.byTooltip('Themes'), findsOneWidget);

      await _playToSummary(tester);
      expect(tester.takeException(), isNull);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.tap(find.byTooltip('Themes'));
      await tester.pump();
      expect(find.text('Themes'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('summary blocks the playfield; Enter plays again', (
    tester,
  ) async {
    final platform = _Platform();
    await _pump(tester, platform: platform);
    await _playToSummary(tester);
    expect(platform.events, ['start', 'stop']);
    final game = _game(tester);
    final lane = game.currentLane;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.tapAt(const Offset(20, 700));
    await tester.pump();
    expect(game.currentLane, lane);
    expect(find.text('Play again'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text('Play again'), findsNothing);
    expect(game.isGameOver, isFalse);
    expect(platform.events, ['start', 'stop', 'start']);
    // Game keys reach the run again.
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(game.currentLane, 0);
  });

  testWidgets('Esc on the summary returns to the ready card', (tester) async {
    final platform = _Platform();
    await _pump(tester, platform: platform);
    await _playToSummary(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('Play again'), findsNothing);
    expect(find.text('Tap / press Space to start'), findsOneWidget);
    expect(platform.events, ['start', 'stop']);
    expect(_game(tester).score, 0);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(platform.events, ['start', 'stop', 'start']);
  });

  testWidgets('keys while the ship shatters do not skip the summary', (
    tester,
  ) async {
    await _pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    final game = _game(tester);
    for (var i = 0; i < 2400 && !game.isGameOver; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(game.isGameOver, isTrue);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Play again'), findsOneWidget);
  });

  testWidgets('a finished run saves XP, runs and best time', (tester) async {
    final store = MemoryProgressStore();
    await _pump(tester, progress: store);
    await _playToSummary(tester);
    expect(store.saveCount, 1);
    expect(store.value.runs, 1);
    expect(store.value.totalXp, greaterThan(0));
    expect(store.value.bestSeconds, greaterThan(0));
    expect(find.textContaining('XP'), findsWidgets);
  });

  testWidgets('a run that ends before progress loads is merged, not lost', (
    tester,
  ) async {
    final store = _GatedProgressStore(_progressAt(700, DriftTheme.sunset));
    await _pump(tester, progress: store);
    await _playToSummary(tester);
    // Never saved before the stored value was read.
    expect(store.saveCount, 0);
    store.gate.complete();
    await tester.pump();
    await tester.pump();
    expect(store.saveCount, 1);
    expect(store.value.totalXp, greaterThan(700));
    expect(store.value.runs, 1);
    expect(store.value.selectedTheme, DriftTheme.sunset);
  });

  testWidgets('broken progress storage never blocks play', (tester) async {
    await _pump(tester, progress: _BrokenProgressStore());
    await _playToSummary(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(_game(tester).isGameOver, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('themes: locked ones stay locked, unlocked ones are saved', (
    tester,
  ) async {
    // Level 3: Neon and Sunset open, Aurora and Void locked.
    final store = MemoryProgressStore(_progressAt(260));
    final platform = _Platform();
    await _pump(tester, progress: store, platform: platform);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    await tester.tap(find.byTooltip('Themes'));
    await tester.pump();
    // Opening the picker mid-run pauses gameplay.
    expect(platform.events, ['start', 'stop']);
    expect(find.text('Lv 6'), findsOneWidget);
    expect(find.text('Lv 10'), findsOneWidget);

    await tester.tap(find.text('Aurora'));
    await tester.pump();
    expect(store.value.selectedTheme, DriftTheme.neon);

    await tester.tap(find.text('Sunset'));
    await tester.pump();
    expect(store.value.selectedTheme, DriftTheme.sunset);
    expect(find.text('Selected'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('Lv 6'), findsNothing);
    expect(platform.events, ['start', 'stop', 'start']);
  });

  testWidgets('crash stops the music and Play again restarts it', (
    tester,
  ) async {
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
    await _pump(tester);
    expect(calls, contains('startLoop'));
    calls.clear();
    await _playToSummary(tester);
    expect(calls, contains('stopLoop'));
    expect(calls, isNot(contains('startLoop')));
    calls.clear();
    await tester.tap(find.text('Play again'));
    await tester.pump();
    expect(calls, contains('startLoop'));
  });
}
