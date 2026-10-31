import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_drift/src/game/game_controller.dart';
import 'package:pulse_drift/src/game/game_painter.dart';
import 'package:pulse_drift/src/game/game_screen.dart';
import 'package:pulse_drift/src/game/how_to_play.dart';
import 'package:pulse_drift/src/persistence/best_score_store.dart';

class _GatedTutorial implements TutorialStore {
  final Completer<bool> _completer = Completer<bool>();

  void release(bool seen) => _completer.complete(seen);

  @override
  Future<bool> isSeen() => _completer.future;

  @override
  Future<void> markSeen() async {}
}

class _SeenTutorial implements TutorialStore {
  @override
  Future<bool> isSeen() async => true;

  @override
  Future<void> markSeen() async {}
}

class _MemoryBestScoreStore implements BestScoreStore {
  @override
  Future<int> loadBestScore() async => 0;

  @override
  Future<void> saveBestScore(int score) async {}
}

Future<GameController> _pump(WidgetTester tester, TutorialStore store) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: GameScreen(
        tutorialStore: store,
        bestScoreStore: _MemoryBestScoreStore(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
  final paint = tester.widget<CustomPaint>(
    find.byWidgetPredicate((w) => w is CustomPaint && w.painter is GamePainter),
  );
  return (paint.painter! as GamePainter).controller;
}

void main() {
  testWidgets('simulation and input wait for the stored tutorial flag', (
    tester,
  ) async {
    final gate = _GatedTutorial();
    final game = await _pump(tester, gate);

    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(game.gates, isEmpty);
    expect(game.score, 0);

    final lane = game.currentLane;
    await tester.tapAt(const Offset(10, 500));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(game.currentLane, lane);

    gate.release(true);
    await tester.pump();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(game.currentLane, isNot(lane));
  });

  testWidgets('Ctrl+arrow is left to the host', (tester) async {
    final game = await _pump(tester, _SeenTutorial());
    final lane = game.currentLane;

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pump();
    expect(game.currentLane, lane);
  });

  testWidgets('a held restart key repeating after a crash does not restart', (
    tester,
  ) async {
    final game = await _pump(tester, _SeenTutorial());

    // The key is already held down when the run crashes.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    for (var i = 0; i < 2400 && !game.isGameOver; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(game.isGameOver, isTrue);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(game.isGameOver, isTrue);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
  });

  testWidgets('Tab cannot move focus out of the open overlay', (tester) async {
    final game = await _pump(tester, _SeenTutorial());
    await tester.tap(find.byTooltip('How to play'));
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('How to play'), findsNothing);

    // The game takes keyboard input again after closing.
    final lane = game.currentLane;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(game.currentLane, isNot(lane));
  });
}
