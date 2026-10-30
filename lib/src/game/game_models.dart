class GateState {
  GateState({
    required this.openLanes,
    required this.yPosition,
    this.scored = false,
  });

  /// Lanes the player can pass through; every other lane is walled.
  final Set<int> openLanes;
  double yPosition;
  bool scored;

  /// Set once the gate has reached the player row, so near-miss is judged once.
  bool entered = false;
}

class SparkState {
  SparkState({required this.lane, required this.yPosition});

  final int lane;
  double yPosition;
}
