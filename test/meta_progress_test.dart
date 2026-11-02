import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_drift/src/meta/drift_progress.dart';
import 'package:pulse_drift/src/meta/drift_theme.dart';
import 'package:pulse_drift/src/meta/missions.dart';
import 'package:pulse_drift/src/meta/progress_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

int _xpForLevel(int level) {
  var xp = 0;
  for (var l = 1; l < level; l++) {
    xp += DriftProgress.xpToAdvance(l);
  }
  return xp;
}

DriftProgress _atXp(int xp) => DriftProgress(
  totalXp: xp,
  bestSeconds: 0,
  runs: 0,
  selectedTheme: DriftTheme.neon,
);

void main() {
  group('DriftProgress', () {
    test('level curve and xp split', () {
      expect(_atXp(0).level, 1);
      expect(_atXp(99).level, 1);
      expect(_atXp(100).level, 2);
      expect(_atXp(100).xpIntoLevel, 0);
      expect(_atXp(100).xpForNextLevel, 150);
      expect(_atXp(_xpForLevel(3)).level, 3);
      expect(_xpForLevel(3), 250);
      expect(_xpForLevel(6), 1000);
      expect(_xpForLevel(10), 2700);
    });

    test('run xp = score/10 + missions + participation', () {
      expect(
        DriftProgress.xpForRun(
          const RunSummary(score: 437, seconds: 20, missionXp: 55),
        ),
        43 + 55 + 10,
      );
      // Short runs skip the participation bonus.
      expect(
        DriftProgress.xpForRun(const RunSummary(score: 30, seconds: 3)),
        3,
      );
      expect(
        DriftProgress.xpForRun(const RunSummary(score: 0, seconds: 0.4)),
        0,
      );
    });

    test('applyRun reports level ups, unlocks and best time', () {
      final start = _atXp(_xpForLevel(3) - 5);
      final outcome = start.applyRun(
        const RunSummary(score: 200, seconds: 30, missionXp: 25),
      );
      expect(outcome.xpGained, 20 + 25 + 10);
      expect(outcome.levelBefore, 2);
      expect(outcome.levelAfter, 3);
      expect(outcome.leveledUp, isTrue);
      expect(outcome.newlyUnlockedThemes, [DriftTheme.sunset]);
      expect(outcome.progress.bestSeconds, 30);
      expect(outcome.progress.runs, 1);
      // First timed run is not announced as a new best time.
      expect(outcome.isNewBestTime, isFalse);
      final second = outcome.progress.applyRun(
        const RunSummary(score: 10, seconds: 31),
      );
      expect(second.isNewBestTime, isTrue);
      expect(second.previousBestSeconds, 30);
    });

    test('locked themes cannot be selected', () {
      expect(
        _atXp(0).withTheme(DriftTheme.aurora).selectedTheme,
        DriftTheme.neon,
      );
      expect(
        _atXp(_xpForLevel(6)).withTheme(DriftTheme.aurora).selectedTheme,
        DriftTheme.aurora,
      );
      expect(
        _atXp(_xpForLevel(9)).isThemeUnlocked(DriftTheme.voidline),
        isFalse,
      );
      expect(
        _atXp(_xpForLevel(10)).isThemeUnlocked(DriftTheme.voidline),
        isTrue,
      );
    });

    test('json round trip', () {
      final progress = _atXp(
        _xpForLevel(6) + 3,
      ).withTheme(DriftTheme.aurora).withXp(0, seconds: 41.5, runs: 7);
      final back = DriftProgress.fromJson(
        jsonDecode(jsonEncode(progress.toJson())),
      );
      expect(back.totalXp, progress.totalXp);
      expect(back.bestSeconds, 41.5);
      expect(back.runs, 7);
      expect(back.selectedTheme, DriftTheme.aurora);
    });

    test('corrupt json falls back field by field', () {
      expect(DriftProgress.fromJson('nope').totalXp, 0);
      expect(DriftProgress.fromJson(null).selectedTheme, DriftTheme.neon);
      final mixed = DriftProgress.fromJson({
        'totalXp': -40,
        'bestSeconds': 'x',
        'runs': 3,
        // Locked at level 1: falls back to Neon.
        'selectedTheme': 'voidline',
      });
      expect(mixed.totalXp, 0);
      expect(mixed.bestSeconds, 0);
      expect(mixed.runs, 3);
      expect(mixed.selectedTheme, DriftTheme.neon);
      expect(
        DriftProgress.fromJson({'selectedTheme': 'nonsense'}).selectedTheme,
        DriftTheme.neon,
      );
    });
  });

  group('ProgressStore', () {
    test('persists under pulse_drift_progress_v1', () async {
      SharedPreferences.setMockInitialValues({});
      const store = ProgressStore();
      expect((await store.load()).totalXp, 0);
      await store.save(_atXp(321));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('pulse_drift_progress_v1'), contains('321'));
      expect((await store.load()).totalXp, 321);
    });

    test('corrupt stored value loads the initial progress', () async {
      SharedPreferences.setMockInitialValues({
        'pulse_drift_progress_v1': '{not json',
      });
      final progress = await const ProgressStore().load();
      expect(progress.totalXp, 0);
      expect(progress.selectedTheme, DriftTheme.neon);
    });

    test('wrong stored type loads the initial progress', () async {
      SharedPreferences.setMockInitialValues({'pulse_drift_progress_v1': 12});
      expect((await const ProgressStore().load()).totalXp, 0);
    });
  });

  group('Missions', () {
    test('three distinct missions scaled by level', () {
      for (var seed = 0; seed < 40; seed++) {
        final low = MissionSet.forLevel(1, Random(seed));
        expect(low.missions.length, 3);
        expect(low.missions.map((m) => m.kind).toSet().length, 3);
        expect(low.missions.any((m) => m.kind == MissionKind.sparks), isFalse);
        for (final m in low.missions) {
          expect(m.target, m.kind.targets.first);
        }
        final high = MissionSet.forLevel(40, Random(seed));
        for (final m in high.missions) {
          expect(m.target, m.kind.targets.last);
        }
      }
    });

    test('progress, completion once, and xp', () {
      final set = MissionSet(const [
        Mission(MissionKind.survive, 15),
        Mission(MissionKind.multiplier, 20),
        Mission(MissionKind.nearMiss, 2),
      ]);
      expect(set.update(const RunStats(seconds: 14.9)), isEmpty);
      expect(set.missions[0].progressFor(const RunStats(seconds: 14.9)), 14);
      final done = set.update(
        const RunStats(seconds: 15, multiplier: 2.0, nearMisses: 1),
      );
      expect(done.map((m) => m.kind), [
        MissionKind.survive,
        MissionKind.multiplier,
      ]);
      expect(set.isDone(0), isTrue);
      expect(set.isDone(2), isFalse);
      expect(set.update(const RunStats(seconds: 30, multiplier: 3)), isEmpty);
      expect(set.xpEarned, MissionKind.survive.xp + MissionKind.multiplier.xp);
      expect(
        set.update(const RunStats(nearMisses: 2)).single.kind,
        MissionKind.nearMiss,
      );
      expect(set.completedCount, 3);
    });

    test('multiplier progress is not lost to float rounding', () {
      // 1 + 9 * 0.12 = 2.08; 1 + 0.12 * 25 / 3 style values round down.
      const m = Mission(MissionKind.multiplier, 20);
      expect(m.progressFor(const RunStats(multiplier: 1.0 + 0.12 * 9)), 20);
      expect(m.progressFor(const RunStats(multiplier: 1.96)), 19);
      expect(m.label, 'Reach x2.0');
    });

    test('every mission has an ASCII label', () {
      for (final kind in MissionKind.values) {
        for (final target in {1, ...kind.targets}) {
          final label = Mission(kind, target).label;
          expect(label.codeUnits.every((c) => c < 128), isTrue, reason: label);
        }
      }
    });
  });
}
