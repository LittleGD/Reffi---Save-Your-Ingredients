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
`-glyphGallery.wilted YES` 글리프 갤러리를 전부 **시든 상태**로 렌더(신선 대비 스크린샷용 · `-glyphGallery`와 함께) ·
`-dishGallery` 요리 아이콘 갤러리(시드 레시피 전체를 그리드로 · 라벨은 한글 요리명, `-dishGallery.archetype YES`면 원형 이름) ·
`-showHistory` History 시트 · `-authView` 로그인 화면 · `-onboarding` 온보딩(+`-onboardingPage N`) ·
`-onboardingSetup` 셋업 시트 바로 열기 · `-onboardingSetupPage N` 셋업 시트 특정 장 직행 ·
`-onboardingSetupAutoAdvance` 셋업 시트 장 자동 순환(전환 QA용) ·
`-titleClipLab` StoryScript 줄 끝 글리프 클리핑 실험실(폰트 advance 패치 회귀 검증용) ·
`-tiltLab` 기울기 물리 실험실(하단 X/Y 슬라이더로 홈 재료 더미의 중력 벡터 주입 · 시뮬레이터엔 자이로가 없어 필수) ·
`-tiltLab.x -1..1` `-tiltLab.y -1..1` 시작 중력 벡터 주입(슬라이더를 코드로 못 움직여 컨테인먼트 스크린샷 QA에 필요 · 단독 지정해도 실험실이 켜진다) ·
`-tiltLab.shake` 런치 1.5초 뒤 셰이크 버스트 1회 자동 발동(달그락 햅틱 QA용 · 실험실 패널의 SHAKE 버튼과 동일 · 단독 지정해도 실험실이 켜진다) ·
`-zoneLab` 홈 판정 존(Ate/Tossed 종이 블롭)을 드래그 없이 항상 표시 — 존은 SpriteKit 노드라 접근성 트리에 없고 드래그 중에만 보여서, 배치 회귀를 스크린샷으로 잡으려면 이 경로가 필요하다(§13.6 3-1) ·
`-fridgeExpand` 냉장고 첫 재료 펼침 · `-fridgeExpandSolo` 재료 1개만 남기고 펼침(네비 클리어런스 QA) ·
`-fridge.sortOpen` 정렬 드롭다운(`PaperDropdown`) 자동 오픈(스크린샷용) · `-fridgeEdit` 첫 재료 편집 시트 자동 표시(+`-loadSample`) ·
`-resetOnboarding` 온보딩 초기화 · `-skipOnboarding` 온보딩 건너뛰고 곧장 게이트 통과 ·
`-skipAuth` 게스트로 게이트 통과 · `-authGate` 게스트 해제 ·
`-fridge.compact YES` 간편보기 · `-fridge.sort recent|freshest|expiry` 정렬 ·
`-loadSample` 샘플 시드 · `-previewCarousel` 캐러셀 바로 열기(`-previewAIBadge` 동시 지정 시 AI 배지 티켓도 얹음) ·
`-cookCarousel` 티켓 덱 자동 오픈(축약 상태 · 시드가 없으면 샘플을 스스로 채운다) ·
　└ 한계: `cook()`을 거치지 않아 **AI 힌트·AI 티켓 합류는 재현되지 않는다**(발주·자동 닫기는 정상) ·
`-cookCarousel.expanded` 티켓 덱 오픈 + 앞 티켓 펼친 상태(단독 지정해도 덱이 켜진다) ·
`-cookTicket` 샘플로 강제 발주 후 조리 티켓(CookingStepsView) 바로 열기 ·
`-shareCardPreview` 공유용 레시피 영수증 카드(RecipeShareCard) 미리보기 ·
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
