import 'package:flutter/services.dart';

/// Lane shift for a key press: -1 for Left/A, +1 for Right/D, null otherwise.
int? laneDeltaForKey(LogicalKeyboardKey key) {
  if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA) {
    return -1;
  }
  if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.keyD) {
    return 1;
  }
  return null;
}

/// Keys that restart a finished run.
bool isRestartKey(LogicalKeyboardKey key) =>
    key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.enter;

/// Lane shift for a tap: left half of the play column goes left, right half right.
int laneDeltaForTap({required double x, required double width}) =>
    x < width / 2 ? -1 : 1;
