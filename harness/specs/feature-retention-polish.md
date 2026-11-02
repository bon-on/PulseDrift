---
id: feature-retention-polish
title: PulseDrift 네온 신스웨이브 시각 개편, 손맛, 재플레이 동기(미션, 레벨, 테마)
status: active
owner: games
related_adrs:
  - adr-flutter-cross-platform-runtime
  - adr-pulse-drift-crazygames-web
  - adr-pulse-drift-gamepix-web
related_contracts:
  - contract-cross-platform-foundation
  - contract-pulse-drift-crazygames
  - contract-pulse-drift-gamepix
required_evidence:
  - flutter-analyze
  - flutter-tests
  - web-build
  - harness-audit
---

# 기능 명세: PulseDrift 네온 신스웨이브 시각 개편, 손맛, 재플레이 동기

## Problem
CrazyGames는 같은 계열 게임(MergeCamp)을 "The overall quality of the game does not yet meet the expectations of our platform"으로 거절했다.
PulseDrift도 흰 원(플레이어), 주황 사각형(게이트), 회색 선(레인)뿐이라 시제품처럼 보인다. 충돌, 니어미스, 배수 상승 같은 순간의 연출이 약하고,
배경음악은 분위기가 없으며, 판이 끝나면 최고 점수 외에 남는 것이 없어 다시 플레이할 이유(목표, 성장, 수집)가 없다.

## Scope
1. 시각 개편(네온 신스웨이브 드리프트)
   - 외부 에셋 없이 `CustomPainter`로 그린다: 엔진 트레일이 있는 우주선(테마별 스킨), 빛나는 펄스 게이트(맥동하는 코어와 테두리 글로), 별 모양 스파크.
   - 배경: 화면 전체에 신스웨이브 풍경(그라데이션 하늘, 줄무늬 태양, 산 실루엣, 원근 그리드 바닥)을 그린다. 플레이필드는 위에서 내려다본 네온 도로다: 시차(parallax) 별, 흐르는 그리드, 발광 레인 구분선, 속도에 비례하는 스피드 라인.
   - 테마 4종: Neon(기본), Sunset, Aurora, Void. 테마는 도로/하늘 팔레트와 우주선 스킨을 함께 바꾼다.
   - 넓은 화면(1280x720, 1366x768 iframe)에서는 플레이필드를 가운데 두고 좌우 패널(왼쪽: 파일럿 레벨/XP 바, 최고 점수/최고 생존 시간, 테마 선택 / 오른쪽: 현재 점수, 배수, 시간, 미션)을 둔다. 좁은 화면(390x844)에서는 위 HUD, 미션 줄, 플레이필드 순으로 쌓는다. 어느 크기에서도 오버플로가 없다.
   - 준비 카드, 튜토리얼, 결과 화면, 테마 선택 패널은 같은 네온 스타일(유리 패널, 발광 버튼, 굵은 제목 계층)을 쓴다.
2. 손맛(입력을 막지 않는 연출)
   - 레인 변경 시 우주선이 진행 방향으로 기울고 가로로 찌그러졌다 돌아온다(squash).
   - 니어미스: "Close! +15" 팝업, 황금색 링, 짧은 효과음.
   - 스파크 획득: 파티클 버스트와 "+25" 팝업, 효과음.
   - 배수 버스트: 배수가 x1.5, x2.0, x2.5, x3.0, x3.5에 도달하면 "x2.0" 배너와 링 버스트, 효과음.
   - 충돌: 화면 흔들림, 우주선 파편 산개(shatter), 붉은 플래시. 결과 화면은 파편 연출 뒤에 나타난다(규칙은 즉시 멈춘다).
   - 연출은 하나의 ticker와 repaint 전용 painter로 그린다. 매 프레임 위젯 트리 전체를 다시 만들지 않는다(HUD 값은 바뀔 때만 다시 그린다).
3. 판 안의 목표: 미션 3개
   - 판마다 미션 3개를 제시한다. 종류: N초 생존, 니어미스 N회, 배수 xN 도달, 스파크 N개, 게이트 N개 통과, 점수 N. 목표치는 파일럿 레벨에 따라 커진다. 같은 종류는 한 판에 중복되지 않는다.
   - 판 도중 달성하면 비차단 배너("Mission complete")와 효과음을 내고 XP 보상(미션별 20~40)을 판 결과에 더한다.
