# Pulse Drift

Pulse Drift는 iPhone과 Android를 대상으로 Flutter로 재구성한 3레인 회피 아케이드 게임이다. 플레이어는 화면을 가로로 드래그해 레인을 바꾸고, 내려오는 펄스 게이트를 피하면서 점수와 배수를 올린다.

## 저장소 방향

- 기준 저장소 경로: `/Users/junsik.park/sources/games/PulseDrift`
- 운영 런타임: Flutter 단일 런타임
- 기능 명세 기준 경로: `harness/specs/`
- 아키텍처 결정 경로: `harness/adrs/`
- 레거시 Swift 참조 경로: `legacy/swift_ios/`

## 게임 개요

- 3개의 레인에서 한 플레이어가 끝없이 내려오는 게이트를 피한다.
- 가로 드래그는 가장 가까운 레인으로 즉시 스냅된다.
- 짧은 탭도 터치한 레인으로 이동한다.
- 청록색 스파크는 추가 점수를 준다.
- 속도와 스폰 간격은 공유 밸런스 모델에서 점진적으로 상승한다.
- 최고 점수는 로컬에 저장된다.

## 스펙 기반 작업 절차

1. `harness/manifest.json`을 읽는다.
2. `harness/specs/`에서 활성 기능 명세를 읽는다.
3. 연결된 ADR과 계약 문서를 읽는다.
4. `harness/rules/constraints.md`, `harness/rules/golden-rules.md`를 읽는다.
5. 수용 기준이 있는 기능 명세를 먼저 갱신한 뒤 구현한다.

## 로컬 실행

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

플랫폼 빌드:

```bash
flutter build ios --simulator
flutter build apk --debug
```

## 프로젝트 구성

- `lib/`: Flutter 앱과 공유 게임 로직
- `test/`: 밸런스, 레인 스냅, 컨트롤러 테스트
- `harness/`: manifest, 명세, ADR, 계약, 규칙, 템플릿
- `docs/`: 간단한 탐색 문서
- `legacy/swift_ios/`: 참조용으로만 남겨둔 구형 Swift 구현
