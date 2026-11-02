import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_drift/src/game/game_balance.dart';
import 'package:pulse_drift/src/game/game_controller.dart';
import 'package:pulse_drift/src/persistence/best_score_store.dart';

class InMemoryBestScoreStore implements BestScoreStore {
  InMemoryBestScoreStore({this.current = 0});

  int current;

  @override
  Future<int> loadBestScore() async => current;

  @override
  Future<void> saveBestScore(int score) async {
    current = score;
  }
}

void main() {
  test('loads the saved best score during initialization', () async {
    final store = InMemoryBestScoreStore(current: 42);
    final controller = GameController(bestScoreStore: store);

    await controller.initialize();

    expect(controller.bestScore, 42);
  });

  test('tap or drag x position snaps to the nearest lane', () async {
    final controller = GameController(bestScoreStore: InMemoryBestScoreStore());
    controller.setViewportSize(const Size(300, 600));

    controller.handlePointerX(10);
    expect(controller.currentLane, 0);

    controller.handlePointerX(160);
    expect(controller.currentLane, 1);

    controller.handlePointerX(280);
    expect(controller.currentLane, 2);
  });

  test('player anchor sits near the lower playfield', () {
    final controller = GameController(bestScoreStore: InMemoryBestScoreStore());

    controller.setViewportSize(const Size(300, 600));

    expect(controller.playerY, 480);
  });

  test('best score persists after successful dodges', () async {
    final store = InMemoryBestScoreStore();
    final controller = GameController(bestScoreStore: store);
    controller.setViewportSize(const Size(300, 600));

    controller.update(1.4);

    for (var index = 0; index < 8; index++) {
      final safeLane =
          controller.laneCenters[controller.gates.first.openLanes.first];
      controller.handlePointerX(safeLane);
      controller.update(0.12);
      if (controller.score > 0 || controller.isGameOver) {
        break;
      }
    }

    expect(controller.score, greaterThan(0));
    expect(store.current, controller.bestScore);
  });

  test('shiftLane moves one lane and clamps at the edges', () {
    final controller = GameController(bestScoreStore: InMemoryBestScoreStore());
    controller.setViewportSize(const Size(300, 600));

    controller.shiftLane(-1);
    expect(controller.currentLane, 0);
    controller.shiftLane(-1);
    expect(controller.currentLane, 0);
    controller.shiftLane(1);
    controller.shiftLane(1);
    controller.shiftLane(1);
    expect(controller.currentLane, 2);
  });

  GameController spawnFirstGate({int dodges = 0}) {
    final controller = GameController(
      bestScoreStore: InMemoryBestScoreStore(),
      random: math.Random(3),
    );
    controller.setViewportSize(const Size(300, 600));
    controller.debugSetCleanDodges(dodges);
    controller.update(GameBalance.gateSpawnDelayFor(dodges) + 0.01);
    return controller;
  }

  test('a late lane switch into the open lane earns the near-miss bonus', () {
    final controller = spawnFirstGate();
    final gate = controller.gates.first;
    final wrongLane = [0, 1, 2].firstWhere((l) => !gate.openLanes.contains(l));
    controller.shiftLane(wrongLane - controller.currentLane);
    final openLane = gate.openLanes.first;
    var switched = false;
    for (var i = 0; i < 400 && !controller.isGameOver; i++) {
      if (!switched && gate.yPosition >= 480 - 34 - controller.speed * 0.1) {
        controller.shiftLane(openLane - controller.currentLane);
        switched = true;
      }
      controller.update(0.01);
      if (gate.scored) break;
    }
    expect(controller.isGameOver, isFalse);
    expect(controller.nearMisses, 1);
    expect(controller.score, greaterThan(GameBalance.nearMissBonus));
  });

  test('switching early is not a near miss', () {
    final controller = spawnFirstGate();
    final gate = controller.gates.first;
    final wrongLane = [0, 1, 2].firstWhere((l) => !gate.openLanes.contains(l));
    controller.shiftLane(wrongLane - controller.currentLane);
    controller.update(0.2);
    controller.shiftLane(gate.openLanes.first - controller.currentLane);
    for (var i = 0; i < 400 && !gate.scored; i++) {
      controller.update(0.01);
    }
    expect(controller.isGameOver, isFalse);
    expect(controller.nearMisses, 0);
  });

  test('late patterns spawn double gates and spark bait deterministically', () {
    var sawDouble = false;
    var sawBait = false;
    for (var seed = 0; seed < 40; seed++) {
      final controller = GameController(
        bestScoreStore: InMemoryBestScoreStore(),
        random: math.Random(seed),
      );
      controller.setViewportSize(const Size(300, 600));
      controller.debugSetCleanDodges(20);
      controller.update(GameBalance.gateSpawnDelayFor(20) + 0.01);
      final gates = controller.gates;
      if (gates.length == 2) {
        // Either a double gate (single gaps, different lanes) or a bait pair.
        if (controller.sparks.isEmpty) {
          sawDouble = true;
          expect(gates[1].openLanes.length, 1);
          expect(gates[0].openLanes.length, 1);
          expect(gates[1].openLanes.first, isNot(gates[0].openLanes.first));
        } else {
          sawBait = true;
          final spark = controller.sparks.single;
          expect(gates[0].openLanes.length, 2);
          expect(gates[0].openLanes, contains(spark.lane));
          expect(gates[1].openLanes.length, 1);
          expect(gates[1].openLanes, isNot(contains(spark.lane)));
        }
        expect(gates[1].yPosition, lessThan(gates[0].yPosition));
      } else {
        expect(gates.length, 1);
        expect(controller.sparks, isEmpty);
      }
    }
    expect(sawDouble, isTrue);
    expect(sawBait, isTrue);
  });

  test('near miss and spark pickups fire events and count', () {
    var nearMissEvents = 0;
    final sparkHits = <Offset>[];
    for (var seed = 0; seed < 60 && sparkHits.isEmpty; seed++) {
      final controller = GameController(
        bestScoreStore: InMemoryBestScoreStore(),
        random: math.Random(seed),
        onNearMiss: () => nearMissEvents++,
        onSparkCollected: sparkHits.add,
      );
      controller.setViewportSize(const Size(300, 600));
      controller.debugSetCleanDodges(20);
      controller.update(GameBalance.gateSpawnDelayFor(20) + 0.01);
      if (controller.sparks.isEmpty) continue;
      final spark = controller.sparks.single;
      controller.shiftLane(spark.lane - controller.currentLane);
      for (var i = 0; i < 300 && controller.sparks.isNotEmpty; i++) {
        controller.update(0.01);
      }
      expect(controller.sparksCollected, 1);
      expect(controller.runSeconds, greaterThan(0));
      controller.restart();
      expect(controller.sparksCollected, 0);
      expect(controller.runSeconds, 0);
    }
    expect(sparkHits, isNotEmpty);

    final controller = GameController(
      bestScoreStore: InMemoryBestScoreStore(),
      random: math.Random(3),
      onNearMiss: () => nearMissEvents++,
    );
    controller.setViewportSize(const Size(300, 600));
    controller.update(GameBalance.gateSpawnDelayFor(0) + 0.01);
    final gate = controller.gates.first;
    final wrongLane = [0, 1, 2].firstWhere((l) => !gate.openLanes.contains(l));
    controller.shiftLane(wrongLane - controller.currentLane);
    var switched = false;
    for (var i = 0; i < 400 && !gate.scored; i++) {
      if (!switched && gate.yPosition >= 480 - 34 - controller.speed * 0.1) {
        controller.shiftLane(gate.openLanes.first - controller.currentLane);
        switched = true;
        expect(controller.laneChangedAt, controller.runSeconds);
        expect(controller.previousLane, wrongLane);
      }
      controller.update(0.01);
    }
    expect(nearMissEvents, 1);
  });
}
