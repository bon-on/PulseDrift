---
id: feature-sound-effects
title: Web sound effects, background loop and user mute toggle
status: active
owner: games
related_adrs:
  - adr-flutter-cross-platform-runtime
  - adr-pulse-drift-crazygames-web
related_contracts:
  - contract-cross-platform-foundation
  - contract-pulse-drift-crazygames
required_evidence:
  - flutter-analyze
  - flutter-tests
  - flutter-web-build
  - harness-audit
---

# Feature: Web sound effects, background loop and user mute toggle

## Problem
The game plays `pulse_pass` and a background loop only through the native
iOS/Android shell channel, so GitHub Pages, CrazyGames and GamePix builds are
silent. There is no crash sound, no player mute control, and the iOS audio
session (`.playback`) ignores the silent switch and interrupts the user's music.

## Scope
- `lib/src/audio/sound_fx.dart` (`SoundFx`) replaces `AudioController`. It
  plays `pulse_pass` when a gate is dodged and `crash` when the run ends, and
  runs the music loop (`music_loop.wav` since `feature-retention-polish`,
  which also adds near-miss, spark, multiplier, mission and level-up effects).
- Web: HTML `Audio` per asset (`web_sound_web.dart`, conditional import with a
  stub). Browser autoplay rules: the loop only starts after the first user
  input (pointer down/up, key, or closing the tutorial) and is retried on later
  input if the browser refused it. Effects reset `currentTime` and ignore
  `play()` rejections.
- Native: the `pulse_drift/audio` MethodChannel takes asset names
  (`play` and `startLoop` with `asset`/`volume`, `stopLoop`, `disposeAudio`;
  generalized by `feature-retention-polish`). iOS uses audio session `.ambient`.
  Missing plugin or platform exceptions are swallowed.
- Mute: a sound icon button next to "?" (`Icons.volume_up_rounded` /
  `Icons.volume_off_rounded`, tooltip "Sound on" / "Sound off") stores
  `sound_muted_v1` (bool, default on) via an injectable `SoundMuteStore`.
  Effective mute = user mute OR `GamePlatform.isAudioMuted`, which the
  CrazyGames adapter reads from `SDK.game.settings.muteAudio` and refreshes
  through `addSettingsChangeListener` (an SDK without settings stays audible);
  GamePix/no-op is false. Muting stops the loop; unmuting resumes it while a
  run is active.
- The toggle is excluded from keyboard focus together with the rest of the
  game while the tutorial card is open (same as "?"), refocuses the game after
  a press, and adds no keyboard shortcut.
- Sounds are played from `GameScreen` callbacks (gate dodged, crash, restart),
  never per frame. No sound for the tutorial card.
- Assets: `pulse_pass.wav` was generated for the project earlier; `crash.wav`
  and the other effects and the music loop are produced by `tool/generate_sounds.py`
  (stdlib only, fixed seed, deterministic). No third-party audio.

## Acceptance Criteria
- Web builds request `pulse_pass.wav` on a dodged gate, `crash.wav` on crash
  and loop `music_loop.wav` after the first user input; nothing plays when
  muted.
- The toggle flips icon and tooltip, persists `sound_muted_v1`, and stops or
  resumes the loop.
- Platform mute silences effects and loop; native method names are unchanged.
- Every asset referenced by `SoundFx` exists on disk and is bundled; the
  generator output is identical across runs.
- Existing tests and the CrazyGames/GamePix build self-checks pass.

## Constraints
- No new package dependencies. English ASCII strings in `lib/`.
- GamePix: no external requests; audio is bundled.

## Evidence
- `python3 tool/generate_sounds.py` twice with identical `shasum`
- `flutter analyze`, `flutter test`, `flutter test --platform chrome test/web`
- `flutter build web --release --base-href /PulseDrift/`,
  `tool/build_crazygames.sh`, `tool/build_gamepix.sh`
- `<harness-lab>` audit (no critical findings)
