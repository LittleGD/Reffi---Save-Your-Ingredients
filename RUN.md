# Reffi — 실행 가이드

냉장고 속 임박 재료를 오늘 먹게 만드는 iOS 앱. 메인(물리 낙하 필드 · 티켓 덱) · 냉장고 · 마이 세 탭이 모두 실동작한다.

## 요구 사항
- **Xcode 26.x** (이 코드는 26.5 / Swift 6.3.2에서 작성)
- **iOS 26.x 시뮬레이터 런타임** — 이 머신엔 26.2 / 26.4 / 26.5가 설치돼 있다.
  없을 때 설치: **Xcode › Settings › Components**에서 iOS 런타임 추가, 또는
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
- `-glyphGallery` 전 글리프 그리드. `-glyphGallery.wilted YES`면 모든 타일을 `.urgent`로 고정해 시듦 A/B 콘택트 시트를 찍는다 · `-titleClipLab` StoryScript 줄 끝 글리프 클리핑 실험실(폰트 advance 패치 회귀 검증)
- `-dishGallery` 시드 레시피 전체를 요리 아이콘 그리드로(§13.7 히어로 체인 검증). `-dishGallery.archetype YES`면 라벨이 요리명 대신 **원형 이름**(클러스터 분포 확인용). 스크롤 화면이라 스크린샷은 첫 판만 담는다 — 80개 전수 대조는 오프스크린 콘택트 시트(`ReffiTests/DishContactSheetTests`)가 맡는다
- `-shareCardPreview` 공유용 레시피 영수증 카드(`RecipeShareCard`) 미리보기 · `-myRecipesPreview` 커스텀 레시피 목록/편집 — 목록이 비어 있으면 시드 앞 5개를 커스텀으로 복제해 채운다(새 UUID라 요리 아이콘이 **폴백 경로**를 탄다 = 실제 커스텀 레시피와 같은 조건). ⚠️ 복제본은 **실제 스토어에 영속 저장**된다 — 이 인자를 준 설치는 이후 정상 런치에서도 그 5개를 커스텀 레시피로 계속 들고 있고, 되돌리려면 MyPage에서 하나씩 지우거나 샘플을 다시 불러와야 한다
- `-glyphMetrics` 글리프 알파 bbox 실측(물리 바디 파라미터 재계측) · `-buttonGallery` 버튼 갤러리 · `-authView` 로그인 화면

**게이트 · 인증**
- `-onboarding` 온보딩 처음부터(초기화 + 정상 진입) · `-resetOnboarding` 온보딩 초기화만
- `-skipOnboarding` 온보딩 건너뛰고 곧장 게이트 통과 · `-onboarding.done YES` 온보딩 완료 플래그 직접 주입(UserDefaults 인자)
- `-onboardingPage N` 인트로 N장 직행 · `-onboardingSetup` 셋업 시트 바로 열기 · `-onboardingSetupPage N` 셋업 N장 직행
- `-onboardingSetupAutoAdvance` 셋업 장 자동 순환(전환 QA용)
- `-skipAuth` 게스트로 게이트 통과 · `-authGate` 게스트 해제 (인증 콘솔 설정은 `docs/AUTH_SETUP.md`)
- `-resetNickname` 저장된 닉네임을 미설정 취급 — 이번 런치에서 곧장 자동 닉네임 생성을 재현(`NicknameGenerator` QA)

**탭 · 데이터**
- `-fridgeTab` `-profileTab` 탭 직행 · `-profileBottom` 프로필 하단(Data·Account)까지 스크롤
- `-loadSample` 샘플 시드(첫 실행 = 데이터 전무일 때만) · `-uiTestSampleFridge` 샘플 냉장고 **강제** 리셋 + 냉장고 보기 기본값 복원(UI 테스트 전용)

**메인 (물리 씬 · 티켓)**
- `-previewCarousel` 추천 캐러셀 바로 열기 · `-previewAdd` 재료 추가 시트 바로 열기
- `-cookCarousel` 티켓 덱 자동 오픈(플릭 방향 의미론 UI 테스트가 쓴다). ⚠️ `store.available`(예약 제외 재고)이 비어 있으면 `loadSampleData()`를 부른다 — **추가가 아니라 전체 대체**다: 조리 세션이 모든 재료를 예약 중이거나 냉장고만 비고 이력·장보기 메모가 남은 상태에서 단독으로 주면 그 데이터가 되돌릴 수 없이 지워진다. UI 테스트는 `-uiTestSampleFridge`와 같이 주므로 그 경로에선 무동작
- `-cookTicket` 샘플로 강제 발주 후 조리 티켓(`CookingStepsView`) 바로 열기
- `-tiltLab` 기울기 실험실 하단 오버레이 — X/Y 슬라이더로 씬 중력을 직접 주입한다. 시뮬레이터엔 자이로가 없어 굴러가는 모양·컨테인먼트 QA는 사실상 이 경로로만 가능하다. SHAKE 버튼 + `HAPTIC n/s` 카운터(햅틱 하드웨어가 없으니 발화 수가 유일한 관측 수단 — 정지한 더미에서 0으로 떨어지는지도 여기서 본다)
- `-tiltLab.x <-1…1>` `-tiltLab.y <-1…1>` 중력 방향 주입(실험실도 함께 켜짐). 값 파싱은 `ProcessInfo.arguments` 직접 순회 — UserDefaults 인자로 두면 `-tiltLab.x -0.9`의 음수를 다음 키로 오인해 바인딩을 통째로 잃는다
- `-tiltLab.shake` 런치 1.5초 뒤 셰이크 버스트 자동 발동(재료가 자리를 잡은 뒤라야 충돌이 의미 있다)
- `-zoneLab` 판정 존(휴지통·냄비) 상시 표시 — 존은 SpriteKit 노드라 접근성 트리에 없고 드래그 중에만 보여서, 위치 회귀를 스크린샷으로 잡으려면 강제 표시가 필요하다

