# 에이전트 작업 지침

이 저장소에서 의미 있는 작업을 할 때는 반드시 `harness-apply` 스킬을 사용한다.

시작 순서:
1. `harness/manifest.json`을 먼저 읽는다.
2. `harness/specs/`에서 현재 활성 기능 명세를 선택한다.
3. manifest의 `approvedPacks`를 확인한다. 비어 있으면 `suggestedPacks`는 참고용으로만 취급한다.
4. 코드 변경 전에 연결된 ADR과 계약 문서를 읽는다.
5. `harness/rules/constraints.md`와 `harness/rules/golden-rules.md`를 읽는다.

응답 계약:
- `References used`, `Constraints`, `Conflicts or gaps`, `Escalation`을 반드시 포함한다.
- 필요한 하네스 산출물이 없거나 서로 충돌하면 추측하지 말고 즉시 에스컬레이션한다.
- 어떤 승인된 팩 또는 제안 팩을 사용했는지 명시한다.

기기 설치 주의:
- iPhone 홈 화면에서 실행할 앱을 설치할 때는 Debug 빌드/`flutter install`을 쓰지 않는다.
- 항상 `/Users/junsik.park/sources/games/_tools/install_ios_release.sh PulseDrift`로 standalone Release 빌드를 설치한다.
- Debug 빌드를 홈 화면에서 실행하면 `Cannot create a FlutterEngine instance in debug mode without Flutter tooling or Xcode.` 오류로 종료될 수 있다.
