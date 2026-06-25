import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_drift/src/game/game_balance.dart';

void main() {
  test('speed starts slow and keeps ramping past the old cap', () {
    expect(GameBalance.speedFor(0), 280);
    expect(GameBalance.speedFor(8), greaterThan(GameBalance.speedFor(0)));
    expect(GameBalance.speedFor(20), greaterThan(820));
    expect(GameBalance.speedFor(40), greaterThan(GameBalance.speedFor(20)));
  });

  test('spawn delays stop at their floors', () {
    expect(GameBalance.gateSpawnDelayFor(40), 0.48);
    expect(GameBalance.sparkSpawnDelayFor(80), 1.9);
  });

  test('lane snapping picks the nearest lane', () {
    expect(GameGeometry.nearestLaneIndex(xPosition: 20, width: 300), 0);
    expect(GameGeometry.nearestLaneIndex(xPosition: 150, width: 300), 1);
    expect(GameGeometry.nearestLaneIndex(xPosition: 280, width: 300), 2);
  });
}
