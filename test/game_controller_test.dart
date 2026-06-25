import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
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
          controller.laneCenters[controller.gates.first.blockedLane];
      controller.handlePointerX(safeLane);
      controller.update(0.12);
      if (controller.score > 0 || controller.isGameOver) {
        break;
      }
    }

    expect(controller.score, greaterThan(0));
    expect(store.current, controller.bestScore);
  });
}
