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
  });

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

    await tester.tap(find.text('Restart'));
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
    await tester.pump();
    await tester.pump();
    expect(find.text('기록을 등록할까요?'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    final on = _FakePlatform(allowsResultRegistration: true, allowsAds: true);
    await _pump(tester, on, _Tutorial(seen: true), enableAds: false);
    await _start(tester);
    await _crashAfterScoring(tester);
    await tester.pump();
    await tester.pump();
    expect(find.text('기록을 등록할까요?'), findsOneWidget);
  });

  testWidgets('a 0-point run never offers leaderboard registration', (
    tester,
  ) async {
    final on = _FakePlatform(allowsResultRegistration: true);
    await _pump(tester, on, _Tutorial(seen: true));
    await _start(tester);
    await _crashWithoutScore(tester);
    await tester.pump();
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
