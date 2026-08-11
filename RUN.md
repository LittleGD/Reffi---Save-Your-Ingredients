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
# 주의: DerivedData에 Reffi-<해시> 폴더가 여러 개 남아 있을 수 있다(xcodegen 재생성 시 해시가 바뀜).
# head -1은 무엇이 걸릴지 보장이 없어 몇 주 전 빌드를 집을 수 있다 — 반드시 실행 바이너리 mtime 최신순으로 고른다.
APP=$(ls -td ~/Library/Developer/Xcode/DerivedData/Reffi-*/Build/Products/Debug-iphonesimulator/Reffi.app 2>/dev/null | while read -r a; do echo "$(stat -f '%m' "$a/Reffi") $a"; done | sort -rn | head -1 | cut -d' ' -f2-)
xcrun simctl install booted "$APP"
xcrun simctl launch booted com.reffi.app

# 스크린샷
xcrun simctl io booted screenshot reffi-home.png
```

### QA 런치 인자 (DEBUG)
전부 `#if DEBUG` 경로다(릴리스 빌드엔 없다). 정본은 소스의 `ProcessInfo.processInfo.arguments` 분기 —
새 인자를 추가하면 이 목록도 같이 갱신한다.

**전용 루트 화면**(`ReffiApp.rootContent` — 아래 인자 하나만 주면 앱 대신 그 화면이 뜬다. 위에서부터 우선)
- `-glyphGallery` 전 글리프 그리드 · `-titleClipLab` StoryScript 줄 끝 글리프 클리핑 실험실(폰트 advance 패치 회귀 검증)
- `-shareCardPreview` 공유용 레시피 영수증 카드(`RecipeShareCard`) 미리보기 · `-myRecipesPreview` 커스텀 레시피 목록/편집
- `-glyphMetrics` 글리프 알파 bbox 실측(물리 바디 파라미터 재계측) · `-buttonGallery` 버튼 갤러리 · `-authView` 로그인 화면

**게이트 · 인증**
- `-onboarding` 온보딩 처음부터(초기화 + 정상 진입) · `-resetOnboarding` 온보딩 초기화만
- `-skipOnboarding` 온보딩 건너뛰고 곧장 게이트 통과 · `-onboarding.done YES` 온보딩 완료 플래그 직접 주입(UserDefaults 인자)
- `-onboardingPage N` 인트로 N장 직행 · `-onboardingSetup` 셋업 시트 바로 열기 · `-onboardingSetupPage N` 셋업 N장 직행
- `-onboardingSetupAutoAdvance` 셋업 장 자동 순환(전환 QA용)
- `-skipAuth` 게스트로 게이트 통과 · `-authGate` 게스트 해제 (인증 콘솔 설정은 `docs/AUTH_SETUP.md`)

**탭 · 데이터**
- `-fridgeTab` `-profileTab` 탭 직행 · `-profileBottom` 프로필 하단(Data·Account)까지 스크롤
- `-loadSample` 샘플 시드(첫 실행 = 데이터 전무일 때만) · `-uiTestSampleFridge` 샘플 냉장고 **강제** 리셋 + 냉장고 보기 기본값 복원(UI 테스트 전용)

**메인 (물리 씬 · 티켓)**
- `-previewCarousel` 추천 캐러셀 바로 열기 · `-previewAdd` 재료 추가 시트 바로 열기
- `-cookTicket` 샘플로 강제 발주 후 조리 티켓(`CookingStepsView`) 바로 열기
- `-tiltLab` 기울기 실험실 하단 오버레이 — X/Y 슬라이더로 씬 중력을 직접 주입한다. 시뮬레이터엔 자이로가 없어 굴러가는 모양·컨테인먼트 QA는 사실상 이 경로로만 가능하다. SHAKE 버튼 + `HAPTIC n/s` 카운터(햅틱 하드웨어가 없으니 발화 수가 유일한 관측 수단 — 정지한 더미에서 0으로 떨어지는지도 여기서 본다)
- `-tiltLab.x <-1…1>` `-tiltLab.y <-1…1>` 중력 방향 주입(실험실도 함께 켜짐). 값 파싱은 `ProcessInfo.arguments` 직접 순회 — UserDefaults 인자로 두면 `-tiltLab.x -0.9`의 음수를 다음 키로 오인해 바인딩을 통째로 잃는다
- `-tiltLab.shake` 런치 1.5초 뒤 셰이크 버스트 자동 발동(재료가 자리를 잡은 뒤라야 충돌이 의미 있다)
- `-zoneLab` 판정 존(휴지통·냄비) 상시 표시 — 존은 SpriteKit 노드라 접근성 트리에 없고 드래그 중에만 보여서, 위치 회귀를 스크린샷으로 잡으려면 강제 표시가 필요하다

**냉장고**
- `-showHistory` History 커버 · `-fridgeExpand` 첫 재료 펼침 · `-fridgeExpandSolo` 재료 1개만 남기고 펼침(네비 클리어런스 QA)
- `-fridgeEdit` 첫 재료 편집 시트(+`-loadSample`) · `-fridge.sortOpen` 정렬 드롭다운(`PaperDropdown`) 자동 오픈
- `-fridge.compact YES` 간편보기 · `-fridge.sort recent|freshest|expiry` 정렬 (둘 다 `@AppStorage` 키를 덮는 UserDefaults 인자)

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
