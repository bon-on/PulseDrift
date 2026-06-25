import 'package:shared_preferences/shared_preferences.dart';

abstract class BestScoreStore {
  Future<int> loadBestScore();

  Future<void> saveBestScore(int score);
}

class SharedPrefsBestScoreStore implements BestScoreStore {
  static const _bestScoreKey = 'pulse_drift.best_score';

  @override
  Future<int> loadBestScore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_bestScoreKey) ?? 0;
  }

  @override
  Future<void> saveBestScore(int score) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_bestScoreKey, score);
  }
}
