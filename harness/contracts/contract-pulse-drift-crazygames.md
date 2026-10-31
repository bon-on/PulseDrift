---
id: contract-pulse-drift-crazygames
title: PulseDrift CrazyGames 웹 배포 계약
status: active
related_specs:
  - feature-pulse-drift-gamepix
  - feature-pulse-drift-crazygames
evidence_files:
  - docs/crazygames.md
  - reports/pulse-drift-crazygames-verification.md
---

# 계약: PulseDrift CrazyGames 웹 배포

## Goal

같은 Flutter 코드베이스에서 CrazyGames HTML5 SDK v3를 연동한 업로드용 웹 번들을 만든다.

## Done Criteria

- `flutter analyze`, `flutter test`, 브라우저 SDK 어댑터 테스트가 통과한다.
- `tool/build_crazygames.sh`가 성공하고 번들 검증을 통과한다.
- GitHub Pages 빌드에는 SDK script가 없다.
- 검증 결과를 `reports/pulse-drift-crazygames-verification.md`에 남긴다.

## Verification

```sh
flutter analyze
flutter test
flutter test --platform chrome test/web
tool/build_crazygames.sh
flutter build web --release --base-href /PulseDrift/
node <harness-lab>/dist/index.js audit . --format md
```

## Evidence References

- docs/crazygames.md
- reports/pulse-drift-crazygames-verification.md
