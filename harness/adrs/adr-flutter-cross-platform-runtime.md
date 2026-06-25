---
id: adr-flutter-cross-platform-runtime
title: PulseDrift의 유일한 운영 런타임으로 Flutter 사용
status: accepted
related_specs:
  - feature-cross-platform-migration
---

# ADR: PulseDrift의 유일한 운영 런타임으로 Flutter를 사용

## Context
PulseDrift는 하나의 게임플레이 구현을 유지하면서 iPhone과 Android를 모두 지원해야 한다. 기존 SwiftUI/SpriteKit 코드는 iPhone만 지원하므로 Android 대응을 위해 별도 구현이 추가로 필요했다.

## Decision
게임의 유일한 운영 런타임으로 Flutter를 사용한다. 공유 게임플레이, 밸런스, 입력 처리, 저장, 화면 표시 로직은 Flutter 앱에 둔다. 기존 Swift 구현은 병행 유지하지 않고 참조용으로만 남긴다.

## Consequences
- iPhone과 Android가 하나의 코드베이스와 하나의 게임플레이 동작면을 공유한다.
- 이후 스펙 기반 작업은 두 개의 네이티브 구현을 맞추는 대신 하나의 런타임만 진화시키면 된다.
- 이번 마이그레이션은 점진적 포팅이 아니라 재구축이므로 단기 비용은 증가한다.
- Flutter가 자리 잡으면 네이티브 iOS 프로젝트 파일은 더 이상 기준 진입점이 아니다.
