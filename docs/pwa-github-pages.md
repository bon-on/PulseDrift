# PulseDrift PWA GitHub Pages 배포

## 배포 주소

```text
https://bon-on.github.io/PulseDrift/
```

## 로컬 빌드

```sh
flutter build web --release --base-href /PulseDrift/
```

## 자동 배포

`.github/workflows/deploy-pages.yml`은 테스트 후 `/PulseDrift/` 경로용 web build를 만들고 GitHub Pages에 배포한다.

저장소 Pages source는 GitHub Actions로 설정한다.

## iPhone 설치

Safari에서 배포 주소를 열고 공유 버튼의 `Add to Home Screen`을 선택한다.

PWA는 iOS 앱 서명 만료를 피하지만, Safari/WebKit 저장공간 정책에 따라 캐시 데이터가 정리될 수 있다.
