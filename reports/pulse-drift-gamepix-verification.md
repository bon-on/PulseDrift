# 검증 보고서: PulseDrift GamePix 웹 배포

- 명세: `harness/specs/feature-pulse-drift-gamepix.md`
- ADR: `harness/adrs/adr-pulse-drift-gamepix-web.md`
- 계약: `harness/contracts/contract-pulse-drift-gamepix.md`
- 날짜: 2026-10-31
- 환경: Flutter (Homebrew), macOS, Google Chrome headless

> 2026-11-28: 이 보고서는 SDK 없는 번들(2026-10-31) 기준의 기록이다. GamePix SDK v3 연동(`feature-gamepix-sdk`) 뒤에는 번들이 integration.gamepix.com에서 SDK를 받고 SDK가 자체 요청을 보내므로 "외부 호스트 요청 0"은 더 이상 성립하지 않는다. 연동 뒤 검증(analyze, test, web test, 두 빌드 스크립트)은 `harness/specs/feature-gamepix-sdk.md` Evidence 기준으로 했고, SDK 연동 번들의 headless Chrome 네트워크/오버플로 확인은 아직 하지 않았다.

## 실행한 검증

| 검증 | 결과 |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | 47개 통과 (`test/gamepix_platform_test.dart` 3개 포함) |
| `flutter test --platform chrome test/web` | 통과 |
| `tool/build_gamepix.sh` | 성공: `index.html`이 zip 루트, `crazygames-sdk`/`bon-on.github.io`/외부 URL 없음, 상대 base, `FontManifest.json`에 Roboto, 파일 약 37개, zip 약 11.6MB |
| `main.dart.js`의 `crazygames` 문자열 | 0개 |
| `tool/build_crazygames.sh` | 성공, Roboto 번들, SDK script 유지 |
| `flutter build web --release --base-href` (Pages) | 성공, SDK script 없음, 허브 내비게이션 유지 |
| headless Chrome 640x480, 360x640 | 오버플로/잘림 없음(scrollWidth/Height = 뷰포트), 로딩 화면은 첫 프레임에 사라짐, 외부 호스트 요청 0 |

## 알려진 사항

- `flutter_bootstrap.js`/`main.dart.js`/인라인 로더에 gstatic CanvasKit 및 폰트 URL 문자열이 엔진 상수로 남지만 `useLocalCanvasKit`과 번들 Roboto 때문에 요청되지 않는다.
- 번들 크기는 CanvasKit 변형 파일들 때문에 약 29MB다.
