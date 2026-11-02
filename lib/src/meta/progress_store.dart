import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'drift_progress.dart';

/// Persists [DriftProgress] as a JSON string under [progressKey].
///
/// Storage failures never break play: a read failure or corrupt value loads
/// the initial progress and a write failure is ignored. Tests use
/// [MemoryProgressStore].
class ProgressStore {
  const ProgressStore();

  static const String progressKey = 'pulse_drift_progress_v1';

  Future<DriftProgress> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(progressKey);
      if (raw == null) return const DriftProgress.initial();
      return DriftProgress.fromJson(jsonDecode(raw));
    } catch (_) {
      return const DriftProgress.initial();
    }
  }

  Future<void> save(DriftProgress progress) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(progressKey, jsonEncode(progress.toJson()));
    } catch (_) {
      return;
    }
  }
}

/// In-memory store for tests.
class MemoryProgressStore extends ProgressStore {
  MemoryProgressStore([this.value = const DriftProgress.initial()]);

  DriftProgress value;
  int saveCount = 0;

  @override
  Future<DriftProgress> load() async => value;

  @override
  Future<void> save(DriftProgress progress) async {
    value = progress;
    saveCount += 1;
  }
}