**냉장고**
- `-showHistory` History 커버 · `-fridgeExpand` 첫 재료 펼침 · `-fridgeExpandSolo` 재료 1개만 남기고 펼침(네비 클리어런스 QA)
- `-fridgeEdit` 첫 재료 편집 시트(+`-loadSample`) · `-fridge.sortOpen` 정렬 드롭다운(`PaperDropdown`) 자동 오픈
- `-fridge.compact YES` 간편보기 · `-fridge.sort recent|freshest|expiry` 정렬 (둘 다 `@AppStorage` 키를 덮는 UserDefaults 인자)
- `-toBuy` To buy 커버 직행(`-fridgeTab`·`-loadSample`과 함께) · `-toBuy.search` 재료 검색 바텀시트까지 자동 오픈(단독 지정해도 커버가 열린다 — 커버 전환과 같은 프레임에 시트를 올리면 씹혀서 전환 뒤로 미룬다)

**테스트 환경변수**(런치 인자가 아니라 `xcodebuild test`에 주는 값)
- `REFFI_CONTACT_SHEET=1` 요리 아이콘 콘택트 시트 산출 — 없으면 해당 두 @Test는 단언만 하고 렌더·파일 쓰기를 건너뛴다(아래 "검증 상태")
- `DISH_SHEET_DIR` 시트 저장 디렉터리(없으면 시뮬레이터 tmp)

## 기술 스택
- **SwiftUI / Swift 6.3** · 배포 타깃 **iOS 18+** · 데이터는 `@Observable` + 샘플(SwiftData는 다음 단계)
- **폰트**(전부 SIL OFL, 번들): Pretendard(한글·본문) / Google Sans Flex(데이터 숫자) / Story Script(워드마크)
- **아이콘**: Phosphor `PhosphorSwift` 2.1.0 (SPM, MIT)
- **색**: OKLCH 정본 → 런타임 sRGB 변환(`ReffiColor`), hex 미사용

## 구조
```
project.yml                  XcodeGen 정의
Reffi/
  ReffiApp.swift             앱 엔트리(+ 폰트 등록 확인, 전용 루트 QA 화면 분기)
  DesignSystem/              Color(OKLCH)·Typography(DynamicType)·Layout·Elevation·Motion
  Models/                    Ingredient(FoodGlyph)·Freshness·Recipe·RemovalLog·NicknameGenerator
  Data/                      IngredientLexicon·RecipeCatalog·RecipeRecommender·FridgeStore/ProfileStore(@Observable)
  Components/                ReffiIcon·FoodMotif·PaperButton/PaperCloseButton·PaperDropdown·UndoToast
  Features/Main/             MainView·IngredientDropScene(SpriteKit)·PaperSilhouette·WiltStyle·GravityMapper
  Features/Recipes/          RecipeMemoCarousel(티켓 덱)·OrderMemoCard(단서 카드)·CookingStepsView·RecipeShareCard
  Features/Fridge · MyPage · AddIngredient · Onboarding · Auth
  Navigation/RootTabView     메인·냉장고·중앙＋·마이
  Resources/Fonts · ingredient-lexicon.json · recipes seed · Localizable.xcstrings
```

## 검증 상태
- **빌드 통과**(iPhone 17 / iOS 26.5 시뮬레이터) — 위 `xcodebuild build` 명령 그대로.
- **유닛 192 / UI 10 전부 통과**:
  ```sh
  xcodebuild -project Reffi.xcodeproj -scheme Reffi \
    -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:ReffiTests
  xcodebuild -project Reffi.xcodeproj -scheme Reffi \
    -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:ReffiUITests
  ```
- **요리 아이콘 콘택트 시트**(검증이 아니라 산출 도구라 기본 스킵) — `REFFI_CONTACT_SHEET=1`을
  줄 때만 PNG를 굽는다. 저장 위치는 `DISH_SHEET_DIR`(없으면 시뮬레이터 tmp), 경로는 콘솔에 찍힌다:
  ```sh
  REFFI_CONTACT_SHEET=1 DISH_SHEET_DIR=/tmp/reffi-sheets \
  xcodebuild -project Reffi.xcodeproj -scheme Reffi \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    test -only-testing:ReffiTests/DishContactSheetTests
  ```
