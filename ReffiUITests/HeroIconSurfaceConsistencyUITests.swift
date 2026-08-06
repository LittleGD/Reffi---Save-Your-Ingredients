import XCTest

/// 히어로 아이콘 표면 일치(§13.5) — `Recipe.heroIcon` 체인 하나가 **네 표면에서 같은 그림**을 내는지.
///
/// **성격: 스크린샷 스모크다. 아이콘 회귀 게이트가 아니다.**
/// 아이콘 정합성 자체는 유닛 테스트(`ReffiTests/DishGlyphTests`)가 단언한다 — 체인 순서가 흐트러지거나
/// 표면별 값이 갈리면 거기서 빨개진다. 이 파일이 하는 일은 그 계약이 **실기기 렌더까지 살아 있는지**
/// 눈으로 볼 사진을 남기는 것이고, 잘못된 그림이 나와도 **실패로 잡지 못한다** —
/// 아이콘(`DishSilhouette`/`PaperSilhouette`)은 `accessibilityHidden` 장식이라 접근성 트리에
/// 그림 자체가 없다. 여기 단언들은 전부 "그 표면까지 도달했는가"만 본다. 스크린샷은 부산물이 아니라 산출물이다.
///
/// 표면은 넷이다: ① 오더 티켓(축약·펼침, `OrderMemoCard`) ② 조리 화면(`CookingStepsView`)
/// ③ 공유 카드(`RecipeShareCard`) ④ 내 레시피 목록(`MyRecipesView`).
/// 시드 레시피는 통일 전후가 동일하므로(① 매핑 표가 어디서든 이긴다) **커스텀 레시피만 이 수정을
/// 시각 검증한다** — 커스텀 "김밥"은 체인 ②(`FoodGlyph.dishKeywords`)에 걸려 손으로 그린 김밥
/// 단면이 나와야 하고, 통일 전에는 ②③④에서 카탈로그 이름 추론(③)의 아무 색 롤이 나왔다.
///
/// 데이터는 기기에 남은 사용자 데이터를 그대로 쓴다(`-uiTestSampleFridge` 같은 파괴적 리셋 인자 금지).
/// 그래서 **사용자 것은 절대 건드리지 않는다**: 진행 중인 조리 세션이 있으면 취소·교체 어느 쪽도
/// 복원 불가라 `XCTSkip`으로 빠지고(`skipIfCookSessionIsActive`), 레시피 이름엔 사용자의 것과
/// 겹치지 않는 접미사를 붙인다. 만든 것만 되돌린다(`restoreDeviceState(createdRecipe:)`).
final class HeroIconSurfaceConsistencyUITests: XCTestCase {

    /// 체인 ②(요리형 글리프)용 이름 — 사용자의 기존 "김밥" 레시피와 **절대 겹치면 안 된다**.
    /// 겹치면 동명 행이 둘이 되어 `app.buttons[name]`이 다중 매칭으로 깨지고, 뒷정리가 사용자 레시피를
    /// 지운다. 접미사를 붙여도 ②는 그대로 발화한다 — `FoodGlyph.dishGlyph`는 **부분 문자열** 매칭이고
    /// (needle "김밥"이 이름 어딘가에 있으면 적중) 제외 규칙은 `hasSuffix("김")` 하나뿐이다.
    private let menu = "김밥 검증용-XCUI"

    /// 체인 ③(카탈로그 이름 추론)용 이름 — 같은 이유로 접미사를 붙였다. "Stir Fry"가 남아 있어야
    /// `DishGlyphCatalog.keywordRules` 마지막 줄의 니들 "stir fry"에 걸려 `.skillet`이 된다.
    /// 접미사 "XCUI"는 그 앞의 어떤 규칙 니들과도 겹치지 않는다(규칙 표 전수 대조).
    private let stirFryMenu = "Korean Beef Stir Fry XCUI"

