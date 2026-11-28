---
id: feature-gamepix-sdk
title: PulseDrift GamePix SDK v3 integration
status: active
owner: games
related_adrs:
  - adr-gamepix-sdk
  - adr-pulse-drift-gamepix-web
related_contracts:
  - contract-pulse-drift-gamepix
required_evidence:
  - flutter-tests
  - flutter-web-tests
  - flutter-analyze
  - gamepix-web-build
  - crazygames-web-build
---

# Feature Spec: PulseDrift GamePix SDK v3 integration

## Problem
The GamePix build was SDK-free (feature-pulse-drift-gamepix). GamePix gives games without its SDK integration approval less exposure. The SDK v3 guide asks for pause/resume handlers that stop gameplay, timers, input and audio, manual lifecycle signals, ads only at natural breaks and localStorage read by known key names. PulseDrift is a real-time game, so a pause must freeze the running loop, not only mute it.

## Scope
- GamePix web build (`--dart-define=GAMEPIX=true`) only: `lib/src/platform/gamepix_platform.dart`, the `GamePlatform` hooks it needs (`setPauseListener`, `showsRunBreakAds`, `showRunBreakAd`, no-op by default), their use in `lib/src/game/game_screen.dart` and `tool/build_gamepix.sh`.
- `lib/src/platform/crazygames_prefs_store.dart`: its save-failure log says "Cloud" instead of "CrazyGames", so the shared store adds no `crazygames` string to the GamePix bundle (S8).
- `tool/build_crazygames.sh` gains a check that the GamePix adapter is not in the CrazyGames bundle.
- Out of scope: gameplay and balance, CrazyGames/Pages/mobile behaviour, AdMob, rewarded ads, login, `happyMoment`/`sadMoment`, loading percentages.

## Acceptance Criteria
- S1: The GamePix `index.html` sets `window.GamePixConfig = { lifecycle: 'manual' }` and loads `https://integration.gamepix.com/sdk/v3/gamepix.sdk.js` exactly once, both in `<head>` before the inline Flutter bootstrap (`_flutter.loader.load`). No other external script, link or URL is added; the build script fails otherwise.
- S2: The adapter registers `pause`, `resume`, `soundOff` and `soundOn`. Pause and soundOff mute all game audio (`isAudioMuted`, refreshed through `addAudioMuteListener`); resume and soundOn restore it; repeated events change nothing.
- S3: A GamePix pause freezes a running run exactly like a hidden or inactive app: no simulation step (score, run time, gates and sparks stay put), no lane input, `gameplayStop` is reported, and paused time is not banked. Resume continues only when the app is also in the foreground (`lifecycleActive && !portalPaused`). A pause that arrived before the game screen registered is replayed on registration.
- S4: `lifecycle.loaded()` is sent once after the first Flutter frame; `lifecycle.gameStart()` is sent when gameplay starts, after `loaded()`. A Player that never answers does not block the game (10 s timeout).
- S5: Interstitials (`ads.interstitial()`) play only when the player leaves the run summary after a crash (Play again or Enter, Menu or Escape), never mid-run and never on a timer, at least 2 minutes after the previous ad (the first run break may show one; the Player caps ads at one every 3 minutes), and never twice at once. While the ad runs or the portal pauses, summary taps are absorbed and presses are ignored (an inactive window alone does not block them, so the click that refocuses a web page still works); after it the action runs only if the summary is still open. A failed, unfilled or hung ad (120 s) still continues, and a lost `resume` cannot leave the game paused.
- S6: Preferences are kept in one localStorage item read with `getItem` by name (`pulsedrift.prefs_v1`), so GamePix storage sync restores progress. Progress saved before the SDK (enumerated `flutter.` keys) is kept on the first SDK session, and those keys are never cleared.
- S7: Without the SDK (blocked script, direct page) the adapter behaves like a no-op portal platform: no ads, no pause events, no leaderboard prompt, no AdMob.
- S8: The CrazyGames bundle contains no `GamePix` string in `main.dart.js`, and the GamePix `main.dart.js` no `crazygames` string; both build scripts fail otherwise.

## Constraints
- GamePix rules: no other third-party SDK, no external links, no timer-triggered ads, the game pauses and mutes during ads.
- A broken SDK must never keep the game from starting or continuing.
- No new package dependencies; English ASCII strings in `lib/`.

## Stack Notes
- `GamePixPlatform` reuses `CloudPrefsStore` with the prefixed localStorage item as the "cloud", an in-memory mirror seeded from the old keys and no local stamp, so the named item is always the source. shared_preferences_web lists keys with `localStorage.key(i)`, which GamePix sync does not see.
- The factory selects the adapter with one conditional expression over `bool.fromEnvironment` constants so dart2js drops the other portal adapter.

## Evidence
- `flutter analyze`, `flutter test`, `flutter test --platform chrome test/web`.
- `tool/build_gamepix.sh` and `tool/build_crazygames.sh` succeed; `grep -c GamePix build/crazygames/main.dart.js` is 0.
