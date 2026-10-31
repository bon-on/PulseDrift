---
id: feature-how-to-play-tutorial
title: First-run "How to play" tutorial with skip
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

# Feature: First-run "How to play" tutorial

## Problem
New players get a single hint line but no explanation of the goal, the lane
controls, or the spark and near-miss scoring. Players asked for a short
explanation or a tutorial that can be skipped.

## Scope
- On the first launch only, show a "How to play" overlay card over the game
  with 3 short steps (dodge gates between lanes, drag/tap/keyboard input,
  sparks and near-miss bonus). Each step has an icon and one or two short lines;
  page dots; "Skip" and "Next" buttons ("Play" on the last step).
- Skip or Play closes the overlay and stores the bool `tutorial_seen_v1` in
  `shared_preferences`; later launches go straight into the game.
- A "?" icon button (tooltip "How to play") in the header reopens it at step 1
  at any time. Reopening does not reset the run.
- Keyboard while open: Enter/Space = Next/Play, Escape = Skip, Left/Right =
  previous/next step. Lane keys (Left/A, Right/D) and restart keys (Space/Enter)
  do not reach the game while the overlay is open; taps and drags are blocked.
- The simulation does not advance while the overlay is open: `GameScreen`
  skips `GameController.update` and drops the elapsed gap so closing resumes
  without a time jump. The overlay also opens on the first frame, before any
  gate can reach the player.
- Storage failures never break play: a read failure shows the tutorial, a
  write failure just closes it.
- Implementation lives in `lib/src/game/how_to_play.dart` (overlay widget and
  a `TutorialStore` interface with a `shared_preferences` implementation,
  following `BestScoreStore`). `GameScreen` accepts an optional store so tests
  can fake it.

## Acceptance Criteria
- First launch (flag unset) shows the overlay; lane keys, taps and drags do not
  move the player while it is open.
- Next walks the steps, the last step shows Play, and Play closes and stores the flag.
- Skip closes and stores the flag; Escape also skips.
- With the flag set the overlay does not appear on launch.
- "?" reopens at step 1 without resetting game state.
- Gates, score and clock do not advance while the overlay is open and resume after.
- No overflow at 390x844, 844x390 and 1280x720.
- Flutter analyze, tests, web build with `--base-href /PulseDrift/`, and
  `<harness-lab>` audit (no critical findings) pass.

## Constraints
- English UI text, matching the existing game UI.
- No new dependency (`shared_preferences` is already used).
- Do not change balance, patterns or scoring.

## Evidence
- flutter analyze
- flutter test
- flutter build web --release --base-href /PulseDrift/
- `node <harness-lab>/dist/index.js audit . --format md`