    /// 재료 — **기기 냉장고에 실제로 있는 이름을 전부** 적는다. 덱 상위 3장 경쟁에서 이기기 위해서다.
    ///
    /// 티켓 덱은 랭킹 상위 3장만 싣고(`MainView.carouselResults`의 `prefix(3)`), 점수는 쓰는 재료의
    /// 임박 가중치 합(urgent 3 / soon 2 / fresh 1, `RecipeRecommender.weight`) + 취향 보정이다
    /// (`score`). 커스텀 레시피는 `cuisine`이 nil이라 `cuisineBonus`(+2)를 못 받으니 보정은 불리한 쪽이다.
    /// 결정적으로 **AI 티켓이 덱을 열 때마다 새로 생성돼 캐시에 쌓이고**(`FridgeStore.aiRecipes`, 상한 30)
    /// 임박 재료를 대거 끌어다 쓴다 — 실측에서 재료 8종·15점짜리 AI 티켓이 1위였다. 재료 4종(10점)으로
    /// 잡았더니 실제로 상위 3장 밖으로 밀려 테스트가 통째로 스킵됐다.
    /// 냉장고를 통째로 쓰면 그 기기에서 **가능한 최고점**이 된다 — 어떤 시드·AI 레시피도 있지도 않은
    /// 재고를 더 쓸 수는 없으므로 상위 3장 진입이 산술적으로 보장된다(동점이어도
    /// `recipes = userRecipes + aiRecipes + seedRecipes`라 우리 쪽이 앞이고, `missing` 0이라 타이브레이크도 이긴다).
    ///
    /// 그래도 **기기 종속은 남는다** — `RecipeRecommender.rank`의 `.filter { !$0.used.isEmpty }`가
    /// 쓰는 재료를 하나도 안 가진 레시피를 후보에서 통째로 빼므로, 이 이름이 하나도 없는 기기
    /// (초기화된 시뮬레이터·CI)에선 티켓이 아예 안 뜬다. 못 찾으면 실패가 아니라 **XCTSkip**이다
    /// (`frontTicketStub(for:)`). 이 파일은 **재고가 준비된 기기 전용**이다.
    private let ingredientLine =
        "Beef, Spinach, Salmon, Mushroom, Eggs, Tomato, Onion, Cheese, Broccoli, Milk, Carrot, Bread, Dumplings"
    private let stepLines = "Spread the rice over the seaweed sheet.\nRoll it tight and slice into rounds."

    /// 온보딩·로그인 게이트만 통과시킨다(`CookTicketCollapseUITests`의 런치 관례에서 데이터 리셋 인자만 뺀 것).
    private let launchArgs = ["-skipOnboarding", "-skipAuth"]

    /// 덱에서 대상 티켓을 찾기까지 든 왼쪽 플릭(Pass) 횟수 — 리포트용.
    private var passFlicks = 0

    /// **이 테스트가 발주한** 조리 세션의 메뉴명. 뒷정리는 이 이름의 세션만 취소한다 —
    /// nil이면 화면에 조리 세션이 남아 있어도 손대지 않는다(사용자 것이다).
    private var firedOrderMenu: String?

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - 본 시나리오

    func testCustomGimbap_SameHeroIconAcrossFourSurfaces() throws {
        app = launch()

        // 사용자 조리 세션은 손대지 않는다 — 취소도, 발주로 교체하는 것도 복원 불가다.
        try skipIfCookSessionIsActive()

        // 상태를 바꾸기 **전에** 등록한다 — 중간에 실패해도 이 테스트가 만든 것만 되돌린다.
        addTeardownBlock { self.restoreDeviceState(createdRecipe: self.menu) }

        // ── 커스텀 레시피 생성 ─────────────────────────────────────────────
        openMyRecipes()
        createRecipe(named: menu)

        // ── 표면 ④ 내 레시피 목록 ──────────────────────────────────────────
        let row = app.buttons[menu]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "저장한 '\(menu)' 행이 내 레시피 목록에 보여야 한다")
        attachScreenshot(named: "surface4-myrecipes")
        tappable("Close").tap()                       // My recipes 시트 닫기
        goHome()

