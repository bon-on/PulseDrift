---
id: adr-gamepix-sdk
title: Integrate the GamePix SDK v3 in the GamePix build
status: accepted
related_specs:
  - feature-gamepix-sdk
  - feature-pulse-drift-gamepix
---

# ADR: Integrate the GamePix SDK v3 in the GamePix build

## Context
The GamePix build was SDK-free by design (adr-pulse-drift-gamepix-web). Without GamePix SDK integration approval the game gets less exposure on the portal. The sibling games (TinyMines, SlideMerge) already ship the SDK v3 adapter; PulseDrift differs in being real-time, so a Player pause must stop the game loop and input, not only the audio.

## Decision
- `GAMEPIX=true` web builds select `GamePixPlatform` (SDK v3, manual lifecycle). `tool/build_gamepix.sh` injects the config and SDK script in `<head>` before the inline Flutter bootstrap; it is the only external script allowed.
- `GamePlatform` gains no-op `setPauseListener`, `showsRunBreakAds` and `showRunBreakAd`. The game screen merges the pause with the app lifecycle (`_appActive = lifecycleActive && !portalPaused`), so the existing freeze path (ticker step, input, gameplay events, music) covers both.
- Interstitials only when the player leaves the run summary after a crash, with a 2 minute cooldown; AdMob stays off (`allowsAds == false`).
- Preferences live in one named localStorage item (`pulsedrift.prefs_v1`) via `CloudPrefsStore`.
- This supersedes the "no SDK, no ads" part of adr-pulse-drift-gamepix-web; its other rules (no outbound links, bundled fonts, relative paths, no leaderboard upload) stay.

## Alternatives
- Stay SDK-free: no work, but no SDK approval or extra exposure.
- Mute only on pause (as a turn-based game could): the run would keep moving during GamePix overlays and ads and the player would crash unseen.
- A separate pause flag checked next to `_appActive`: duplicates every lifecycle check; merging into one flag keeps a single freeze path.
- Legacy automatic lifecycle: less code, but less accurate GamePix analytics (load time, time to play).

## Consequences
- The GamePix bundle requests integration.gamepix.com and shows GamePix interstitials between runs.
- The run, its input and its music follow GamePix pause events as well as app visibility.
- Existing players keep their progress: the first SDK session copies the enumerated local keys into the named item.
