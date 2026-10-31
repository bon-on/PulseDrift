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

- 방향: 세로(portrait) 위주. 데스크톱에서는 480px 폭 열이 가운데에 표시된다.
- 입력: 터치/마우스 드래그·탭, 키보드(←/→, A/D, Space/Enter 재시작).
- 오디오: 웹 빌드에는 효과음/배경음이 없다(오디오는 iOS 네이티브 채널 전용이고 웹에서는 조용히 무시된다). 그래서 iOS Safari의 AudioContext resume 처리는 해당 없다.
- 필요한 커버(아직 만들지 않음): 1920x1080, 800x1200, 800x800.
- Basic Launch로 먼저 제출한다.