        // ── 표면 ① 오더 티켓(축약 → 펼침) ──────────────────────────────────
        openTicketDeck()
        attachScreenshot(named: "deck-front-on-open")   // 플릭 전 덱 1순위 — 플릭 횟수의 근거
        let stub = try frontTicketStub(for: menu)
        attachScreenshot(named: "surface1a-ticket-collapsed")
        attachString("passFlicks=\(passFlicks)", named: "deck-flick-count")

        stub.tap()
        XCTAssertTrue(app.staticTexts["ON THE TICKET"].waitForExistence(timeout: 10),
                      "티켓을 탭하면 상세가 펼쳐져야 한다")
        attachScreenshot(named: "surface1b-ticket-expanded")

        // ── 표면 ② 조리 화면 ───────────────────────────────────────────────
        tappable("Cook this").tap()
        XCTAssertTrue(app.staticTexts["ORDER · FIRED"].waitForExistence(timeout: 25),
                      "발주하면 조리 화면(CookingStepsView)이 열려야 한다")
        firedOrderMenu = menu                          // 이제부터 뒷정리가 이 세션을 취소해도 된다
        XCTAssertTrue(app.staticTexts[menu].waitForExistence(timeout: 5),
                      "조리 화면의 메뉴명이 발주한 티켓(\(menu))이어야 한다")
        attachScreenshot(named: "surface2-cooking")

        // ── 표면 ③ 공유 카드 ───────────────────────────────────────────────
        let share = app.buttons["Share"]
        XCTAssertTrue(share.waitForExistence(timeout: 10), "조리 티켓에 Share 버튼이 있어야 한다")
        scrollIntoView(share)
        share.tap()
        XCTAssertTrue(shareSheetAppeared(), "Share를 누르면 공유 시트(프리뷰 썸네일 포함)가 떠야 한다")
        attachScreenshot(named: "surface3-share-sheet")
        XCTAssertTrue(dismissShareSheet(), "공유 시트가 닫혀야 한다")
        // 복귀 확인은 Share 버튼의 hittable로 한다 — 조리 화면 텍스트는 시트 뒤에서도 '존재'하므로
        // 존재 대기로는 시트가 남아 있는 상태와 구분되지 않는다.
        XCTAssertTrue(wait(timeout: 10) { share.isHittable },
                      "시트를 닫으면 조리 화면(Share를 다시 누를 수 있는 상태)으로 돌아와야 한다")

        // ── 보너스: 레시피가 지워져도 세션 폴백이 같은 그림을 유지하는가 ────
        // `CookingStepsView.heroIcon(for:)`은 id로 원본 레시피를 되찾지 못하면 `RecipeHeroIcon.session`
        // 으로 떨어진다. 그 폴백도 체인 ②를 앞세우므로 손으로 그린 김밥이 그대로 남아야 한다.
        tappable("Close").tap()                       // 조리 화면 커버 닫기(세션은 유지)
        goHome()
        openMyRecipes()
        deleteRecipeRow(named: menu)
        XCTAssertTrue(app.buttons[menu].waitForNonExistence(timeout: 10), "'\(menu)'가 목록에서 사라져야 한다")
        tappable("Close").tap()
        goHome()

        let resume = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", menu)).firstMatch
        XCTAssertTrue(resume.waitForExistence(timeout: 10), "레시피를 지워도 Cooking now 카드는 남아야 한다")
        resume.tap()
        XCTAssertTrue(app.staticTexts["ORDER · FIRED"].waitForExistence(timeout: 15),
                      "Cooking now 카드로 조리 화면에 복귀해야 한다")
        attachScreenshot(named: "surface2b-cooking-after-delete")

