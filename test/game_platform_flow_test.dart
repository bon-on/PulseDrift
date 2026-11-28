import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_drift/src/ads/ad_banner.dart';
import 'package:pulse_drift/src/game/game_controller.dart';
import 'package:pulse_drift/src/game/game_painter.dart';
import 'package:pulse_drift/src/game/game_screen.dart';
import 'package:pulse_drift/src/game/how_to_play.dart';
import 'package:pulse_drift/src/persistence/best_score_store.dart';
import 'package:pulse_drift/src/platform/game_platform.dart';

class _FakePlatform extends GamePlatform {
  _FakePlatform({
    this.allowsResultRegistration = false,
    this.allowsAds = false,
    this.showsRunBreakAds = false,
    this.replayPause = false,
  });

  /// Replays a pause that arrived before the screen registered.
  final bool replayPause;

  @override
  final bool showsRunBreakAds;

  /// Completes the break ad in flight; null when none was requested.
  Completer<void>? ad;

  void Function(bool paused)? pauseListener;

  @override
  Future<void> showRunBreakAd() {
    events.add('ad');
    return (ad = Completer<void>()).future;
  }

  @override
  void setPauseListener(void Function(bool paused)? listener) {
    pauseListener = listener;
    if (replayPause) listener?.call(true);
  }

  @override
  final bool allowsResultRegistration;

  @override
  final bool allowsAds;

  final List<String> events = <String>[];

  @override
  Future<void> initialize() async {}

  @override
  void gameplayStart() => events.add('start');

  @override
  void gameplayStop() => events.add('stop');
}

class _Tutorial implements TutorialStore {
  _Tutorial({this.seen = false});

  bool seen;

  @override
  Future<bool> isSeen() async => seen;

  @override
  Future<void> markSeen() async => seen = true;
}

class _MemoryBestScoreStore implements BestScoreStore {
  @override
  Future<int> loadBestScore() async => 0;

  @override
  Future<void> saveBestScore(int score) async {}
}

