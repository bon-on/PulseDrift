---
id: feature-pulse-drift-pwa-pages
title: PulseDrift PWA GitHub Pages 배포
status: active
owner: games
related_adrs:
  - adr-pulse-drift-pwa-pages
related_contracts:
  - contract-pulse-drift-pwa-pages
required_evidence:
  - flutter-tests
  - flutter-web-build
  - harness-audit
---

# 기능 명세: PulseDrift PWA GitHub Pages 배포

## Problem

개발 서명으로 iPhone에 직접 설치한 빌드는 서명 만료 후 실행되지 않을 수 있다. PulseDrift를 App Store 없이 홈 화면에서 실행할 수 있는 웹/PWA 배포 경로가 필요하다.

## Scope

- 기존 iOS와 Android 네이티브 프로젝트를 유지한다.
- Flutter web/PWA 빌드를 추가한다.
- GitHub Pages 프로젝트 경로 `/PulseDrift/`에서 실행되게 한다.
- PWA manifest와 HTML 메타데이터를 PulseDrift에 맞게 설정한다.
- 웹에서는 네이티브 AdMob 호출을 no-op 처리한다.
- 테스트 통과 후 GitHub Actions로 Pages에 배포한다.

## Acceptance Criteria

- `flutter test`가 통과한다.
- `flutter build web --release --base-href /PulseDrift/`가 통과한다.
- 웹 빌드는 `https://bon-on.github.io/PulseDrift/` 경로 기준으로 asset을 찾는다.
- iOS와 Android 네이티브 디렉터리는 유지된다.
- 웹 플랫폼에서는 AdMob 초기화와 광고 요청이 발생하지 않는다.
- GitHub Pages가 `build/web` 산출물을 배포한다.

## Constraints

- 운영 앱은 공유 Flutter 코드베이스에서 iPhone과 Android를 모두 지원해야 한다.
- 게임은 3레인 회피 구조를 유지한다.
- 웹 배포는 별도 웹 광고 상품이 설정되기 전까지 무광고로 실행한다.

## Evidence

- `flutter test`
- `flutter build web --release --base-href /PulseDrift/`
- `node /Users/junsik.park/sources/harness-lab/dist/index.js audit . --format md`
