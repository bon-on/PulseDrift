---
id: feature-pulse-drift-pattern-variety
title: PulseDrift speed plateau, pattern variety and desktop input
status: active
owner: games
related_adrs:
  - adr-flutter-cross-platform-runtime
related_contracts:
  - contract-pulse-drift-pattern-variety
required_evidence:
  - flutter-analyze
  - flutter-tests
  - flutter-web-build
  - harness-audit
---

# Feature: Speed plateau, pattern variety and desktop input

## Problem
Runs were pure reaction: one open lane per gate, random lane, and a speed that
grew by 32 px/s per dodge after 12 dodges with no cap, which ends every run in
an unreadable wall. Sparks were free +25 with no cost, and there was no way to
play with a keyboard or a plain tap on desktop. The layout also stretched
across wide desktop windows.

This spec supersedes the "no fixed cap on speed" criterion of
`feature-cross-platform-migration`; the rest of that spec still holds.

## Scope
- Cap fall speed at `GameBalance.maxSpeed` (600 px/s) and raise difficulty
  through patterns instead.
- Patterns, chosen by `GameBalance.patternFor(cleanDodges, roll)`:
  - single gate (one open lane), as before.
  - double gate: two single-gap gates `doubleGateGapSeconds` apart, always in
    different lanes, forcing a lane change.
  - spark bait: a gate with two open lanes whose spark sits in the open lane
    farthest from the exit gap of a single-gap gate `baitGateGapSeconds`
    behind it. Taking the spark (+25) costs a lane change under time pressure.
- Sparks only appear as bait now and fall at gate speed so the spark stays
  aligned with its gate; ambient random sparks are removed.
- Near-miss bonus: entering the gate's open lane within
  `nearMissWindowSeconds` of the gate reaching the player, after being in a
  walled lane, awards `nearMissBonus` points with a brief ring and label.
- Input: Left/A and Right/D shift one lane; tapping the left/right half of the
  play column shifts one lane; dragging still follows the pointer. Space or
  Enter restarts after game over.
- Layout: play column centered with max width 480 px on desktop, full width on
  phones; on web the Flutter view is embedded in the `#game-host` element below
  the hub bar (web/index.html), so no app-side offset is needed.
- Tap vs drag: a tap shifts one lane; a drag follows the pointer. Flutter's pan
  slop already keeps small mouse jitter (a few px) classified as a tap.

## Numbers and rationale
- Speed: `280 + 360 * (1 - 0.88^n)`, clamped to 600. The curve is unchanged
  until it reaches 600 at 18 dodges (the old curve passed 600 around 14 dodges
  and kept rising). At 600 px/s a gate crosses a ~530 px lane in about 0.9 s.
- Gate spacing floor rises from 0.48 s to 0.62 s (reached at 28 dodges): at
  the capped speed 0.48 s left under 290 px between gates, too tight to read.
- Double chance 10% at 4 dodges, +2% per dodge, cap 30%. Bait chance 8% at 8
  dodges, +1% per dodge, cap 20%. The remaining 50%+ stay single gates as
  breathing room. Gaps of 0.65 s and 0.75 s are about two human lane taps.
- Near miss: 0.18 s window, +15 points (1.5 base gates), less than a spark so
  safe spark bait remains the main score lever.

## Acceptance Criteria
- `speedFor` never exceeds `maxSpeed`, is non-decreasing, and equals the cap
  from 18 dodges onward.
- Pattern chances are 0 below their unlock, grow with dodges and cap as above;
  `patternFor` is a pure function of dodges and roll.
- Bait layout: wall lane differs from the exit lane, the spark lane is open in
  the first gate and walled in the second.
- Double gates always have different open lanes.
- A late switch into the open lane awards the near-miss bonus; an early one
  does not.
- `shiftLane` moves one lane and clamps; key and tap mapping helpers are
  covered by tests.
- No overflow at 390x844 and 1280x720.
- Flutter analyze, tests, web build with `--base-href /PulseDrift/`, and harness
  audit (no critical findings) pass.

## Constraints
- Keep the 3-lane structure, opt-in leaderboard, hub nav and AdMob behaviour
  (ads stay no-op on web).
- `GameBalance` stays deterministic: randomness enters only through rolls
  passed in by the controller.

## Evidence
- reports/pulse-drift-pattern-variety-verification.md
- `flutter analyze`, `flutter test`
- `flutter build web --release --base-href /PulseDrift/`