4. 판 사이의 동기: 결과 화면, 파일럿 레벨, 테마
   - 결과 화면: 점수, 최고 점수("New best!"), 생존 시간, 니어미스, 최고 배수, 미션 달성 표시, 획득 XP와 레벨 진행 바, 레벨 업과 새로 열린 테마, "Play again" 버튼. Enter/Space로 다시 시작하고 Esc는 결과를 닫고 준비 카드로 돌아간다.
   - 최고 점수(기존 `pulse_drift.best_score`)와 최고 생존 시간을 HUD에 보인다.
   - 파일럿 레벨: 판 점수/10 + 미션 XP + 참여 보너스(5초 이상 생존 시 10)가 XP로 쌓인다. 레벨 L에서 다음 레벨까지 100 + 50 x (L - 1) XP. 테마 해금: Neon Lv1, Sunset Lv3, Aurora Lv6, Void Lv10. 테마는 꾸미기 전용이고 규칙에 영향이 없다. 열린 테마만 고를 수 있다.
   - 진행도는 `shared_preferences` 키 `pulse_drift_progress_v1`(JSON)에 저장한다. 읽기/쓰기 실패나 손상된 값은 초기값으로 대체하고 플레이를 막지 않는다. 저장값을 읽기 전에는 저장하지 않는다(읽기 전에 끝난 판의 XP는 읽은 값에 합친 뒤 저장한다).
5. 소리
   - 배경음악을 신스웨이브 루프(약 120 bpm, 베이스 아르페지오, 패드, 드럼)로 교체한다. `tool/generate_sounds.py`(표준 라이브러리만, 결정적 출력)가 16000 Hz 모노 16비트, 1 MB 이하로 만든다.
   - 새 효과음: 니어미스, 스파크, 배수 버스트, 미션 달성, 레벨 업. 기존 pulse_pass, crash는 유지한다.
   - 음악은 웹에서 첫 사용자 입력 이후 시작, 탭/앱이 숨겨지면 멈춤, 충돌 시 멈추고 다시 하기에서 재개, 전면 광고(모바일 AdMob interstitial) 동안 멈추고 닫힘/실패 콜백 뒤 재개한다. 하나의 소리 토글이 효과음과 음악을 모두 끄고, CrazyGames `muteAudio` 설정을 따른다.
   - iOS/Android 네이티브 채널은 에셋 이름을 받는 `play`, `startLoop`, `stopLoop`, `disposeAudio`로 일반화한다(효과음은 겹쳐 재생, iOS는 오디오 인터럽션 후 음악 재개).

## Acceptance Criteria
- 우주선, 게이트, 스파크, 배경이 4개 테마 모두에서 코드로 그려지고 흰 원/주황 사각형 같은 시제품 표현이 남지 않는다.
- 레인 변경 squash, 니어미스 팝업, 스파크 버스트, 배수 배너, 충돌 흔들림/파편이 재생되고, 연출 중에도 입력은 즉시 처리된다.
- 판마다 미션 3개가 보이고, 조건을 충족하면 완료 표시와 XP 보상이 결과에 반영된다.
- 결과 화면에 점수, 최고 점수, 신기록 여부, 생존 시간, 니어미스, 최고 배수, 획득 XP, 레벨 진행이 보이고, Play again/Enter/Space로 새 판이 시작된다.
- XP, 최고 생존 시간, 선택한 테마, 최고 점수가 앱을 다시 열어도 유지된다. 손상된 저장값은 초기값으로 대체된다.
- 테마는 요구 레벨에 도달하면 열리고 선택한 테마로 그려진다. 잠긴 테마는 고를 수 없다.
- 배경음악은 음소거/숨김/광고 중 멈추고, 돌아오면 다시 재생된다(충돌 후 결과 화면에서는 멈춘 상태).
- 키보드 조작(방향키/A/D, Space/Enter), 준비 카드, 튜토리얼, CrazyGames gameplayStart/Stop, 광고 흐름, GamePix 흐름, GitHub Pages 전용 리더보드 안내(점수 0 초과일 때만)가 기존대로 동작한다. 새 오버레이(결과, 테마)가 열려 있으면 플레이필드 입력은 막히고 Esc/Enter로 닫거나 다시 시작할 수 있다.
- 1280x720, 1366x768, 390x844에서 오버플로 없이 표시된다.
- 기존 테스트(정당한 UI 변경분만 갱신), CrazyGames/GamePix 빌드 자체 검사가 통과한다.

## Constraints
- 새 패키지 의존성을 추가하지 않는다. 그림은 코드로, 소리는 생성기로 만든다.
- lib/ 문자열은 영어 ASCII다(GamePix 빌드 검사). GitHub Pages 전용 결과 등록 문구(한국어)는 기존 그대로 둔다.
- 3레인 회피 규칙, 속도/스폰/점수 계산(`GameBalance`)은 바꾸지 않는다. 컨트롤러에는 연출과 미션용 통계(생존 시간, 스파크 수)와 이벤트 콜백(니어미스, 스파크)만 추가한다.
- GamePix: 외부 요청 없음, 모든 자산 번들. 음악 루프는 16000 Hz 모노 16비트, 1 MB 이하.

## Evidence
- `flutter analyze`, `flutter test`, `flutter test --platform chrome test/web`
- `flutter build web --release --base-href /PulseDrift/`, `tool/build_crazygames.sh`, `tool/build_gamepix.sh`
- 1280x720, 390x844 화면과 결과 화면 렌더 확인(임시 골든 테스트)
- `node <harness-lab>/dist/index.js audit . --format md`
