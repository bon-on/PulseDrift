# Harness Apply 스킬 메모

- 사용한 참조:
  - `harness/manifest.json`
  - `harness/specs/feature-cross-platform-migration.md`
  - `harness/adrs/adr-flutter-cross-platform-runtime.md`
  - `harness/contracts/contract-cross-platform-foundation.md`
  - `harness/rules/constraints.md`
  - `harness/rules/golden-rules.md`
- 제약:
  - 운영 앱은 공유 Flutter 런타임을 유지한다.
  - 광고는 플레이 중간을 끊지 않고 별도 레이아웃 슬롯과 완료된 런 이후 전면 광고 조건을 따른다.
  - 제품 변경은 구현 전에 `harness/specs/`의 Markdown 명세로 기록한다.
- 충돌 또는 공백:
  - 승인된 프로필 팩은 없다. 스택 지침은 저장소 규칙 문서에 직접 유지한다.
- 에스컬레이션:
  - 실제 스토어 업로드 전에는 privacy/support URL과 서명 자격증명을 별도로 채워야 한다.
