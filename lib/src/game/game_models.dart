class GateState {
  GateState({
    required this.blockedLane,
    required this.yPosition,
    this.scored = false,
  });

  final int blockedLane;
  double yPosition;
  bool scored;
}

class SparkState {
  SparkState({required this.lane, required this.yPosition});

  final int lane;
  double yPosition;
}
