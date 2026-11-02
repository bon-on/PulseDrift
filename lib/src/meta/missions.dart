import 'dart:math';

/// What a run has achieved so far; missions read their progress from it.
class RunStats {
  const RunStats({
    this.seconds = 0,
    this.nearMisses = 0,
    this.multiplier = 1,
    this.sparks = 0,
    this.gates = 0,
    this.score = 0,
  });

  final double seconds;
  final int nearMisses;
  final double multiplier;
  final int sparks;
  final int gates;
  final int score;
}

enum MissionKind {
  survive(xp: 25, targets: [15, 20, 25, 30, 40, 50, 60]),
  nearMiss(xp: 35, targets: [1, 1, 2, 2, 3, 3, 4]),
  // Tenths: 20 means x2.0.
  multiplier(xp: 30, targets: [20, 20, 25, 25, 30, 30, 35]),
  sparks(xp: 30, targets: [1, 1, 1, 2, 2, 2, 3]),
  gates(xp: 20, targets: [10, 15, 20, 25, 30, 40, 50]),
  score(xp: 25, targets: [100, 150, 250, 350, 500, 650, 800]);

  const MissionKind({required this.xp, required this.targets});

  /// XP reward for completing a mission of this kind.
  final int xp;

  /// Target by difficulty tier (pilot level - 1, capped).
  final List<int> targets;
}

/// One in-run goal.
class Mission {
  const Mission(this.kind, this.target);

  final MissionKind kind;
  final int target;

  int get xp => kind.xp;

  String get label {
    switch (kind) {
      case MissionKind.survive:
        return 'Survive $target s';
      case MissionKind.nearMiss:
        return target == 1 ? 'Score a near miss' : 'Score $target near misses';
      case MissionKind.multiplier:
        return 'Reach x${(target / 10).toStringAsFixed(1)}';
      case MissionKind.sparks:
        return target == 1 ? 'Grab a spark' : 'Grab $target sparks';
      case MissionKind.gates:
        return 'Pass $target gates';
      case MissionKind.score:
        return 'Score $target';
    }
  }

  /// Progress toward [target], clamped to 0..target.
  int progressFor(RunStats stats) {
    final int value;
    switch (kind) {
      case MissionKind.survive:
        value = stats.seconds.floor();
      case MissionKind.nearMiss:
        value = stats.nearMisses;
      case MissionKind.multiplier:
        value = (stats.multiplier * 10 + 1e-6).floor();
      case MissionKind.sparks:
        value = stats.sparks;
      case MissionKind.gates:
        value = stats.gates;
      case MissionKind.score:
        value = stats.score;
    }
    return value.clamp(0, target);
  }
}

/// Three missions for one run. Targets grow with the pilot level; a
/// mission, once complete, stays complete for the rest of the run.
class MissionSet {
  MissionSet(this.missions);

  /// Three distinct missions for a pilot at [level].
  factory MissionSet.forLevel(int level, Random random) {
    final tier = (level - 1).clamp(0, 6);
    final pool = [
      for (final kind in MissionKind.values)
        // Sparks only appear after a few gates; keep them off the first set.
        if (tier > 0 || kind != MissionKind.sparks) kind,
    ]..shuffle(random);
    return MissionSet([
      for (final kind in pool.take(3)) Mission(kind, kind.targets[tier]),
    ]);
  }

  final List<Mission> missions;
  final Set<int> _done = <int>{};

  bool isDone(int index) => _done.contains(index);
  int get completedCount => _done.length;

  int get xpEarned =>
      [for (final i in _done) missions[i].xp].fold(0, (a, b) => a + b);

  /// Marks missions that [stats] now satisfies; returns the newly completed.
  List<Mission> update(RunStats stats) {
    final fresh = <Mission>[];
    for (var i = 0; i < missions.length; i++) {
      if (_done.contains(i)) continue;
      final mission = missions[i];
      if (mission.progressFor(stats) >= mission.target) {
        _done.add(i);
        fresh.add(mission);
      }
    }
    return fresh;
  }
}
