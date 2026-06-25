import 'dart:math' as math;

class GameBalance {
  static const int laneCount = 3;
  static const int baseScorePerGate = 10;
  static const int sparkBonus = 25;
  static const double baseSpeed = 280;
  static const double playerRadius = 22;
  static const double playerAnchorHeightFactor = 0.8;
  static const double gateWidth = 78;
  static const double gateHeight = 24;
  static const double sparkRadius = 12;

  static double multiplierFor(int cleanDodges) {
    final rawValue = 1.0 + (cleanDodges * 0.12);
    return math.min(rawValue, 3.5);
  }

  static double speedFor(int cleanDodges) {
    final earlyRamp = (1.0 - math.pow(0.88, cleanDodges)) * 360;
    final endlessRamp = math.max(0, cleanDodges - 12) * 32.0;
    return baseSpeed + earlyRamp + endlessRamp;
  }

  static double gateSpawnDelayFor(int cleanDodges) {
    final rawValue = 1.32 - (cleanDodges * 0.025);
    return math.max(rawValue, 0.48);
  }

  static double sparkSpawnDelayFor(int cleanDodges) {
    final rawValue = 3.4 - (cleanDodges * 0.04);
    return math.max(rawValue, 1.9);
  }
}

class GameGeometry {
  static List<double> laneCentersForWidth(double width) {
    final spacing = width / (GameBalance.laneCount + 1);
    return List<double>.generate(
      GameBalance.laneCount,
      (index) => spacing * (index + 1),
    );
  }

  static int nearestLaneIndex({
    required double xPosition,
    required double width,
  }) {
    final laneCenters = laneCentersForWidth(width);
    var bestLane = 0;
    var bestDistance = double.infinity;

    for (var index = 0; index < laneCenters.length; index++) {
      final distance = (laneCenters[index] - xPosition).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        bestLane = index;
      }
    }

    return bestLane;
  }
}
