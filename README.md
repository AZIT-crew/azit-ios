# azit-ios

AZIT(아지트) iOS 웹뷰 shell 앱이에요. `WEB_URL`(기본 `https://azitcrew.com`)을 `WKWebView`로 띄워요.

- 프로젝트 생성: `brew install xcodegen && xcodegen generate`
- 웹 URL 변경: `Resources/*.xcconfig`의 `WEB_URL`
- 딥링크: `azit://schedule/1` → `WEB_URL/schedule/1`, Universal Link `applinks:azitcrew.com`
- 같은 host 외 링크는 외부 앱/브라우저로 열어요
- 상·하단 safe area는 웹이 `env(safe-area-inset-*)`로 처리해요

## 배포

`main`에 푸시하면(`ci:`/`chore:`/`docs:` 커밋 제외) 자동으로 TestFlight 업로드(`deploy.yml`)와 GitHub Release 생성(`release.yml`)이 돌아요.
빌드 번호는 `git rev-list --count HEAD`, 버전은 `Resources/Info.plist`의 `CFBundleShortVersionString`을 써요.

필요한 GitHub Secrets (AZIT 팀 `4U9PQRRKLB`의 App Store Connect API 키):
- `ASC_API_KEY_ID`
- `ASC_API_KEY_ISSUER_ID`
- `ASC_API_KEY_P8_BASE64` (`base64 -i AuthKey_XXXX.p8`)
