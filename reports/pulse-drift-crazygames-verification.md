# 검증 보고서: PulseDrift CrazyGames 웹 배포

- 명세: `harness/specs/feature-pulse-drift-crazygames.md`
- ADR: `harness/adrs/adr-pulse-drift-crazygames-web.md`
- 계약: `harness/contracts/contract-pulse-drift-crazygames.md`

| 검증 | 결과 |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | 43개 통과 (이전 31개) |
| `flutter test --platform chrome test/web` | 6개 통과 |
| `tool/build_crazygames.sh` | 성공, 파일 33개, 약 28MB, index.html 검증 통과 |
| `flutter build web --release --base-href /PulseDrift/` | 성공, SDK script 없음, 내비게이션 바 유지 |
| harness audit | Critical 0 |
