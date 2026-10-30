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

  /// Fall speed plateaus here so late runs stay readable; difficulty then
  /// grows through pattern variety instead of raw speed.
  static const double maxSpeed = 600;
  static const double nearMissBonus = 15;
  static const double nearMissWindowSeconds = 0.18;

  /// Seconds between the two gates of a double pattern.
  static const double doubleGateGapSeconds = 0.65;

  /// Seconds between a two-open-lane bait gate and the single-gap gate behind it.
  static const double baitGateGapSeconds = 0.75;

  static double speedFor(int cleanDodges) {
    final earlyRamp = (1.0 - math.pow(0.88, cleanDodges)) * 360;
    return math.min(baseSpeed + earlyRamp, maxSpeed);
  }

  static double gateSpawnDelayFor(int cleanDodges) {
    final rawValue = 1.32 - (cleanDodges * 0.025);
    return math.max(rawValue, 0.62);
  }

  /// Chance (0..1) that the next gate spawns as a quick double gate.
  static double doubleChanceFor(int cleanDodges) {
    if (cleanDodges < 4) return 0;
    return math.min(0.10 + (cleanDodges - 4) * 0.02, 0.30);
  }

  /// Chance (0..1) that the next gate spawns as a spark bait pair.
  static double baitChanceFor(int cleanDodges) {
    if (cleanDodges < 8) return 0;
    return math.min(0.08 + (cleanDodges - 8) * 0.01, 0.20);
  }

  /// Picks the next pattern from a uniform [roll] in [0, 1).
  static GatePattern patternFor(int cleanDodges, double roll) {
    final bait = baitChanceFor(cleanDodges);
    final doubleChance = doubleChanceFor(cleanDodges);
    if (roll < bait) return GatePattern.bait;
    if (roll < bait + doubleChance) return GatePattern.doubleGate;
    return GatePattern.single;
  }

  /// Layout of a bait pair whose second gate is open only in [exitLane].
  /// The first gate walls off [BaitLayout.wallLane] and the spark sits in the
  /// open lane farthest from the exit, so grabbing it costs a lane change.
  /// [roll] only matters for the middle exit lane, where both sides are equal.
  static BaitLayout baitLayoutFor(int exitLane, double roll) {
    if (exitLane != 1) {
      return BaitLayout(wallLane: 1, sparkLane: laneCount - 1 - exitLane);
    }
    final sparkLane = roll < 0.5 ? 0 : laneCount - 1;
    return BaitLayout(
      wallLane: laneCount - 1 - sparkLane,
      sparkLane: sparkLane,
    );
  }
}

enum GatePattern { single, doubleGate, bait }

class BaitLayout {
  const BaitLayout({required this.wallLane, required this.sparkLane});

  final int wallLane;
  final int sparkLane;
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
