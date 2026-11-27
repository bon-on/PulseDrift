import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_drift/src/art/drift_palette.dart';
import 'package:pulse_drift/src/game/how_to_play.dart';
import 'package:pulse_drift/src/game/ui/overlays.dart';
import 'package:pulse_drift/src/meta/drift_progress.dart';
import 'package:pulse_drift/src/meta/drift_theme.dart';
import 'package:pulse_drift/src/meta/missions.dart';

/// Short phone windows (browser bars, landscape) where a card can be taller
/// than the screen. The way out of every card must stay on screen without
/// scrolling.
const _sizes = [Size(360, 560), Size(320, 480), Size(640, 300)];

Future<void> _pump(WidgetTester tester, Size size, Widget overlay) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SizedBox.expand(child: overlay)),
    ),
  );
  await tester.pumpAndSettle();
}

void _expectOnScreen(WidgetTester tester, Finder finder, Size size) {
  expect(finder, findsOneWidget);
  final rect = tester.getRect(finder);
  expect(rect.top, greaterThanOrEqualTo(0), reason: '$finder at $size');
  expect(rect.bottom, lessThanOrEqualTo(size.height), reason: '$finder');
  expect(rect.left, greaterThanOrEqualTo(0), reason: '$finder');
  expect(rect.right, lessThanOrEqualTo(size.width), reason: '$finder');
}

RunReport _report() {
  const before = DriftProgress.initial();
  return RunReport(
    score: 1234,
    bestScore: 1234,
    isNewBest: true,
    seconds: 42,
    nearMisses: 3,
    peakMultiplier: 2.5,
    sparks: 4,
    missions: [for (final kind in MissionKind.values.take(3)) Mission(kind, 1)],
    missionsDone: const [true, false, true],
    outcome: RunOutcome(
      progress: before,
      xpGained: 120,
      levelBefore: 1,
      levelAfter: 2,
      isNewBestTime: true,
      previousBestSeconds: 10,
      newlyUnlockedThemes: [DriftTheme.values.last],
    ),
    progressBefore: before,
  );
}

void main() {
  for (final size in _sizes) {
    testWidgets('the run summary keeps its buttons on screen at $size', (
      tester,
    ) async {
      var menu = 0;
      await _pump(
        tester,
        size,
        RunSummaryOverlay(
          report: _report(),
          palette: DriftPalette.neon,
          onPlayAgain: () {},
          onMenu: () => menu++,
        ),
      );
      expect(tester.takeException(), isNull);
      _expectOnScreen(tester, find.text('Play again'), size);
      _expectOnScreen(tester, find.text('Menu'), size);
      await tester.tap(find.text('Menu'));
      expect(menu, 1);
    });

    testWidgets('the theme picker keeps Done on screen at $size', (
      tester,
    ) async {
      var closed = 0;
      await _pump(
        tester,
        size,
        ThemePickerOverlay(
          progress: const DriftProgress.initial(),
          palette: DriftPalette.neon,
          onSelect: (_) {},
          onClose: () => closed++,
        ),
      );
      expect(tester.takeException(), isNull);
      _expectOnScreen(tester, find.text('Done'), size);
      await tester.tap(find.text('Done'));
      expect(closed, 1);
    });

    testWidgets('How to play keeps Skip and Next on screen at $size', (
      tester,
    ) async {
      var closed = 0;
      await _pump(tester, size, HowToPlayOverlay(onClose: () => closed++));
      expect(tester.takeException(), isNull);
      _expectOnScreen(tester, find.text('Skip'), size);
      _expectOnScreen(tester, find.text('Next'), size);
      await tester.tap(find.text('Skip'));
      expect(closed, 1);
    });
  }
}
