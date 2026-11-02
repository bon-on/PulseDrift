# Pulse Drift

Pulse Drift는 iPhone과 Android를 대상으로 Flutter로 재구성한 3레인 회피 아케이드 게임이다. 플레이어는 화면을 가로로 드래그해 레인을 바꾸고, 내려오는 펄스 게이트를 피하면서 점수와 배수를 올린다.

## 저장소 방향

- 기준 저장소: `bon-on/PulseDrift`
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
- 페이지를 열면 준비 카드("Tap / press Space to start")가 뜨고, 첫 탭/키 입력에서 런이 시작된다.
- 네온 신스웨이브 화면: 코드로 그린 우주선(엔진 트레일), 맥동하는 펄스 게이트, 시차 별과 흐르는 그리드 도로, 스피드 라인. 레인 변경 squash, 니어미스 "Close!" 보너스, 배수 버스트 배너, 충돌 시 화면 흔들림과 파편 연출이 있다.
- 판마다 미션 3개(생존 시간, 니어미스, 배수, 스파크, 게이트, 점수)가 나오고 달성하면 XP를 준다.
- 판이 끝나면 결과 화면(점수, 최고 점수, 시간, 니어미스, 최고 배수, 미션, XP와 레벨 바)이 뜬다. Enter/Space로 다시 하고 Esc로 준비 카드로 돌아간다.
- 파일럿 레벨이 오르면 테마(도로 팔레트 + 우주선 스킨)가 열린다: Neon Lv1, Sunset Lv3, Aurora Lv6, Void Lv10. 팔레트 버튼으로 고른다.
- 최고 점수는 `pulse_drift.best_score`, XP/최고 생존 시간/판 수/선택 테마는 `pulse_drift_progress_v1`(JSON)에 로컬 저장된다. 손상된 값은 초기값으로 대체된다.
- GitHub Pages 빌드에서만 0점을 넘긴 판 뒤에 리더보드 등록 안내가 뜬다.
- 첫 실행 때 건너뛸 수 있는 "How to play" 안내 카드가 나오고(`tutorial_seen_v1`로 기억), 헤더의 ? 버튼으로 다시 열 수 있다. 열려 있는 동안 게임은 멈춘다.

## CrazyGames 빌드

`tool/build_crazygames.sh`가 `build/pulse-drift-crazygames.zip`을 만든다(SDK 이벤트, 허브 링크/광고/리더보드 없음). 자세한 내용은 `docs/crazygames.md`.

## GamePix 웹 번들

`tool/build_gamepix.sh`를 실행하면 `build/gamepix/`와 업로드용 `build/pulse-drift-gamepix.zip`이 생성된다(SDK 없음, 외부 링크/광고/결과 업로드 없음). 자세한 내용은 `docs/gamepix.md`를 참고한다.

## 소리

- `assets/audio/pulse_pass.wav`는 이 프로젝트를 위해 생성한 파일이다. `crash.wav`, 니어미스/스파크/배수/미션/레벨 업 효과음, 신스웨이브 배경음악 `music_loop.wav`(120 bpm, 16 kHz 모노, 끊김 없는 16초 루프)는 `tool/generate_sounds.py`(Python 3 표준 라이브러리만, 고정 시드)로 만든다. 서드파티 오디오는 없다. 다시 만들려면 `python3 tool/generate_sounds.py`를 실행한다.
- 웹(Pages, CrazyGames, GamePix)과 iOS/Android 모두에서 재생된다. 브라우저 정책 때문에 배경 루프는 첫 탭/키 입력 뒤에 시작한다.
- 헤더의 스피커 버튼(? 옆)으로 끄고 켠다. 선택은 `shared_preferences`의 `sound_muted_v1`에 저장되고, CrazyGames 플랫폼 음소거와 함께 적용된다. iOS 오디오 세션은 `.ambient`다(무음 스위치를 따르고 다른 앱의 음악을 끊지 않는다).

## 폰트 라이선스

웹 빌드가 외부 폰트를 받지 않도록 Roboto(Apache License 2.0)를 `assets/fonts/`에 번들한다. 라이선스 전문은 `assets/fonts/Roboto_LICENSE.txt`에 있다.

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
