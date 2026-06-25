---
id: contract-pulse-drift-pwa-pages
title: PulseDrift PWA GitHub Pages 배포 계약
status: active
related_specs:
  - feature-pulse-drift-pwa-pages
evidence_files:
  - docs/pwa-github-pages.md
  - reports/pulse-drift-pwa-pages-verification.md
---

# 계약: PulseDrift PWA GitHub Pages 배포

## Goal

PulseDrift를 `https://bon-on.github.io/PulseDrift/`에서 실행되는 Flutter web/PWA로 배포한다.

## Scope

- Flutter web scaffold와 PWA 메타데이터.
- GitHub Pages workflow.
- 웹 no-op 광고 서비스와 배너 구현.
- 배포 문서와 검증 기록.

## Done Criteria

- `flutter test`가 통과한다.
- `flutter build web --release --base-href /PulseDrift/`가 통과한다.
- harness audit에 critical finding이나 warning이 없다.
- GitHub Pages가 배포 URL을 서빙한다.

## Verification

```sh
flutter test
flutter build web --release --base-href /PulseDrift/
node /Users/junsik.park/sources/harness-lab/dist/index.js audit . --format md
```

## Evidence References

- docs/pwa-github-pages.md
- reports/pulse-drift-pwa-pages-verification.md
