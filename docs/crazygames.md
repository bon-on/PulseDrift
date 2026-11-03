# CrazyGames 배포

`--dart-define=CRAZYGAMES=true`로 빌드하면 CrazyGames HTML5 SDK v3 어댑터를 쓴다. 이 플래그가 없는 웹(GitHub Pages)과 모바일 빌드는 SDK를 쓰지 않는다.

## 빌드

```sh
tool/build_crazygames.sh
```

결과물: `build/crazygames/`(번들 폴더), `build/pulse-drift-crazygames.zip`(업로드용).

스크립트는 `--base-href /`와 `--no-web-resources-cdn`으로 빌드한 뒤 `<base href="./">`로 바꾸고, Flutter 로더 앞에 SDK script를 넣고, Bon-on 허브 내비게이션 바를 지우고(포털은 외부 링크 금지), `*.symbols`를 삭제하고, 파일 수(1500개 이하)와 크기(50MB 이하)를 검사한다.

## 테스트

```sh
flutter test                              # 게임 흐름, 가짜 플랫폼 (VM)
flutter test --platform chrome test/web   # SDK 어댑터 (Chrome)
```

## 로컬 확인

```sh
cd build && python3 -m http.server 8765
# http://localhost:8765/crazygames/index.html
```

`localhost`에서는 SDK environment가 `local`이고 콘솔에 SDK 로그가 찍힌다.

## SDK 연동 지점

| 시점 | 호출 |
|---|---|
| 앱 시작 | `SDK.init()`; environment가 `crazygames`/`local`이 아니면 끔 |
| 저장 플래그를 읽고 오버레이가 없을 때(첫 실행은 오버레이를 닫은 뒤) | `gameplayStart` |
| "How to play" 오버레이 열림 | `gameplayStop` |
| 오버레이 닫힘 | `gameplayStart` |
| 충돌로 게임 오버 | `gameplayStop` |
| Restart | `gameplayStart` |

이 빌드에서는 AdMob, 배너/전면 광고, 리더보드 등록 안내가 모두 꺼진다.

## 업로드 메모

- 진행도는 SDK Data 모듈에 저장한다(`feature-crazygames-cloud-save`). 업로드할 때 제출 화면의 **Progress Save**에서
  "Yes, using the Data Module from the CrazyGames SDK"를 반드시 선택한다. 선택하지 않으면 Data 모듈이 꺼져 있어
  브라우저 localStorage에만 저장된다.
  - 모든 환경설정을 Data 모듈 키 `prefs_v1` 하나에 `{rev, owner, values}`로 저장하고, 같은 값을 localStorage에도 쓴다.
    localStorage의 `cg_prefs_stamp_v1`가 로컬 사본의 주인(사용자 이름, 게스트는 null)과 리비전을 기록한다.
  - 시작할 때 로컬 사본이 같은 사용자 것이고 리비전이 같거나 더 높으면 로컬을, 아니면 계정 사본을 쓴다. 다른 사용자의 로컬
    사본은 쓰지 않는다. 이 기능 이전의 로컬 진행도는 계정 사본이 없을 때만 이어받는다.
  - 로그인/로그아웃(`user.addAuthListener`)으로 사용자가 바뀌면 페이지를 다시 읽는다. 처음 사용자를 알 수 없으면 계정 저장을
    켜지 않는다.
- 방향: 세로(portrait) 위주. 데스크톱에서는 480px 폭 열이 가운데에 표시된다.
- 입력: 터치/마우스 드래그·탭, 키보드(←/→, A/D, Space/Enter 재시작).
- 오디오: 효과음(pulse_pass, crash)과 배경 루프를 HTML `Audio`로 재생한다. 브라우저 자동재생 정책 때문에 루프는 첫 사용자 입력(탭/키) 뒤에 시작한다. CrazyGames `settings.muteAudio`와 헤더의 소리 버튼(`sound_muted_v1`)이 모두 적용된다.
- 필요한 커버(아직 만들지 않음): 1920x1080, 800x1200, 800x800.
- Basic Launch로 먼저 제출한다.
