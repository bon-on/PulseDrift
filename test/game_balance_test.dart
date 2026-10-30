import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_drift/src/game/game_balance.dart';
import 'package:pulse_drift/src/game/game_input.dart';

void main() {
  test('speed ramps early, then plateaus at the cap', () {
    expect(GameBalance.speedFor(0), 280);
    expect(GameBalance.speedFor(8), greaterThan(GameBalance.speedFor(0)));
    expect(GameBalance.speedFor(17), greaterThan(595));
    expect(GameBalance.speedFor(18), GameBalance.maxSpeed);
    expect(GameBalance.speedFor(500), GameBalance.maxSpeed);
    for (var n = 0; n < 100; n++) {
      expect(
        GameBalance.speedFor(n + 1),
        greaterThanOrEqualTo(GameBalance.speedFor(n)),
      );
      expect(GameBalance.speedFor(n), lessThanOrEqualTo(GameBalance.maxSpeed));
    }
  });

  test('gate spawn delay stops at its floor', () {
    expect(GameBalance.gateSpawnDelayFor(0), closeTo(1.32, 1e-9));
    expect(GameBalance.gateSpawnDelayFor(40), 0.62);
  });

  test('pattern variety escalates and caps', () {
    expect(GameBalance.doubleChanceFor(3), 0);
    expect(GameBalance.baitChanceFor(7), 0);
    expect(GameBalance.doubleChanceFor(4), closeTo(0.10, 1e-9));
    expect(GameBalance.doubleChanceFor(100), 0.30);
    expect(GameBalance.baitChanceFor(8), closeTo(0.08, 1e-9));
    expect(GameBalance.baitChanceFor(100), 0.20);
    expect(GameBalance.patternFor(0, 0.0), GatePattern.single);
    expect(GameBalance.patternFor(20, 0.0), GatePattern.bait);
    expect(GameBalance.patternFor(20, 0.25), GatePattern.doubleGate);
    expect(GameBalance.patternFor(20, 0.99), GatePattern.single);
  });

  test('bait layout puts the spark in an open lane away from the exit', () {
    for (var exit = 0; exit < GameBalance.laneCount; exit++) {
      for (final roll in [0.0, 0.7]) {
        final layout = GameBalance.baitLayoutFor(exit, roll);
        expect(layout.wallLane, isNot(exit));
        expect(layout.sparkLane, isNot(layout.wallLane));
        expect(layout.sparkLane, isNot(exit));
      }
    }
    expect(GameBalance.baitLayoutFor(0, 0).sparkLane, 2);
    expect(GameBalance.baitLayoutFor(2, 0).sparkLane, 0);
  });

  test('lane snapping picks the nearest lane', () {
    expect(GameGeometry.nearestLaneIndex(xPosition: 20, width: 300), 0);
    expect(GameGeometry.nearestLaneIndex(xPosition: 150, width: 300), 1);
    expect(GameGeometry.nearestLaneIndex(xPosition: 280, width: 300), 2);
  });

  test('keyboard maps Left/A and Right/D to lane shifts', () {
    expect(laneDeltaForKey(LogicalKeyboardKey.arrowLeft), -1);
    expect(laneDeltaForKey(LogicalKeyboardKey.keyA), -1);
    expect(laneDeltaForKey(LogicalKeyboardKey.arrowRight), 1);
    expect(laneDeltaForKey(LogicalKeyboardKey.keyD), 1);
    expect(laneDeltaForKey(LogicalKeyboardKey.keyW), isNull);
    expect(isRestartKey(LogicalKeyboardKey.space), isTrue);
  });

  test('tapping the left or right half shifts one lane', () {
    expect(laneDeltaForTap(x: 40, width: 300), -1);
    expect(laneDeltaForTap(x: 260, width: 300), 1);
  });
}
