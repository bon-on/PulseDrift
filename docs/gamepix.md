# GamePix 배포

`--dart-define=GAMEPIX=true`로 빌드하면 GamePix SDK v3(수동 lifecycle, `harness/specs/feature-gamepix-sdk.md`)를 쓰는 번들이 된다. 서드파티 스크립트는 GamePix SDK 하나뿐이고, 외부 링크, AdMob, 결과 업로드, 외부 폰트 요청은 없다. GamePix 전면 광고는 충돌 뒤 결과 화면에서 다음 판(Play again/Enter, Menu/Esc)으로 넘어갈 때만, 최소 2분 간격으로 나온다(Player 자체 제한은 3분에 한 번). 플레이 중이나 타이머로는 광고를 띄우지 않는다. 다른 빌드(GitHub Pages, CrazyGames, 모바일)는 바뀌지 않는다.

## 빌드

```sh
tool/build_gamepix.sh
```

결과물: `build/gamepix/`(번들 폴더), `build/pulse-drift-gamepix.zip`(업로드용, `index.html`이 zip 루트).

스크립트가 하는 일:

1. `flutter build web --release --base-href / --no-web-resources-cdn --dart-define=GAMEPIX=true`
2. `<base href="./">`로 바꾸고, 허브 내비게이션 바와 높이를 지우고, 템플릿 주석(문서 URL)을 지운다.
3. `<head>` 끝에 `<script>window.GamePixConfig = { lifecycle: 'manual' };</script>`와 `<script src="https://integration.gamepix.com/sdk/v3/gamepix.sdk.js"></script>`를 넣고, 각각 한 번만 있고 config → SDK → 인라인 Flutter 부트스트랩(`_flutter.loader.load`) 순서인지 검사한다.
4. SDK 태그를 뺀 index.html에서 검사: 다른 `<script src>` 없음, `crazygames`/`gamepix.com`/`bon-on.github.io`/`http(s)://` 없음(엔진 로더 상수인 gstatic CanvasKit, GitHub 이슈 URL 제외), viewport `user-scalable=no`, `touch-action: none`. 번들에 `crazygames-sdk` 없음, `main.dart.js`에 `crazygames` 문자열 없음, `FontManifest.json`에 Roboto, zip 루트의 `index.html`.
5. 파일 수/크기와 `main.dart.js`의 `crazygames` 문자열 수(0)를 출력한다.

`tool/build_crazygames.sh`는 반대로 CrazyGames `main.dart.js`에 `GamePix` 문자열이 있으면 실패한다.

## SDK 연동 내용

- `pause`/`resume`: 달리는 판을 탭이 숨겨졌을 때와 똑같이 멈춘다(시뮬레이션, 점수, 게이트, 입력, 배경음). 멈춘 시간은 생존 시간에 쌓이지 않는다. 앱이 포그라운드이고 Player가 재개했을 때만 이어진다.
- `soundOff`/`soundOn`: Player 음소거 버튼을 따른다(사용자 음소거와 함께 적용).
- `lifecycle.loaded()`는 첫 프레임 뒤 한 번, `lifecycle.gameStart()`는 판이 시작될 때 보낸다.
- 저장: 모든 설정을 localStorage의 `pulsedrift.prefs_v1` 한 항목에 둔다(GamePix 동기화는 이름으로 `getItem`한 항목만 본다). SDK 이전의 `flutter.` 키는 첫 SDK 세션에서 옮겨지고 지워지지 않는다.
- SDK가 없거나 막히면 광고와 일시정지 이벤트 없이 그대로 플레이된다.

## 로컬 확인

```sh
cd build && python3 -m http.server 8765
# http://localhost:8765/gamepix/index.html (640x480, 360x640 창에서도 확인)
```

로컬에서는 SDK가 integration.gamepix.com에서 로드된다. 오프라인이면 SDK 없는 동작으로 떨어진다.

## 업로드 메모

- SDK integration: 체크(GamePix SDK v3, 전면 광고, pause/resume, soundOff/soundOn, localStorage 동기화)
- 아이콘 256x256, 커버 1360x850 (아직 만들지 않음)
- 방향: 세로 위주(데스크톱에서는 480px 폭 열이 가운데에 표시됨). Desktop/Mobile friendly로 등록한다.
- 입력: 터치/마우스 드래그·탭, 키보드(←/→, A/D, Space/Enter 재시작).
- 오디오: 효과음과 배경음이 번들되어 있고, 첫 입력 뒤 재생된다.
- 언어: 영어(기본).
- 폰트: Roboto를 `assets/fonts/`에 번들한다(라이선스 `assets/fonts/Roboto_LICENSE.txt`). 그래서 런타임에 fonts.gstatic.com 요청이 없다. `main.dart.js`/`flutter_bootstrap.js`에는 gstatic URL 문자열이 남지만 사용되지 않는다.
