---
id: adr-pulse-drift-pwa-pages
title: PulseDrift PWA 배포에 Flutter Web과 GitHub Pages 사용
status: accepted
related_specs:
  - feature-pulse-drift-pwa-pages
---

# ADR: PulseDrift PWA 배포에 Flutter Web과 GitHub Pages 사용

## Context

iPhone 개발 서명 빌드는 주기적으로 재서명해야 한다. PulseDrift는 Flutter 기반 3레인 회피 게임이므로 정적 웹/PWA로도 플레이 경로를 제공할 수 있다.

## Decision

기존 네이티브 모바일 앱은 유지하고, `bon-on/PulseDrift` GitHub Pages에서 Flutter web build를 제공한다. 빌드는 `--base-href /PulseDrift/`를 사용한다. 웹에서는 AdMob 서비스와 배너 구현을 no-op으로 대체한다.

## Consequences

- iPhone 홈 화면에서 서명 만료 없이 실행할 수 있는 경로가 생긴다.
- GitHub Pages가 정적 Flutter web build를 호스팅한다.
- 웹 버전은 별도 웹 광고 설정 전까지 무광고다.
- 네이티브 모바일 빌드의 AdMob 경로는 유지된다.
