# Reffi — 실행 가이드

냉장고 속 임박 재료를 오늘 먹게 만드는 iOS 앱. 이 빌드는 **홈 화면 + 하단 네비**(나머지 탭 플레이스홀더) + 샘플 데이터.

## 요구 사항
- **Xcode 26.x** (이 코드는 26.5 / Swift 6.3.2에서 작성)
- **iOS 26.x 시뮬레이터 런타임** — *이 머신엔 26.2/26.4만 있고 26.5가 없어 빌드가 막혔습니다.*
  설치: **Xcode › Settings › Components**에서 iOS 런타임 추가, 또는
  ```sh
  xcodebuild -downloadPlatform iOS        # iOS 26.5 런타임 내려받기
  ```
- **XcodeGen** (프로젝트 생성용): `brew install xcodegen`

## 프로젝트 생성 · 열기
`Reffi.xcodeproj`는 **`project.yml`에서 생성**됩니다(정본은 project.yml, .xcodeproj는 .gitignore).
```sh
cd /Users/jmlee/Documents/Reffi
xcodegen generate
open Reffi.xcodeproj      # Xcode에서 Run(⌘R)
```

## CLI 빌드 · 실행 · 스크린샷 (런타임 설치 후)
```sh
# xcode-select가 CommandLineTools를 가리키면 DEVELOPER_DIR로 우회(sudo 불필요)
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

# 빌드
xcodebuild -project Reffi.xcodeproj -scheme Reffi \
  -destination 'platform=iOS Simulator,name=iPhone 17' build

# 시뮬레이터에 설치 후 실행
xcrun simctl boot "iPhone 17" || true
open -a Simulator
APP=$(find ~/Library/Developer/Xcode/DerivedData/Reffi-*/Build/Products/Debug-iphonesimulator -name 'Reffi.app' | head -1)
xcrun simctl install booted "$APP"
xcrun simctl launch booted com.reffi.app

# 스크린샷
xcrun simctl io booted screenshot reffi-home.png
```

### QA 런치 인자 (DEBUG)
`-glyphGallery` `-buttonGallery` 갤러리 · `-profileTab` `-fridgeTab` 탭 직행 ·
`-showHistory` History 시트 · `-authView` 로그인 화면 · `-onboarding` 온보딩(+`-onboardingPage N`) ·
`-resetOnboarding` 온보딩 초기화 · `-skipOnboarding` 온보딩 건너뛰고 곧장 게이트 통과 ·
`-skipAuth` 게스트로 게이트 통과 · `-authGate` 게스트 해제 ·
`-fridge.compact YES` 간편보기 · `-fridge.sort recent|freshest|expiry` 정렬 ·
`-loadSample` 샘플 시드 · `-previewCarousel` 캐러셀 바로 열기(`-previewAIBadge` 동시 지정 시 AI 배지 티켓도 얹음) ·
`-profileAI` Profile을 AI recipes 영수증까지 스크롤
(인증 콘솔 설정은 `docs/AUTH_SETUP.md`)

## 기술 스택
- **SwiftUI / Swift 6.3** · 배포 타깃 **iOS 18+** · 데이터는 `@Observable` + 샘플(SwiftData는 다음 단계)
- **폰트**(전부 SIL OFL, 번들): Pretendard(한글·본문) / Google Sans Flex(데이터 숫자) / Story Script(워드마크)
- **아이콘**: Phosphor `PhosphorSwift` 2.1.0 (SPM, MIT)
- **색**: OKLCH 정본 → 런타임 sRGB 변환(`ReffiColor`), hex 미사용

## 구조
```
project.yml                  XcodeGen 정의
Reffi/
  ReffiApp.swift             앱 엔트리(+ 폰트 등록 확인)
  DesignSystem/              Color(OKLCH)·Typography(DynamicType)·Layout·Elevation·Motion
  Models/                    Ingredient·Freshness·Recipe·AlternativeAction
  Data/                      SampleData·RecipeRecommender·FridgeStore(@Observable)
  Components/                ReffiIcon·FoodMotif(색면 음식 일러스트)·Chips·PillButton·PlaceholderScreen
  Features/Home/             HomeView·RecipeBannerView·IngredientStackView·StackCardView·ExpandedIngredientCard
  Features/Fridge · MyPage · AddIngredient
  Navigation/RootTabView     홈·냉장고·중앙＋·마이
  Resources/Fonts · Assets.xcassets
```

## 검증 상태
- 전체 27개 소스 **`swiftc -typecheck` 통과**(에러 0). Phosphor는 동일 시그니처로 대체해 타입 검증, 실제 케이스명·API는 사전 확인.
- **전체 빌드/실행/스크린샷은 iOS 26.x 런타임 설치 후 위 명령으로 진행.**
