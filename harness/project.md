# Project instructions

Project-owned. Add instructions specific to this repository here, such as operational cautions, domain rules or verification notes that do not fit a spec, ADR or rule file. harness-lab creates this file once and never replaces your edits; keep `AGENTS.md`, `CLAUDE.md` and `harness/workflow.md` identical to the template so `harness-lab update` can refresh them.

- iPhone 홈 화면에서 실행할 앱을 설치할 때는 Debug 빌드/`flutter install`을 쓰지 않는다. 항상 `../_tools/install_ios_release.sh PulseDrift`로 standalone Release 빌드를 설치한다. Debug 빌드를 홈 화면에서 실행하면 `Cannot create a FlutterEngine instance in debug mode without Flutter tooling or Xcode.` 오류로 종료될 수 있다.
- 회귀 검증은 `flutter test`(CI와 동일), 공유 실행 증거는 `harness-lab verify`(`harness/verify.json`) 후 `check-evidence`와 `audit`로 확인한다.
