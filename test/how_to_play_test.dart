import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_drift/src/game/game_controller.dart';
import 'package:pulse_drift/src/game/game_painter.dart';
import 'package:pulse_drift/src/game/game_screen.dart';
import 'package:pulse_drift/src/game/how_to_play.dart';
import 'package:pulse_drift/src/persistence/best_score_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeTutorialStore implements TutorialStore {
  _FakeTutorialStore({this.seen = false});

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
  _FakeTutorialStore store, {
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
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
}

GameController _controller(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.byWidgetPredicate((w) => w is CustomPaint && w.painter is GamePainter),
  );
  return (paint.painter! as GamePainter).controller;
}

Future<void> _runFor(WidgetTester tester, Duration total) async {
  var elapsed = Duration.zero;
  const step = Duration(milliseconds: 50);
  while (elapsed < total) {
    await tester.pump(step);
    elapsed += step;
  }
}

void main() {
  testWidgets('first launch shows the tutorial and blocks game input', (
    tester,
  ) async {
    await _pump(tester, _FakeTutorialStore());
    expect(find.text('How to play'), findsOneWidget);
    final game = _controller(tester);
    expect(game.currentLane, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(game.currentLane, 1);

    await tester.tapAt(const Offset(20, 400));
    await tester.dragFrom(const Offset(300, 400), const Offset(-250, 0));
    await tester.pump();
    expect(game.currentLane, 1);
    expect(find.text('How to play'), findsOneWidget);
  });

  testWidgets('Next walks the steps and Play closes and stores the flag', (
    tester,
  ) async {
    final store = _FakeTutorialStore();
    await _pump(tester, store);

    for (var i = 0; i < howToPlaySteps.length - 1; i++) {
      expect(find.text(howToPlaySteps[i].text), findsOneWidget);
      expect(find.text('Play'), findsNothing);
      await tester.tap(find.text('Next'));
      await tester.pump();
    }
    expect(find.text(howToPlaySteps.last.text), findsOneWidget);
    expect(find.text('Next'), findsNothing);

    await tester.tap(find.text('Play'));
    await tester.pump();
    expect(find.text('How to play'), findsNothing);
    expect(store.seen, isTrue);
  });

  testWidgets('Skip closes and stores the flag', (tester) async {
    final store = _FakeTutorialStore();
    await _pump(tester, store);
    await tester.tap(find.text('Skip'));
    await tester.pump();
    expect(find.text('How to play'), findsNothing);
    expect(store.seen, isTrue);
  });

  testWidgets('keyboard navigates, Escape skips, game keys work afterwards', (
    tester,
  ) async {
    final store = _FakeTutorialStore();
    await _pump(tester, store);
    final game = _controller(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(find.text(howToPlaySteps[1].text), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(find.text(howToPlaySteps[0].text), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text(howToPlaySteps[1].text), findsOneWidget);
    expect(game.currentLane, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('How to play'), findsNothing);
    expect(store.seen, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(game.currentLane, 0);
  });

  testWidgets('tutorial does not appear when already seen', (tester) async {
    await _pump(tester, _FakeTutorialStore(seen: true));
    expect(find.text('How to play'), findsNothing);
  });

  testWidgets('? reopens at step 1 without resetting the run', (tester) async {
    await _pump(tester, _FakeTutorialStore(seen: true));
    final game = _controller(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(game.currentLane, 2);

    await tester.tap(find.byTooltip('How to play'));
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.tap(find.text('Skip'));
    await tester.pump();

    await tester.tap(find.byTooltip('How to play'));
    await tester.pump();
    expect(find.text(howToPlaySteps[0].text), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pump();
    expect(game.currentLane, 2);
  });

  testWidgets('simulation does not advance while the tutorial is open', (
    tester,
  ) async {
    await _pump(tester, _FakeTutorialStore());
    final game = _controller(tester);

    await _runFor(tester, const Duration(seconds: 4));
    expect(game.gates, isEmpty);
    expect(game.isGameOver, isFalse);

    await tester.tap(find.text('Skip'));
    await tester.pump();
    // Closing must not apply the 4 s spent reading as one huge time step.
    await tester.pump(const Duration(milliseconds: 16));
    expect(game.gates, isEmpty);

    await _runFor(tester, const Duration(milliseconds: 1600));
    expect(game.gates, isNotEmpty);

    final gatesBefore = game.gates.first.yPosition;
    await tester.tap(find.byTooltip('How to play'));
    await tester.pump();
    await _runFor(tester, const Duration(seconds: 2));
    expect(game.gates.first.yPosition, gatesBefore);
  });

  for (final size in const [
    Size(390, 844),
    Size(844, 390),
    Size(1280, 720),
    Size(320, 480),
  ]) {
    testWidgets('tutorial and ? button fit without overflow at $size', (
      tester,
    ) async {
      await _pump(tester, _FakeTutorialStore(), size: size);
      expect(tester.takeException(), isNull);
      for (var i = 0; i < howToPlaySteps.length - 1; i++) {
        await tester.tap(find.text('Next'));
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
      await tester.tap(find.text('Play'));
      await tester.pump();
      final help = find.byTooltip('How to play');
      expect(help, findsOneWidget);
      expect((Offset.zero & size).contains(tester.getCenter(help)), isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  test('SharedPrefsTutorialStore persists the flag', () async {
    SharedPreferences.setMockInitialValues({});
    const store = SharedPrefsTutorialStore();
    expect(await store.isSeen(), isFalse);
    await store.markSeen();
    expect(await store.isSeen(), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('tutorial_seen_v1'), isTrue);
  });
}
