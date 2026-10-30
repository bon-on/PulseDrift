# PulseDrift pattern variety verification

Spec: `harness/specs/feature-pulse-drift-pattern-variety.md`

## Checks
- `flutter analyze`: no issues.
- `flutter test`: all tests pass, including balance (speed plateau, pattern
  chances, bait layout), controller (shiftLane, near miss, double gate and bait
  spawning over 40 seeds) and input mapping tests.
- `flutter build web --release --base-href /PulseDrift/`: succeeds.
- Headless Chrome screenshots at 1280x720 (centered column) and 390x844
  (iframe, full width) show no overflow.
- Harness audit: no critical findings.

## Not verified
- Real keyboard and tap play-through in a browser; feel of the tuned numbers.
- Android/iOS builds and AdMob behaviour (code untouched apart from layout).
