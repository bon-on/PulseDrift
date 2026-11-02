import 'drift_theme.dart';

/// Facts about one finished run, fed to [DriftProgress.applyRun].
class RunSummary {
  const RunSummary({
    required this.score,
    required this.seconds,
    this.missionXp = 0,
  });

  final int score;

  /// Seconds survived.
  final double seconds;

  /// XP already earned from missions completed during the run.
  final int missionXp;
}

/// Result of applying a run to the saved progress.
class RunOutcome {
  const RunOutcome({
    required this.progress,
    required this.xpGained,
    required this.levelBefore,
    required this.levelAfter,
    required this.isNewBestTime,
    required this.previousBestSeconds,
    required this.newlyUnlockedThemes,
  });

  final DriftProgress progress;
  final int xpGained;
  final int levelBefore;
  final int levelAfter;
  final bool isNewBestTime;
  final double previousBestSeconds;
  final List<DriftTheme> newlyUnlockedThemes;

  bool get leveledUp => levelAfter > levelBefore;
}

/// Saved meta progress: pilot XP, longest run and the chosen theme.
/// The best score keeps its own legacy key (`BestScoreStore`).
///
/// Tuning: a gate is worth 10 x multiplier (1.0 rising by 0.12 per dodge),
/// so a 15 s beginner run scores about 100 and a 40 s run 600 to 900.
/// XP per run = score / 10 + mission XP (20 to 35 each) + 10 for surviving
/// at least [participationSeconds]. Beginners earn about 30 to 60 XP, steady
/// players 100 to 180. Reaching level L+1 costs 100 + 50 x (L - 1), so Sunset
/// (Lv3, 250 XP) takes about 3 to 5 runs, Aurora (Lv6, 1000 XP) about 10 and
/// Void (Lv10, 2700 XP) about 20 to 25.
class DriftProgress {
  const DriftProgress({
    required this.totalXp,
    required this.bestSeconds,
    required this.runs,
    required this.selectedTheme,
  });

  const DriftProgress.initial()
    : totalXp = 0,
      bestSeconds = 0,
      runs = 0,
      selectedTheme = DriftTheme.neon;

  static const int participationXp = 10;
  static const double participationSeconds = 5;

  final int totalXp;
  final double bestSeconds;
  final int runs;
  final DriftTheme selectedTheme;

  /// XP needed to go from [level] to the next one.
  static int xpToAdvance(int level) => 100 + 50 * (level < 1 ? 0 : level - 1);

  /// XP awarded for a run's score.
  static int xpForScore(int score) => score <= 0 ? 0 : score ~/ 10;

  int get level => _split().$1;
  int get xpIntoLevel => _split().$2;
  int get xpForNextLevel => xpToAdvance(level);

  (int, int) _split() {
    var level = 1;
    var left = totalXp < 0 ? 0 : totalXp;
    while (left >= xpToAdvance(level)) {
      left -= xpToAdvance(level);
      level += 1;
    }
    return (level, left);
  }

  bool isThemeUnlocked(DriftTheme theme) => level >= theme.requiredLevel;

  /// Returns this progress unchanged when [theme] is still locked.
  DriftProgress withTheme(DriftTheme theme) {
    if (!isThemeUnlocked(theme)) return this;
    return _copy(selectedTheme: theme);
  }

  /// Adds [xp] (e.g. a run that ended before the stored value had loaded).
  DriftProgress withXp(int xp, {double seconds = 0, int runs = 0}) => _copy(
    totalXp: totalXp + (xp < 0 ? 0 : xp),
    bestSeconds: seconds > bestSeconds ? seconds : bestSeconds,
    runs: this.runs + runs,
  );

  static int xpForRun(RunSummary summary) {
    if (summary.score <= 0 && summary.seconds < 1) return 0;
    return xpForScore(summary.score) +
        (summary.missionXp < 0 ? 0 : summary.missionXp) +
        (summary.seconds >= participationSeconds ? participationXp : 0);
  }

  RunOutcome applyRun(RunSummary summary) {
    final levelBefore = level;
    final xp = xpForRun(summary);
    final seconds = summary.seconds.isFinite && summary.seconds > 0
        ? summary.seconds
        : 0.0;
    final next = withXp(xp, seconds: seconds, runs: 1);
    final levelAfter = next.level;
    return RunOutcome(
      progress: next,
      xpGained: xp,
      levelBefore: levelBefore,
      levelAfter: levelAfter,
      isNewBestTime: seconds > bestSeconds && bestSeconds > 0,
      previousBestSeconds: bestSeconds,
      newlyUnlockedThemes: [
        for (final theme in DriftTheme.values)
          if (levelBefore < theme.requiredLevel &&
              levelAfter >= theme.requiredLevel)
            theme,
      ],
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'totalXp': totalXp,
    'bestSeconds': bestSeconds,
    'runs': runs,
    'selectedTheme': selectedTheme.name,
  };

  /// Tolerant parser: any missing or invalid field falls back on its own.
  factory DriftProgress.fromJson(Object? json) {
    if (json is! Map) return const DriftProgress.initial();
    num readNum(Object? value) =>
        value is num && value.isFinite && value >= 0 ? value : 0;
    final progress = DriftProgress(
      totalXp: readNum(json['totalXp']).toInt(),
      bestSeconds: readNum(json['bestSeconds']).toDouble(),
      runs: readNum(json['runs']).toInt(),
      selectedTheme: DriftTheme.neon,
    );
    final name = json['selectedTheme'];
    return progress.withTheme(
      DriftTheme.fromName(name is String ? name : null),
    );
  }

  DriftProgress _copy({
    int? totalXp,
    double? bestSeconds,
    int? runs,
    DriftTheme? selectedTheme,
  }) {
    return DriftProgress(
      totalXp: totalXp ?? this.totalXp,
      bestSeconds: bestSeconds ?? this.bestSeconds,
      runs: runs ?? this.runs,
      selectedTheme: selectedTheme ?? this.selectedTheme,
    );
  }
}
