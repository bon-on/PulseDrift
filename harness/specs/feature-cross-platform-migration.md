---
id: feature-cross-platform-migration
title: PulseDrift를 스펙 기반 Flutter 게임으로 재구축
status: active
owner: junsik.park
related_adrs:
  - adr-flutter-cross-platform-runtime
  - adr-ad-supported-store-release
related_contracts:
  - contract-cross-platform-foundation
required_evidence:
  - flutter-analyze
  - flutter-tests
  - ios-build
  - android-build
  - harness-audit
---

# 기능 명세: PulseDrift를 스펙 기반 Flutter 게임으로 재구축

## Problem
PulseDrift는 현재 iPhone 전용 SwiftUI/SpriteKit 프로젝트에서 시작했으며, 레인 이동도 탭 중심으로 설계되어 있었다. 앞으로는 iPhone과 Android를 함께 지원하는 공유 런타임, 드래그 기반 조작, 그리고 대화 로그가 아닌 버전 관리되는 Markdown 문서를 기준으로 개발이 이어져야 한다.

## Scope
- 기준 저장소를 `/Users/junsik.park/sources/games/PulseDrift`로 고정한다.
- 하네스 저장소 키트를 적용하고, 기능 작업을 명세, ADR, 계약 문서에 연결한다.
- 네이티브 iOS 구현을 대체하는 Flutter 앱을 만들고 iPhone과 Android를 함께 지원한다.
- 3레인 회피 루프는 유지하되, 조작은 탭 중심에서 드래그 기반 레인 스냅으로 바꾼다.
- 점수, 배수, 속도 상승, 스파크 보너스, 재시작, 최고 점수 저장, 게임 오디오를 재구성한다.
- App Store와 Play Store 출시를 위해 AdMob 배너 광고, 낮은 빈도의 게임오버 전면 광고, 개인정보/스토어 신고 문서를 준비한다.

## Acceptance Criteria
- 활성 저장소 경로가 `/Users/junsik.park/sources/games/PulseDrift`이고, 하네스 manifest, rules, templates, spec, ADR, contract를 포함한다.
- 운영 앱은 공유 게임 로직을 사용하는 Flutter 프로젝트이며 iOS/Android 타깃을 모두 가진다.
- 플레이어는 가로 드래그로 세 레인 중 가장 가까운 레인으로 스냅되며, 짧은 탭도 해당 레인 선택으로 동작한다.
- 장애물 속도는 기존 빌드보다 느리게 시작하고, 하나의 공유 밸런스 모델에서 고정 상한 없이 계속 증가한다.
- 펄스 게이트를 통과하면 회피 효과음이 나고, 플레이 중에는 반복 배경 사운드가 재생된다.
- 최고 점수는 앱 재실행 후에도 유지된다.
- 광고는 플레이 중간을 끊지 않으며, 배너는 별도 레이아웃 슬롯에 표시되고 전면 광고는 완료된 런 이후에만 표시 대상이 된다.
- 플랫폼 manifest/plist에는 테스트 빌드용 AdMob 앱 식별자와 광고 식별자 관련 메타데이터가 포함된다.
- `flutter analyze`와 자동화 테스트가 통과한다.
- Flutter 코드베이스에서 실행 가능한 iOS/Android 빌드를 만들 수 있다.

## Constraints
- 구형 Swift 코드는 운영 타깃으로 유지하지 않는다.
- 게임플레이 로직은 플랫폼 간 공유하고, 플랫폼별 코드는 앱 셸 통합 수준으로 제한한다.
- 이후 게임 변경은 구현 전에 반드시 `harness/specs/`에 명세로 기록한다.
- 감지된 프로필 팩이 승인되기 전까지는 저장소 규칙 문서만을 공식 근거로 사용한다.

## Evidence
- `node /Users/junsik.park/sources/harness-lab/dist/index.js audit /Users/junsik.park/sources/games/PulseDrift --format md`
- `flutter analyze`
- `flutter test`
- `flutter build ios --simulator`
- `flutter build apk --debug`
