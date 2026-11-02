---
id: feature-pulse-drift-crazygames
title: PulseDrift CrazyGames 웹 배포
status: active
owner: games
related_adrs:
  - adr-pulse-drift-crazygames-web
related_contracts:
  - contract-pulse-drift-crazygames
required_evidence:
  - flutter-tests
  - flutter-analyze
  - crazygames-web-build
  - harness-audit
---

# 기능 명세: PulseDrift CrazyGames 웹 배포

## Problem

PulseDrift 웹 빌드는 GitHub Pages에만 배포된다. CrazyGames 포털에 올리려면 HTML5 SDK v3 gameplay 이벤트, 상대 경로 번들, 외부 링크/광고/외부 기록 업로드 제거가 필요하다.

## Scope

- `--dart-define=CRAZYGAMES=true`로 빌드한 웹 번들에서만 CrazyGames 어댑터(`dart:js_interop`)를 쓴다. 플래그가 없으면 no-op 플랫폼이라 GitHub Pages, iOS, Android 동작은 그대로다.
- SDK 이벤트(전환 시에만, 중복 없음):
  - `gameplayStart`: 저장된 튜토리얼 플래그를 읽었고, "How to play" 오버레이가 닫혀 있고, 플레이어가 준비 카드("Tap / press Space to start")에서 첫 입력(탭, 드래그, Space/Enter, 방향키/A/D)을 해서 런이 시작됐을 때. 페이지를 열자마자 런이 자동으로 시작되지 않는다.
  - `gameplayStop`: 오버레이가 열릴 때(첫 실행 또는 ? 버튼), 충돌로 게임 오버가 될 때.
  - `gameplayStart`: 오버레이가 닫힐 때, 게임 오버 후 Restart 할 때.
- `SDK.init()` 실패/타임아웃/SDK 없음/environment가 `crazygames`·`local`이 아님이면 어댑터는 조용히 꺼지고 게임은 그대로 플레이된다.
- CrazyGames 빌드에서는 AdMob을 초기화하지 않고 배너/전면 광고를 띄우지 않는다(`GamePlatform.allowsAds`). 웹 빌드의 `AdService`/`AdBanner`는 원래 no-op이다.
- CrazyGames 빌드에서는 리더보드 등록 안내(`feature-post-game-leaderboard`)를 띄우지 않는다(`allowsResultRegistration`).
- `tool/build_crazygames.sh`가 `build/crazygames/`와 `build/pulse-drift-crazygames.zip`을 만든다: 상대 `<base href="./">`, 인라인 Flutter 로더 앞의 SDK script, 게임 허브 내비게이션 바(`feature-game-hub-navigation`) 제거와 높이 0, `*.symbols` 삭제, 파일 1500개 이하, 50MB 이하, 치환 결과 자체 검사.
- 튜토리얼 후속 수정: 저장 플래그를 읽는 동안 입력과 시뮬레이션을 막고, 게임 오버 후 키 반복(KeyRepeat)으로 재시작되지 않게 하며, 오버레이와 게임이 Tab/F5/Ctrl/Meta/Alt 단축키를 가로채지 않는다.

제외 범위: 게임 플레이/밸런스 변경, 보상형 광고, Data/User 모듈, 웹 오디오 추가, 포털 업로드.

## Acceptance Criteria

- `flutter analyze`, `flutter test`, `flutter test --platform chrome test/web`가 통과한다.
- 가짜 플랫폼 위젯 테스트가 튜토리얼 오버레이 포함 호출 순서와, 광고/리더보드가 플랫폼을 따르는지 검증한다.
- `tool/build_crazygames.sh`가 성공하고 번들 `index.html`에 `<base href="./">`, 로더 앞 SDK script가 있으며 `bon-on.github.io` 링크가 없고 `--games-nav-height: 0px`이다.
- `flutter build web --release --base-href /PulseDrift/` 결과에는 SDK script가 없고 내비게이션 바가 유지된다.

## Constraints

- 게임 플레이는 SDK와 네트워크 없이 동작해야 한다.
- 새 pub 의존성을 추가하지 않는다.
- 모바일 AdMob 경로는 변경하지 않는다.

## Evidence

- `flutter analyze`, `flutter test`, `flutter test --platform chrome test/web`
- `tool/build_crazygames.sh`
- `flutter build web --release --base-href /PulseDrift/`
- `node <harness-lab>/dist/index.js audit . --format md`
- `reports/pulse-drift-crazygames-verification.md`
