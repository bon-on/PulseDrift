---
id: contract-pulse-drift-gamepix
title: PulseDrift GamePix 웹 배포 계약
status: active
related_specs:
  - feature-pulse-drift-gamepix
  - feature-gamepix-sdk
  - feature-retention-polish
evidence_files:
  - docs/gamepix.md
  - reports/pulse-drift-gamepix-verification.md
---

# 계약: PulseDrift GamePix 웹 배포

## Goal

같은 Flutter 코드베이스에서 GamePix 업로드용 웹 번들을 만든다. 서드파티 스크립트는 GamePix SDK v3 하나뿐이고(feature-gamepix-sdk), 그 외 외부 요청과 외부 링크는 없다. GamePix 일시정지는 달리는 판을 멈추고, 전면 광고는 충돌 뒤 다음 판으로 넘어갈 때만 나온다.

## Done Criteria

- `flutter analyze`, `flutter test`, `flutter test --platform chrome test/web`이 통과한다.
- `tool/build_gamepix.sh`가 성공하고 자체 검사(SDK 태그 1회, 부트스트랩보다 앞, 다른 외부 스크립트 없음, `main.dart.js`에 `crazygames` 없음)를 통과한다.
- `tool/build_crazygames.sh`가 성공하고 CrazyGames `main.dart.js`에 `GamePix`가 없다.
- CrazyGames, Pages 빌드가 계속 성공한다.
- 검증 결과를 `reports/pulse-drift-gamepix-verification.md`에 남긴다.

## Verification

```sh
flutter analyze
flutter test
flutter test --platform chrome test/web
tool/build_gamepix.sh
tool/build_crazygames.sh
flutter build web --release --base-href /PulseDrift/
node <harness-lab>/dist/index.js audit . --format md
```

## Evidence References

- docs/gamepix.md
- reports/pulse-drift-gamepix-verification.md
