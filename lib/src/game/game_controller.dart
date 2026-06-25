import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../persistence/best_score_store.dart';
import 'game_balance.dart';
import 'game_models.dart';

class GameController extends ChangeNotifier {
  GameController({
    required BestScoreStore bestScoreStore,
    VoidCallback? onGateDodged,
    VoidCallback? onCrash,
    VoidCallback? onRestarted,
    math.Random? random,
  }) : _bestScoreStore = bestScoreStore,
       _onGateDodged = onGateDodged,
       _onCrash = onCrash,
       _onRestarted = onRestarted,
       _random = random ?? math.Random();

  final BestScoreStore _bestScoreStore;
  final VoidCallback? _onGateDodged;
  final VoidCallback? _onCrash;
  final VoidCallback? _onRestarted;
  final math.Random _random;

  final List<GateState> _gates = <GateState>[];
  final List<SparkState> _sparks = <SparkState>[];

  Size _viewportSize = Size.zero;
  double _playerVisualX = 0;
  int _currentLane = 1;
  int _cleanDodges = 0;
  int _score = 0;
  int _bestScore = 0;
  bool _isGameOver = false;
  bool _initialized = false;
  double _gateTimer = 0;
  double _sparkTimer = 0;

  List<GateState> get gates => List<GateState>.unmodifiable(_gates);
  List<SparkState> get sparks => List<SparkState>.unmodifiable(_sparks);
  int get currentLane => _currentLane;
  int get score => _score;
  int get bestScore => _bestScore;
  bool get isGameOver => _isGameOver;
  bool get isInitialized => _initialized;
  double get multiplier => GameBalance.multiplierFor(_cleanDodges);
  double get speed => GameBalance.speedFor(_cleanDodges);
  double get playerVisualX => _playerVisualX;
  double get playerY => _viewportSize.height == 0
      ? 0
      : _viewportSize.height * GameBalance.playerAnchorHeightFactor;
  List<double> get laneCenters =>
      GameGeometry.laneCentersForWidth(_viewportSize.width);

  Future<void> initialize() async {
    _bestScore = await _bestScoreStore.loadBestScore();
    _initialized = true;
    notifyListeners();
  }

  void setViewportSize(Size size) {
    if (_viewportSize == size || size.isEmpty) {
      return;
    }

    _viewportSize = size;
    _playerVisualX = laneCenters[_currentLane];
    notifyListeners();
  }

  void handlePointerX(double xPosition) {
    if (_isGameOver || _viewportSize.isEmpty) {
      return;
    }

    _currentLane = GameGeometry.nearestLaneIndex(
      xPosition: xPosition,
      width: _viewportSize.width,
    );
    notifyListeners();
  }

  void update(double deltaSeconds) {
    if (_viewportSize.isEmpty || deltaSeconds <= 0) {
      return;
    }

    _updatePlayerVisualPosition(deltaSeconds);

    if (_isGameOver) {
      notifyListeners();
      return;
    }

    _gateTimer += deltaSeconds;
    _sparkTimer += deltaSeconds;

    if (_gateTimer >= GameBalance.gateSpawnDelayFor(_cleanDodges)) {
      _gateTimer = 0;
      _spawnGate();
    }

    if (_sparkTimer >= GameBalance.sparkSpawnDelayFor(_cleanDodges)) {
      _sparkTimer = 0;
      _spawnSpark();
    }

    _moveWorld(deltaSeconds);
    _handleCollisionsAndScoring();
    _removeOffscreenEntities();
    notifyListeners();
  }

  void restart() {
    _gates.clear();
    _sparks.clear();
    _currentLane = 1;
    _cleanDodges = 0;
    _score = 0;
    _isGameOver = false;
    _gateTimer = 0;
    _sparkTimer = 0;
    _playerVisualX = _viewportSize.isEmpty ? 0 : laneCenters[_currentLane];
    _onRestarted?.call();
    notifyListeners();
  }

  void _updatePlayerVisualPosition(double deltaSeconds) {
    if (_viewportSize.isEmpty) {
      return;
    }

    final targetX = laneCenters[_currentLane];
    final lerpFactor = math.min(1.0, deltaSeconds * 14);
    _playerVisualX += (targetX - _playerVisualX) * lerpFactor;
  }

  void _moveWorld(double deltaSeconds) {
    final velocity = speed;
    for (final gate in _gates) {
      gate.yPosition += velocity * deltaSeconds;
    }
    for (final spark in _sparks) {
      spark.yPosition += (velocity * 0.82) * deltaSeconds;
    }
  }

  void _handleCollisionsAndScoring() {
    final playerCenterY = playerY;

    for (final gate in _gates) {
      final overlapsPlayer =
          (gate.yPosition - playerCenterY).abs() <=
          (GameBalance.playerRadius + (GameBalance.gateHeight / 2));

      if (overlapsPlayer && _currentLane != gate.blockedLane) {
        _isGameOver = true;
        _onCrash?.call();
        return;
      }

      if (!gate.scored &&
          gate.yPosition > playerCenterY + GameBalance.gateHeight) {
        gate.scored = true;
        _cleanDodges += 1;
        _score +=
            (GameBalance.baseScorePerGate *
                    GameBalance.multiplierFor(_cleanDodges))
                .round();
        _syncBestScore();
        _onGateDodged?.call();
      }
    }

    _sparks.removeWhere((spark) {
      final collides =
          spark.lane == _currentLane &&
          (spark.yPosition - playerCenterY).abs() <=
              (GameBalance.playerRadius + GameBalance.sparkRadius);

      if (collides) {
        _score += GameBalance.sparkBonus;
        _syncBestScore();
      }

      return collides;
    });
  }

  void _removeOffscreenEntities() {
    final cutoff = _viewportSize.height + 120;
    _gates.removeWhere((gate) => gate.yPosition > cutoff);
    _sparks.removeWhere((spark) => spark.yPosition > cutoff);
  }

  void _spawnGate() {
    _gates.add(
      GateState(
        blockedLane: _random.nextInt(GameBalance.laneCount),
        yPosition: -48,
      ),
    );
  }

  void _spawnSpark() {
    _sparks.add(
      SparkState(lane: _random.nextInt(GameBalance.laneCount), yPosition: -88),
    );
  }

  void _syncBestScore() {
    if (_score <= _bestScore) {
      return;
    }

    _bestScore = _score;
    _bestScoreStore.saveBestScore(_bestScore);
  }
}
