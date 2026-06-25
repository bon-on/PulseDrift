# 하네스 계획 보고서

- 제목: PulseDrift를 스펙 기반 Flutter 게임으로 재구축
- 명세: `/Users/junsik.park/sources/games/PulseDrift/harness/specs/feature-cross-platform-migration.md`
- 상태: active

## 실행 순서

1. 기능 명세에서 의도와 수용 기준을 읽는다.
2. 런타임 또는 플랫폼 결정 전에 ADR `adr-flutter-cross-platform-runtime`을 읽는다.
3. 광고 또는 스토어 출시 결정 전에 ADR `adr-ad-supported-store-release`를 읽는다.
4. 작업 단위 완료 기준을 확정하기 위해 계약 문서 `contract-cross-platform-foundation`을 읽는다.
5. 명세 요구사항을 저장소 제약과 골든 룰에 대조한다.
6. 수용 기준을 만족하는 가장 작은 구현 변경을 수행한다.
7. 필요한 증빙을 수집하고 에스컬레이션 포인트를 기록한다.

## 수용 기준

- 활성 저장소 경로가 `/Users/junsik.park/sources/games/PulseDrift`이고 하네스 산출물이 모두 존재한다.
- 운영 앱은 공유 게임 로직을 사용하는 Flutter 프로젝트이며 iOS/Android 타깃을 가진다.
- 플레이어는 드래그와 탭으로 세 레인 사이를 이동할 수 있다.
- 속도 증가는 공유 밸런스 모델에서 상한 없이 이어진다.
- 게이트 통과 효과음과 배경 루프 사운드가 존재한다.
- 최고 점수가 로컬에 유지된다.
- 광고는 플레이 중간을 끊지 않으며, 배너는 별도 레이아웃 슬롯에 표시되고 전면 광고는 완료된 런 이후에만 표시 대상이 된다.
- 플랫폼 manifest/plist에는 테스트 빌드용 AdMob 앱 식별자와 광고 식별자 관련 메타데이터가 포함된다.
- `flutter analyze`와 자동화 테스트가 통과한다.
- Flutter 코드베이스에서 실행 가능한 iOS/Android 빌드를 만들 수 있다.

## 관련 제약

- 구형 Swift 코드는 운영 타깃으로 유지하지 않는다.
- 공유 게임플레이 로직을 유지하고 플랫폼별 코드는 앱 셸 수준으로 제한한다.
- 이후 기능 변경은 구현 전에 `harness/specs/`에 기록한다.

## 관련 ADR

- `adr-flutter-cross-platform-runtime`: PulseDrift의 유일한 운영 런타임으로 Flutter를 사용
- `adr-ad-supported-store-release`: 스토어 출시를 위해 보수적인 AdMob 배치를 사용

## 관련 계약

- `contract-cross-platform-foundation`: 첫 번째 공유 Flutter 게임 기반 구축

## 필요 증빙

- `node /Users/junsik.park/sources/harness-lab/dist/index.js audit /Users/junsik.park/sources/games/PulseDrift --format md`
- `node /Users/junsik.park/sources/harness-lab/dist/index.js plan /Users/junsik.park/sources/games/PulseDrift/harness/specs/feature-cross-platform-migration.md --format text`
- `flutter analyze`
- `flutter test`
- `flutter build ios --simulator`
- `flutter build apk --debug`

## 차단 요소

- 없음
