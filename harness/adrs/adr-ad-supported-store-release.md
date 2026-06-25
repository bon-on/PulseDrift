---
id: adr-ad-supported-store-release
title: 스토어 출시를 위해 보수적인 AdMob 배치를 사용
status: accepted
related_specs:
  - feature-cross-platform-migration
---

# ADR: 스토어 출시를 위해 보수적인 AdMob 배치를 사용

## Context
PulseDrift는 무료 모바일 게임으로 App Store와 Play Store에 출시할
예정이다. 광고는 레인 회피 플레이를 방해하지 않아야 하며, 개인정보와
광고 식별자 신고가 스토어 정책과 일치해야 한다.

## Decision
공식 Google Mobile Ads Flutter 플러그인을 사용한다. 광고 요청 전 SDK의 UMP
흐름으로 동의 상태를 갱신하고, 광고 요청이 가능한 경우 앱 시작 시 SDK를
초기화한다. 실제 AdMob ID가 준비되기 전까지는 Google 테스트 ID를 쓴다. 배너는
별도 하단 슬롯에 표시하고, 전면 광고는 완료된 런 이후 낮은 빈도로만 표시한다.

## Consequences
- 공유 게임 컨트롤러는 광고 SDK에 의존하지 않는다.
- 출시 전 AdMob, 광고 식별자, 제3자 데이터 처리를 개인정보 문서와 스토어
  신고에 반영해야 한다.
- 실제 출시 빌드 전 테스트 ID를 앱별 실제 AdMob 앱/광고 단위 ID로 교체해야
  한다.
