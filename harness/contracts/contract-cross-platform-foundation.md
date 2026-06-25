---
id: contract-cross-platform-foundation
title: 첫 번째 공유 Flutter 게임 기반 구축
status: active
related_specs:
  - feature-cross-platform-migration
evidence_files:
  - reports/repo-kit-audit-report.md
---

# 계약: 첫 번째 공유 Flutter 게임 기반 구축

## Goal
iOS 전용 앱을 대체하고, iPhone과 Android에서 PulseDrift 핵심 게임 루프를 재현하는 Flutter 코드베이스를 구축한다.

## Scope
- Flutter 프로젝트 구조와 공유 앱 진입점을 만든다.
- 3레인 게임 루프, 드래그 레인 스냅 입력, 게이트, 스파크, 점수, 배수, 상한 없는 속도 증가, 재시작, 로컬 최고 점수 저장, 런타임 오디오를 구현한다.
- 구형 네이티브 Swift 앱을 운영 경로에서 제거한다.

## Done Criteria
- 저장소가 Flutter 프로젝트로 빌드된다.
- 공유 게임플레이 로직이 iOS와 Android를 함께 구동한다.
- 테스트가 밸런스 상승, 레인 스냅, 점수 저장을 다룬다.
- 하네스 산출물이 이 구현과 검증 절차를 참조한다.

## Verification
- 저장소에 대해 하네스 감사 명령을 실행한다.
- `flutter analyze`를 실행한다.
- `flutter test`를 실행한다.
- Flutter 기준 iOS와 Android 디버그 빌드를 각각 한 번 실행한다.

## Evidence References
- reports/repo-kit-audit-report.md