Future<void> _pump(
  WidgetTester tester,
  _FakePlatform platform,
  TutorialStore tutorial, {
  bool enableAds = false,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: GameScreen(
        enableAds: enableAds,
        platform: platform,
        tutorialStore: tutorial,
        bestScoreStore: _MemoryBestScoreStore(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
}

GameController _controller(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.byWidgetPredicate((w) => w is CustomPaint && w.painter is GamePainter),
  );
  return (paint.painter! as GamePainter).controller;
}

/// Leaves the ready card the way a keyboard player does.
Future<void> _start(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.space);
  await tester.pump();
}

/// Idles until the run crashes (no input is sent, so a gate eventually hits).
Future<void> _crash(WidgetTester tester) async {
  final game = _controller(tester);
  for (var i = 0; i < 2400 && !game.isGameOver; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(game.isGameOver, isTrue);
}

/// Lets the crash shatter play out until the run summary is up.
Future<void> _waitSummary(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Steers into a walled lane of the first gate, so the run ends at 0 points.
Future<void> _crashWithoutScore(WidgetTester tester) async {
  final game = _controller(tester);
  for (var i = 0; i < 2400 && !game.isGameOver; i++) {
    if (game.gates.isNotEmpty) {
      final gate = game.gates.first;
      final wall = [0, 1, 2].firstWhere((l) => !gate.openLanes.contains(l));
      game.handlePointerX(game.laneCenters[wall]);
    }
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(game.isGameOver, isTrue);
  expect(game.score, 0);
}

/// Dodges until the first points land, then idles into a wall.
Future<void> _crashAfterScoring(WidgetTester tester) async {
  final game = _controller(tester);
  for (var i = 0; i < 2400 && !game.isGameOver; i++) {
    final next = game.gates.where((g) => !g.scored);
    if (game.score == 0 && next.isNotEmpty) {
      game.handlePointerX(game.laneCenters[next.first.openLanes.first]);
    }
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(game.isGameOver, isTrue);
  expect(game.score, greaterThan(0));
}

void main() {
  testWidgets('inactive and hidden states freeze the run until resume', (
    tester,
  ) async {
    final platform = _FakePlatform();
    await _pump(tester, platform, _Tutorial(seen: true));
    await _start(tester);
    await tester.pump(const Duration(milliseconds: 30));
    final game = _controller(tester);
    final seconds = game.runSeconds;
    final lane = game.currentLane;

    final binding = tester.binding;
    addTearDown(
      () => binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed),
    );
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    expect(game.currentLane, lane);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(seconds: 5));
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump(const Duration(seconds: 5));
    expect(game.runSeconds, seconds);
    expect(game.currentLane, lane);
    expect(platform.events, ['start', 'stop']);

    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 5));
    expect(game.runSeconds, seconds);
    await tester.pump(const Duration(milliseconds: 16));
    expect(game.runSeconds, closeTo(seconds + 0.016, 0.000001));
    expect(platform.events, ['start', 'stop', 'start']);
  });

  testWidgets('the run waits on the ready card until the first input', (
    tester,
  ) async {
    final platform = _FakePlatform();
    await _pump(tester, platform, _Tutorial(seen: true));
    final game = _controller(tester);
    expect(find.text('Tap / press Space to start'), findsOneWidget);
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(game.gates, isEmpty);
    expect(platform.events, isEmpty);

    await _start(tester);
    expect(platform.events, <String>['start']);
    expect(find.text('Tap / press Space to start'), findsNothing);
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(game.gates, isNotEmpty);
  });

  testWidgets('a tap on the ready card starts without shifting lanes', (
    tester,
  ) async {
    final platform = _FakePlatform();
    await _pump(tester, platform, _Tutorial(seen: true));
    final game = _controller(tester);
    await tester.tapAt(const Offset(30, 500));
    await tester.pump();
    expect(platform.events, <String>['start']);
    expect(game.currentLane, 1);
  });

  testWidgets('a lane key on the ready card starts and moves', (tester) async {
    final platform = _FakePlatform();
    await _pump(tester, platform, _Tutorial(seen: true));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(platform.events, <String>['start']);
    expect(_controller(tester).currentLane, 0);
  });

  testWidgets(
    'first launch starts gameplay only after the tutorial and first input',
    (tester) async {
      final platform = _FakePlatform();
      await _pump(tester, platform, _Tutorial());
      expect(find.text('How to play'), findsOneWidget);
      expect(platform.events, isEmpty);

      await tester.tap(find.text('Skip'));
      await tester.pump();
      expect(platform.events, isEmpty);
      await _start(tester);
      expect(platform.events, <String>['start']);
    },
  );

  testWidgets('reopening the tutorial stops and closing it restarts', (
    tester,
  ) async {
    final platform = _FakePlatform();
    await _pump(tester, platform, _Tutorial(seen: true));
    await _start(tester);

    await tester.tap(find.byTooltip('How to play'));
    await tester.pump();
    expect(platform.events, <String>['start', 'stop']);

    await tester.tap(find.text('Skip'));
    await tester.pump();
    expect(platform.events, <String>['start', 'stop', 'start']);
  });

  testWidgets('crash stops gameplay and restart starts it again', (
    tester,
  ) async {
    final platform = _FakePlatform();
    await _pump(tester, platform, _Tutorial(seen: true));
    await _start(tester);

    await _crash(tester);
    await tester.pump();
    expect(platform.events, <String>['start', 'stop']);

    await _waitSummary(tester);
    await tester.tap(find.text('Play again'));
    await tester.pump();
    expect(platform.events, <String>['start', 'stop', 'start']);
  });

  testWidgets('a held restart key repeating after a crash does not restart', (
    tester,
  ) async {
    final platform = _FakePlatform();
    await _pump(tester, platform, _Tutorial(seen: true));

    // The key is already held down when the run crashes (its press also
    // left the ready card).
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await _crash(tester);
    await tester.pump();
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(_controller(tester).isGameOver, isTrue);
    expect(platform.events, <String>['start', 'stop']);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
  });

  testWidgets('simulation and input wait for the stored flag', (tester) async {
    final platform = _FakePlatform();
    final gate = _GatedTutorial();
    await _pump(tester, platform, gate);
    final game = _controller(tester);

    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(game.gates, isEmpty);
    expect(game.score, 0);
    expect(platform.events, isEmpty);

    final lane = game.currentLane;
    await tester.tapAt(const Offset(10, 500));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(game.currentLane, lane);

    gate.release(true);
    await tester.pump();
    await tester.pump();
    expect(platform.events, isEmpty);
    await _start(tester);
    expect(platform.events, <String>['start']);
  });

  testWidgets('Ctrl+arrow is left to the host', (tester) async {
    final platform = _FakePlatform();
    await _pump(tester, platform, _Tutorial(seen: true));
    final game = _controller(tester);
    final lane = game.currentLane;

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pump();
    expect(game.currentLane, lane);
  });

  testWidgets('ads and leaderboard follow the platform', (tester) async {
    final off = _FakePlatform();
    await _pump(tester, off, _Tutorial(seen: true), enableAds: true);
    expect(tester.widget<AdBanner>(find.byType(AdBanner)).enabled, isFalse);
    await _start(tester);
    await _crashAfterScoring(tester);
    await _waitSummary(tester);
    await tester.pump();
    expect(find.text('기록을 등록할까요?'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    final on = _FakePlatform(allowsResultRegistration: true, allowsAds: true);
    await _pump(tester, on, _Tutorial(seen: true), enableAds: false);
    await _start(tester);
    await _crashAfterScoring(tester);
    await _waitSummary(tester);
    await tester.pump();
    expect(find.text('기록을 등록할까요?'), findsOneWidget);
  });

  testWidgets('Play again after a crash waits for the break ad', (
    tester,
  ) async {
    final platform = _FakePlatform(showsRunBreakAds: true);
    await _pump(tester, platform, _Tutorial(seen: true));
    await _start(tester);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(platform.events, <String>['start'], reason: 'no ad mid-run');

    await _crash(tester);
    expect(platform.events, <String>['start', 'stop'], reason: 'no ad yet');
    await _waitSummary(tester);
    await tester.tap(find.text('Play again'));
    await tester.pump();
    // Repeated presses (tap and Enter) while the ad runs are ignored.
    await tester.tap(find.text('Play again'), warnIfMissed: false);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(platform.events, <String>['start', 'stop', 'ad']);
    expect(find.text('Play again'), findsOneWidget);
    expect(_controller(tester).isGameOver, isTrue);

    platform.ad!.complete();
    await tester.pump();
    await tester.pump();
    expect(platform.events, <String>['start', 'stop', 'ad', 'start']);
    expect(find.text('Play again'), findsNothing);
    expect(_controller(tester).isGameOver, isFalse);
  });

  testWidgets('Enter and Escape on the summary also wait for the ad', (
    tester,
  ) async {
    final platform = _FakePlatform(showsRunBreakAds: true);
    await _pump(tester, platform, _Tutorial(seen: true));
    await _start(tester);
    await _crash(tester);
    await _waitSummary(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(platform.events, <String>['start', 'stop', 'ad']);
    platform.ad!.complete();
    await tester.pump();
    await tester.pump();
    expect(platform.events, <String>['start', 'stop', 'ad', 'start']);

    await _crash(tester);
    await _waitSummary(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(platform.events.last, 'ad');
    platform.ad!.complete();
    await tester.pump();
    await tester.pump();
    // Menu goes back to the ready card: no gameplay until the next input.
    expect(find.text('Tap / press Space to start'), findsOneWidget);
    expect(platform.events, <String>[
      'start',
      'stop',
      'ad',
      'start',
      'stop',
      'ad',
    ]);
  });

  testWidgets('a portal pause freezes the run until it resumes', (
    tester,
  ) async {
    final platform = _FakePlatform();
    await _pump(tester, platform, _Tutorial(seen: true));
    expect(platform.pauseListener, isNotNull);
    await _start(tester);
    final game = _controller(tester);
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(game.gates, isNotEmpty);
    final seconds = game.runSeconds;
    final score = game.score;
    final lane = game.currentLane;
    final gateY = [for (final g in game.gates) g.yPosition];

    platform.pauseListener!(true);
    platform.pauseListener!(true);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.tapAt(const Offset(30, 500));
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(game.runSeconds, seconds);
    expect(game.score, score);
    expect(game.currentLane, lane);
    expect([for (final g in game.gates) g.yPosition], gateY);
    expect(game.isGameOver, isFalse);
    expect(platform.events, <String>['start', 'stop']);

    platform.pauseListener!(false);
    await tester.pump(const Duration(seconds: 5));
    expect(game.runSeconds, seconds, reason: 'paused time is not banked');
    await tester.pump(const Duration(milliseconds: 16));
    expect(game.runSeconds, closeTo(seconds + 0.016, 0.000001));
    expect(platform.events, <String>['start', 'stop', 'start']);

    await tester.pumpWidget(const SizedBox());
    expect(platform.pauseListener, isNull);
  });

  testWidgets('the run goes on only when portal and app both allow it', (
    tester,
  ) async {
    final platform = _FakePlatform();
    await _pump(tester, platform, _Tutorial(seen: true));
    await _start(tester);
    await tester.pump(const Duration(milliseconds: 30));
    final game = _controller(tester);
    final binding = tester.binding;
    addTearDown(
      () => binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed),
    );

    // App back in the foreground, portal still paused: frozen.
    platform.pauseListener!(true);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    var seconds = game.runSeconds;
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(game.runSeconds, seconds, reason: 'the portal still pauses');

    // Portal resumed, app inactive: still frozen.
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    platform.pauseListener!(false);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(game.runSeconds, seconds, reason: 'the app is still inactive');

    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    seconds = game.runSeconds;
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(game.runSeconds, greaterThan(seconds));
  });

  testWidgets('a pause from before the screen existed is replayed', (
    tester,
  ) async {
    final platform = _FakePlatform(replayPause: true);
    await _pump(tester, platform, _Tutorial(seen: true));
    final game = _controller(tester);
    await _start(tester);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(game.runSeconds, 0);
    expect(platform.events, isEmpty);

    platform.pauseListener!(false);
    await _start(tester);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(game.runSeconds, greaterThan(0));
    expect(platform.events, <String>['start']);
  });

  testWidgets('a portal pause on the summary holds Play again and the ad', (
    tester,
  ) async {
    final platform = _FakePlatform(showsRunBreakAds: true);
    await _pump(tester, platform, _Tutorial(seen: true));
    await _start(tester);
    await _crash(tester);
    await _waitSummary(tester);

    platform.pauseListener!(true);
    await tester.pump();
    await tester.tap(find.text('Play again'), warnIfMissed: false);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(platform.events, <String>['start', 'stop']);
    expect(find.text('Play again'), findsOneWidget);

    platform.pauseListener!(false);
    await tester.pump();
    await tester.tap(find.text('Play again'));
    await tester.pump();
    expect(platform.events, <String>['start', 'stop', 'ad']);
  });

  testWidgets('an inactive window does not swallow a summary click', (
    tester,
  ) async {
    final platform = _FakePlatform();
    await _pump(tester, platform, _Tutorial(seen: true));
    await _start(tester);
    await _crash(tester);
    await _waitSummary(tester);
    final binding = tester.binding;
    addTearDown(
      () => binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed),
    );

    // Web: the click that refocuses the window lands while still inactive.
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Play again')),
    );
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await gesture.up();
    await tester.pump();
    expect(find.text('Play again'), findsNothing);
    expect(platform.events, <String>['start', 'stop', 'start']);
  });

  testWidgets('a 0-point run never offers leaderboard registration', (
    tester,
  ) async {
    final on = _FakePlatform(allowsResultRegistration: true);
    await _pump(tester, on, _Tutorial(seen: true));
    await _start(tester);
    await _crashWithoutScore(tester);
    await _waitSummary(tester);
    await tester.pump();
    expect(find.text('기록을 등록할까요?'), findsNothing);
  });
}

class _GatedTutorial extends _Tutorial {
  final _completer = Completer<bool>();

  void release(bool value) => _completer.complete(value);

  @override
  Future<bool> isSeen() => _completer.future;
}
