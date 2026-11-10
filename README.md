# azit-ios

AZIT(아지트) iOS 웹뷰 shell 앱이에요. `WEB_URL`(기본 `https://azitcrew.com`)을 `WKWebView`로 띄워요.

- 프로젝트 생성: `brew install xcodegen && xcodegen generate`
- 웹 URL 변경: `Resources/*.xcconfig`의 `WEB_URL`
- 딥링크: `azit://schedule/1` → `WEB_URL/schedule/1`, Universal Link `applinks:azitcrew.com`
- 같은 host 외 링크는 외부 앱/브라우저로 열어요
- 상·하단 safe area는 웹이 `env(safe-area-inset-*)`로 처리해요
