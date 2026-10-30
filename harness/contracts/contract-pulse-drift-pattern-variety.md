---
id: contract-pulse-drift-pattern-variety
title: Deliver capped speed, pattern variety and keyboard/tap input
status: active
related_specs:
  - feature-pulse-drift-pattern-variety
evidence_files:
  - reports/pulse-drift-pattern-variety-verification.md
---

# Contract: Pattern variety and desktop input

## Goal
Make late runs about decisions rather than an uncapped speed wall, and make the
game playable with keyboard, tap and mouse on a centered desktop column.

## Done Criteria
- Speed plateaus; double gates, spark bait and near-miss bonus work as in the
  feature spec.
- Left/A, Right/D and half-width taps shift lanes.
- Tests cover balance, pattern spawning, near miss and input mapping.
- Analyze, tests, web build and harness audit pass.

## Verification
- flutter analyze
- flutter test
- flutter build web --release --base-href /PulseDrift/
- harness audit

## Evidence References
- reports/pulse-drift-pattern-variety-verification.md
