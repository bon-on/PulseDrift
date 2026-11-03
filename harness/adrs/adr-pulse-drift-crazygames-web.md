---
id: adr-pulse-drift-crazygames-web
title: CrazyGames 배포에 빌드 플래그와 플랫폼 어댑터 사용
status: accepted
related_specs:
  - feature-pulse-drift-gamepix
  - feature-pulse-drift-crazygames
  - feature-sound-effects
  - feature-retention-polish
  - feature-crazygames-cloud-save
---

# ADR: CrazyGames 배포에 빌드 플래그와 플랫폼 어댑터 사용

## Context

`adr-pulse-drift-pwa-pages`는 웹 빌드를 GitHub Pages에 배포하도록 했다. CrazyGames는 임의 하위 경로에서 번들을 서빙하고, 외부 링크와 광고를 허용하지 않으며, gameplay 이벤트를 요구한다.

## Decision

- `bool.fromEnvironment('CRAZYGAMES')`로 플랫폼을 고른다. 게임 화면은 `GamePlatform` 인터페이스(`gameplayStart`, `gameplayStop`, `allowsAds`, `allowsResultRegistration`)에만 의존하고, 조건부 import(`dart.library.js_interop`)로 JS 어댑터를 모바일 빌드에서 제외한다.
- SDK script와 상대 base href는 `web/index.html`이 아니라 `tool/build_crazygames.sh`가 산출물에만 주입한다. 이 셸은 Flutter 로더를 인라인하므로 SDK 태그는 `#game-host` 바로 뒤(로더 앞)에 넣고, 치환이 실패하면 스크립트가 중단된다.
- 허브 내비게이션 바는 스크립트가 산출물에서 지운다. 리더보드와 광고는 `GamePlatform`으로 막는다.

## Consequences

- Pages와 모바일 빌드는 영향이 없다.
- SDK 실패는 no-op으로 떨어져 플레이가 유지된다.
- index.html 문자열 치환에 의존하므로 스크립트가 결과를 검증한다.