        // ── 뒷정리(정상 경로) — 예약 재료를 냉장고로 되돌린다 ───────────────
        cancelCookingFromStepsView()
        XCTAssertTrue(app.buttons["Start cooking"].waitForExistence(timeout: 15),
                      "조리를 취소하면 홈으로 돌아와야 한다")
        firedOrderMenu = nil                           // 정상 경로에서 이미 취소했다
    }

    /// 이름 추론(③)이 재료 폴백(④)을 이기는지 — "Korean Beef Stir Fry XCUI"는 시드 매핑 표(①, id 기반이라
    /// 커스텀 레시피의 무작위 UUID엔 애초에 안 걸린다)에도, 요리형 글리프 큐레이션(②, `dishKeywords`는
    /// "김밥" 니들뿐)에도 없어 `Recipe.heroIcon`이 카탈로그 이름 추론(③, `DishGlyphCatalog.keywordArchetype`)
    /// 까지 내려간다. "stir fry" 니들이 `.skillet`(볶음 팬) 원형에 걸리므로(단위 테스트로 이미 증명됨)
    /// 오더 티켓 히어로는 팬 요리 그림이어야 한다 — ③이 없었다면 ④(`Recipe.glyph`)로 떨어져 첫 비상비
    /// 재료(Beef → `.meat`)의 고기 덩어리 글리프가 나왔을 것이다. 재료는 위 시나리오의 `ingredientLine`을
    /// 그대로 재사용해 냉장고 실보유 재료로 랭킹 상위 3장 진입을 그대로 재현한다(클래스 상단 주석 참고).
    ///
    /// 이 테스트는 발주하지 않아 조리 세션을 만들지도 바꾸지도 않는다 — 그래서 세션 스킵 게이트가 없다.
    func testStirFryTicket_ShowsDishIconNotIngredientFallback() throws {
        app = launch()

        // 상태를 바꾸기 **전에** 등록한다 — 공유 teardown이 아니라 이 이름 전용이다.
        addTeardownBlock { self.restoreDeviceState(createdRecipe: self.stirFryMenu) }

        // ── 커스텀 레시피 생성 — 흐름은 본 시나리오와 동일, 이름·니들만 다르다 ─────
        openMyRecipes()
        createRecipe(named: stirFryMenu)

        let row = app.buttons[stirFryMenu]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "저장한 '\(stirFryMenu)' 행이 내 레시피 목록에 보여야 한다")
        tappable("Close").tap()                       // My recipes 시트 닫기
        goHome()

        // ── 오더 티켓 덱에서 찾아 축약 히어로 스크린샷(이 테스트의 산출물) ──────────────────
        openTicketDeck()
        _ = try frontTicketStub(for: stirFryMenu)      // 필요하면 왼쪽 플릭으로 맨 앞까지 순회
        attachScreenshot(named: "stirfry-ticket")
        attachString("passFlicks=\(passFlicks)", named: "stirfry-deck-flick-count")

        // ── 뒷정리(정상 경로) — 덱을 닫고 만든 레시피를 지운다 ─────────────────────────────
        tappable("Close").tap()                       // 티켓 덱 커버 닫기(종이 X, CoverHeader)
        goHome()
        openMyRecipes()
        deleteRecipeRow(named: stirFryMenu)
        XCTAssertTrue(app.buttons[stirFryMenu].waitForNonExistence(timeout: 10),
                      "'\(stirFryMenu)'가 목록에서 사라져야 한다")
        tappable("Close").tap()
        goHome()
    }

    // MARK: - 런치 · 이동

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = launchArgs
        app.launch()
        XCTAssertTrue(app.buttons["Start cooking"].waitForExistence(timeout: 30), "홈까지 도달해야 한다")
        return app
    }

    private func goHome() {
        let home = app.buttons["Home"]
        if home.waitForExistence(timeout: 10), home.isHittable { home.tap() }
        _ = app.buttons["Start cooking"].waitForExistence(timeout: 10)
    }

    /// Profile 탭 → My recipes 시트. 영수증 카드가 다섯 번째라 스크롤이 필요하다.
    private func openMyRecipes() {
        tappable("Profile").tap()
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Custom recipes")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Profile에 My recipes 영수증이 있어야 한다")
        scrollIntoView(row)
        row.tap()
        XCTAssertTrue(app.staticTexts["My recipes"].waitForExistence(timeout: 10), "My recipes 시트가 열려야 한다")
    }

    /// 홈 CTA로 티켓 덱을 연다(`-cookCarousel`은 런치 시점 스냅샷이라 방금 만든 레시피를 못 싣는다).
    private func openTicketDeck() {
        tappable("Start cooking").tap()
        XCTAssertTrue(app.staticTexts["Today's tickets"].waitForExistence(timeout: 25), "티켓 덱이 열려야 한다")
    }

    // MARK: - 레시피 편집기

    private func createRecipe(named name: String) {
        tappable("Add recipe").tap()
        XCTAssertTrue(app.staticTexts["Add recipe"].waitForExistence(timeout: 10), "레시피 편집기가 열려야 한다")

        let field = textInput(placeholder: "Recipe name")
        XCTAssertTrue(field.waitForExistence(timeout: 10), "이름 필드가 있어야 한다")
        type(name, into: field)
        XCTAssertEqual(field.value as? String, name,
                       "이름 필드에 '\(name)'가 그대로 들어가야 한다(글리프 니들과 정확히 맞아야 체인이 발화한다)")

        type(ingredientLine, into: textInput(placeholder: "Onion, Egg, Rice…"))
        type(stepLines, into: textInput(placeholder: "Chop, stir-fry, season…"))

        tappable("Add").tap()   // 도킹 CTA(생성=Add). 캡슐 네비의 ＋와 라벨이 같아 hittable로 가린다.
    }

    /// 목록 카드 롱프레스 → 컨텍스트 메뉴 Delete recipe → 확인 다이얼로그 Delete.
    /// 행 라벨은 `recipe.displayName` 정확 일치라, 고유 접미사가 붙은 테스트 레시피만 집힌다.
    private func deleteRecipeRow(named name: String) {
        let row = app.buttons[name]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "'\(name)' 행이 있어야 삭제할 수 있다")
        row.press(forDuration: 1.2)
        let delete = app.buttons["Delete recipe"]
        XCTAssertTrue(delete.waitForExistence(timeout: 10), "롱프레스로 컨텍스트 메뉴가 떠야 한다")
        delete.tap()
        let confirm = app.buttons["Delete"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 10), "삭제 확인 다이얼로그가 떠야 한다")
        confirm.tap()
    }

    // MARK: - 티켓 덱

    /// 덱 맨 앞에 온 `menu` 티켓의 축약 본문. 앞이 아니면 왼쪽 플릭(Pass)으로 넘긴다.
    /// 라벨은 `"Ticket N: 메뉴명"`이고, 앞 티켓만 히트테스트를 받는다(`allowsHitTesting(isFront)`).
    ///
    /// 덱에 **아예 없으면 실패가 아니라 `XCTSkip`**이다 — 덱 진입은 기기 재고에 종속이라
    /// (클래스 상단 `ingredientLine` 주석) 재료가 없는 기기에선 이 시나리오가 성립하지 않는다.
    /// 반대로 덱에 실려 있는데 앞으로 못 오는 건 재고 문제가 아니라 덱 순환·제스처 회귀라 실패로 잡는다.
    private func frontTicketStub(for menu: String) throws -> XCUIElement {
        let stub = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label ENDSWITH %@", ": \(menu)")).firstMatch
        guard stub.waitForExistence(timeout: 15) else {
            throw XCTSkip("'\(menu)' 티켓이 덱에 없다 — 이 테스트는 재고가 준비된 기기 전용이다"
                          + "(덱은 랭킹 상위 3장만 싣고, 쓰는 재료를 하나도 안 가진 레시피는 후보에서 빠진다)")
        }
        while !stub.isHittable && passFlicks < 15 {
            flickPass()
            passFlicks += 1
            _ = stub.waitForExistence(timeout: 3)
        }
        XCTAssertTrue(stub.isHittable, "\(passFlicks)회 플릭 안에 '\(menu)' 티켓이 맨 앞으로 와야 한다")
        return stub
    }

    /// 왼쪽 플릭 = Pass. 시작점은 **맨 앞 티켓 카드 기준**이다 — 앱 전역 정규화 좌표는 큰 Dynamic Type·
    /// 작은 기기에서 카드를 벗어나 플릭이 덱에 닿지 않는다(선례: `CookTicketCollapseUITests`의
    /// `testTicketDeck_LeftFlick_PassesToNextTicket`, 카드 기준 `dx: 0.9` + 그 이유 주석).
    /// 카드 오른쪽 끝에서 시작해야 플릭 임계(160pt)의 1.5배인 240pt를 밀 폭이 남는다.
    private func flickPass() {
        let cards = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Ticket "))
        var cardEdge: XCUICoordinate?
        for i in 0..<cards.count {
            let card = cards.element(boundBy: i)
            if card.exists, card.isHittable {          // 앞 티켓만 히트테스트를 받는다 = 지금 넘길 카드
                cardEdge = card.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
                break
            }
        }
        // 앞 카드를 못 집는 상태(펼침 등)에선 화면 기준으로 폴백한다.
        let start = cardEdge ?? app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.45))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: -240, dy: 0)))
    }

    // MARK: - 공유 시트

    /// 공유 시트에**만** 있는 시스템 액션 라벨. 앱 안엔 하나도 없다(전수 확인) —
    /// 조리 화면의 종이 X(`PaperCloseButton`, `accessibilityLabel("Close")`)는 시트가 없어도 상시
    /// 존재하므로 판정 근거가 될 수 없다. 그걸 보면 시트가 안 떠도 통과해 표면③ 단언이 무력해진다.
    private static let shareSheetActionLabels =
        ["Copy", "Print", "Save Image", "AirDrop", "Add to Reading List", "Markup"]
    /// `UIActivityViewController` 컨테이너 식별자(iOS 버전에 따라 갈린다).
    private static let shareSheetContainerIDs = ["ActivityListView", "UIActivityContentView"]

    /// 지금 떠 있는 공유 시트 컨테이너(없으면 nil).
    private var shareSheetContainer: XCUIElement? {
        Self.shareSheetContainerIDs.lazy.map { self.app.otherElements[$0] }.first { $0.exists }
    }

    /// 지금 공유 시트가 떠 있는가 — 컨테이너 식별자 또는 시스템 액션 하나라도 보이면 true.
    /// **시트가 없으면 반드시 false여야 한다**(위 주석의 이유).
    private func shareSheetIsUp() -> Bool {
        if shareSheetContainer != nil { return true }
        return shareSheetActions.firstMatch.exists
    }

    private var shareSheetActions: XCUIElementQuery {
        let subpredicates = Self.shareSheetActionLabels.map { NSPredicate(format: "label == %@", $0) }
        return app.descendants(matching: .any)
            .matching(NSCompoundPredicate(orPredicateWithSubpredicates: subpredicates))
    }

    private func shareSheetAppeared() -> Bool {
        if wait(timeout: 20, until: { self.shareSheetIsUp() }) { return true }
        // 안 떴는지 / 식별자가 바뀐 건지는 트리를 봐야 갈린다 — 실패를 진단 가능하게 남긴다.
        attachString(app.debugDescription, named: "share-sheet-missing-hierarchy")
        return false
    }

    /// 공유 시트 닫기 — **앱 전역 "Close" 탭은 절대 쓰지 않는다.**
    /// iOS 26 공유 시트는 화면 **가운데 떠 있는 카드**라 조리 화면 커버의 종이 X(우상단,
    /// `PaperCloseButton`, 같은 라벨 "Close")가 시트와 **동시에 보이고 hittable로 남는다**
    /// (첨부 `surface3-share-sheet` 스크린샷으로 확인). firstMatch도, hittable 필터(`tappable(_:)`)도
    /// 둘을 못 가른다 — 라벨로 고르면 시트 대신 커버가 닫힌다.
    ///
    /// 그래서 ① 시트 컨테이너의 **자손으로 범위를 좁힌** 닫기 버튼(커버의 X는 구조적으로 배제된다)
    /// ② 시트 요소 기준 아래 스와이프 ③ 카드 바깥 탭 순으로 시도한다.
    private func dismissShareSheet() -> Bool {
        // ① 시트가 자기 닫기 버튼을 가진 버전 대비(현재 iOS 26 카드엔 없다).
        if let sheet = shareSheetContainer {
            let close = sheet.descendants(matching: .button)
                .matching(NSPredicate(format: "label == 'Close' OR label == 'Cancel'")).firstMatch
            if close.exists, close.isHittable {
                close.tap()
                if wait(timeout: 5, until: { !self.shareSheetIsUp() }) { return true }
            }
        }

        // ② 시트 **요소 기준** 아래 스와이프 — 카드가 화면 어디에 뜨든 시작점이 카드 위에 온다
        // (앱 전역 정규화 좌표로 잡으면 카드 위쪽 여백에서 시작해 아무 일도 안 일어난다).
        for _ in 0..<2 {
            guard let sheet = shareSheetContainer else { break }
            sheet.swipeDown(velocity: .fast)
            if wait(timeout: 5, until: { !self.shareSheetIsUp() }) { return true }
        }
        if !shareSheetIsUp() { return true }

        // ③ 카드 **바깥** 탭(시스템 시트의 정본 해제). 좌상단을 고르는 이유는 안전이다 —
        // 커버의 종이 X는 우상단, 파괴적 버튼(Finish/Cancel cooking)은 하단이라, 만에 하나 탭이
        // 시트를 뚫고 앱에 닿아도 아무것도 누르지 않는 자리는 여기뿐이다.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.12)).tap()
        if wait(timeout: 5, until: { !self.shareSheetIsUp() }) { return true }

        attachString(app.debugDescription, named: "share-sheet-stuck-hierarchy")
        return false
    }

    // MARK: - 조리 세션

    /// 기기에 조리 세션이 **이미** 있으면 테스트를 건너뛴다. 취소하면 체크 진행·시작 시각이 사라지고
    /// 복원 경로가 없으며, 취소 없이 발주해도 세션이 통째로 교체된다 — 어느 쪽이든 테스트가 만들지 않은
    /// 사용자 데이터를 파괴한다. 판정은 홈의 Cooking now 카드에 있는 `Text(verbatim: "COOKING NOW")`로
    /// 한다(비로컬라이즈 마커라 로케일과 무관하다).
    private func skipIfCookSessionIsActive() throws {
        if app.staticTexts["COOKING NOW"].waitForExistence(timeout: 4) {
            throw XCTSkip("기기에 진행 중인 사용자 조리 세션이 있다 — 취소도 발주 교체도 복원 불가라 건너뛴다"
                          + "(그 조리를 끝내거나 취소한 뒤 다시 실행할 것)")
        }
    }

    /// 조리 화면 하단의 조리 포기 → 확인 다이얼로그. 세션이 사라지면 커버가 스스로 닫힌다.
    private func cancelCookingFromStepsView() {
        let cancel = app.buttons["Cancel cooking, put ingredients back"]
        guard cancel.waitForExistence(timeout: 15) else {
            XCTFail("조리 화면에 조리 포기 경로가 있어야 한다")
            return
        }
        scrollIntoView(cancel)
        cancel.tap()
        let confirm = app.buttons["Cancel cooking"]   // 확인 다이얼로그의 파괴 버튼(트리거와 라벨이 다르다)
        guard confirm.waitForExistence(timeout: 10) else {
            XCTFail("Put ingredients back? 확인 다이얼로그가 떠야 한다")
            return
        }
        confirm.tap()
    }

    // MARK: - 뒷정리 (실패해도 최대한 원복 — 단언하지 않는다)

    /// **이 테스트가 만든 것만** 되돌린다 — ① 이 테스트가 발주한 조리 세션 취소(예약 재료 반납)
    /// ② 이 테스트가 만든 커스텀 레시피 삭제. 사용자 세션과 동명 레시피는 손대지 않는다.
    private func restoreDeviceState(createdRecipe name: String) {
        let app = XCUIApplication()
        app.terminate()
        app.launchArguments = launchArgs
        app.launch()
        self.app = app
        guard app.buttons["Start cooking"].waitForExistence(timeout: 30) else { return }

        // ① 조리 세션 취소 — **이 테스트가 발주한 세션일 때만**. 카드 라벨이 메뉴명을 품는다
        // (`MainView`: "Continue cooking \(cook.recipeName)")라 사용자 세션과 구분된다.
        if let fired = firedOrderMenu {
            let resume = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", fired)).firstMatch
            if resume.waitForExistence(timeout: 4) {
                resume.tap()
                if app.staticTexts["ORDER · FIRED"].waitForExistence(timeout: 15) {
                    let cancel = app.buttons["Cancel cooking, put ingredients back"]
                    if cancel.waitForExistence(timeout: 10) {
                        scrollIntoView(cancel)
                        cancel.tap()
                        let confirm = app.buttons["Cancel cooking"]
                        if confirm.waitForExistence(timeout: 10) { confirm.tap() }
                    }
                }
                _ = app.buttons["Start cooking"].waitForExistence(timeout: 15)
            }
            firedOrderMenu = nil
        }

        // ② 남은 커스텀 레시피 삭제 — 고유 접미사가 붙은 이름이라 사용자 레시피와 겹치지 않는다.
        let profile = app.buttons["Profile"]
        guard profile.waitForExistence(timeout: 6), profile.isHittable else { return }
        profile.tap()
        let receiptRow = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Custom recipes")).firstMatch
        guard receiptRow.waitForExistence(timeout: 10) else { return }
        scrollIntoView(receiptRow)
        receiptRow.tap()
        guard app.staticTexts["My recipes"].waitForExistence(timeout: 10) else { return }
        let row = app.buttons[name]
        if row.waitForExistence(timeout: 4) {
            row.press(forDuration: 1.2)
            let delete = app.buttons["Delete recipe"]
            if delete.waitForExistence(timeout: 8) {
                delete.tap()
                let confirm = app.buttons["Delete"]
                if confirm.waitForExistence(timeout: 8) { confirm.tap() }
            }
        }
        let close = app.buttons["Close"]
        if close.exists, close.isHittable { close.tap() }
    }

    // MARK: - 요소 헬퍼

    /// 같은 라벨이 여러 층에 있을 수 있다(시트 뒤 캡슐 네비의 "Add"/"Close"). **누를 수 있는 것**을 고른다.
    private func tappable(_ label: String, timeout: TimeInterval = 15) -> XCUIElement {
        let query = app.buttons.matching(NSPredicate(format: "label == %@", label))
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            for i in 0..<query.count {
                let candidate = query.element(boundBy: i)
                if candidate.exists, candidate.isHittable { return candidate }
            }
            Thread.sleep(forTimeInterval: 0.25)
        } while Date() < deadline
        XCTFail("누를 수 있는 '\(label)' 버튼을 찾지 못했다")
        return query.firstMatch
    }

    /// 여러 쿼리를 합친 조건이 참이 될 때까지 폴링한다 — `waitForExistence`는 요소 하나만 본다.
    private func wait(timeout: TimeInterval, until condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.25)
        } while Date() < deadline
        return condition()
    }

    /// 플레이스홀더로 텍스트 입력 요소를 찾는다 — `axis: .vertical` TextField는 textView로 노출된다.
    private func textInput(placeholder: String) -> XCUIElement {
        let field = app.textFields[placeholder]
        if field.waitForExistence(timeout: 4) { return field }
        return app.textViews[placeholder]
    }

    private func type(_ text: String, into element: XCUIElement) {
        scrollIntoView(element)
        element.tap()
        element.typeText(text)
    }

    /// 스크롤 컨테이너 안의 요소를 보이는 곳까지 올린다(시트 내부 ScrollView·조리 티켓 공통).
    /// 시도 횟수가 넉넉한 이유: 조리 티켓이 재료 수만큼 길어지고(`ingredientLine`이 냉장고 전체라
    /// 체크 행이 열 몇 개다) Share·조리 포기 버튼은 그 아래에 온다.
    private func scrollIntoView(_ element: XCUIElement, attempts: Int = 12) {
        var tries = 0
        while element.exists, !element.isHittable, tries < attempts {
            app.swipeUp()
            tries += 1
        }
    }

    // MARK: - 첨부

    private func attachScreenshot(named name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func attachString(_ value: String, named name: String) {
        let note = XCTAttachment(string: value)
        note.name = name
        note.lifetime = .keepAlways
        add(note)
    }
}
