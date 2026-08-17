import XCTest

/// 핵심 유저 플로우 E2E — 실제 탭으로 게이트 전환(온보딩→로그인→메인)과
/// 냉장고 컨트롤(리포트 배너·정렬·간편보기)을 검증한다.
final class ReffiFlowUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// 시각 표면은 눈으로 볼 근거를 남긴다 — 탭 패인 셋의 스크린샷을 결과 번들에 붙인다.
    private func attach(_ app: XCUIApplication, named name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// 온보딩을 처음부터 시작. `-skipAuth`로 게스트 상태를 로컬에 고정해, 셋업 완료 후
    /// 메인 진입이 실제 익명 로그인 네트워크 호출에 좌우되지 않고 결정론적으로 검증되게 한다
    /// (게이트 로직 자체는 세션 유무와 무관하게 온보딩 완료 시 곧장 메인으로 보낸다).
    private func launchFreshOnboarding() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-resetOnboarding", "-skipAuth"]
        app.launch()
        return app
    }

    // MARK: 신 플로우 — 인트로(스와이프 전용) → "Let's Start" → 셋업 시트(Next…Maybe later) → 도장 → 메인

    /// 인트로 마지막 장까지 스와이프 → "Let's Start" → 셋업 각 단계를 "Next"로 진행 →
    /// 알림 프라이밍 페이지에서 "Maybe later"로 스킵 → 도장 연출 뒤 로그인 게이트 없이 곧장
    /// 메인(RootTabView, 게스트)에 도달하는지 검증(게스트 우선 플로우).
    func testOnboarding_CompleteSetup_ReachesGuestMain() {
        let app = launchFreshOnboarding()

        // 인트로 진입 확인 — 스플래시("Reffi" 워드마크뿐)와 모호하지 않은 온보딩 전용 요소(Skip)로.
        XCTAssertTrue(app.buttons["Skip"].waitForExistence(timeout: 8), "온보딩 인트로가 떠야 한다")
        XCTAssertTrue(app.descendants(matching: .any)["Intro 1 of 3"].exists, "인트로 1장 인디케이터")
        let letsStart = app.buttons["Let's Start"]
        XCTAssertFalse(letsStart.exists, "인트로 첫 장엔 Let's Start가 없어야 한다(스와이프 전용)")

        // 인트로는 하단 버튼 없이 스와이프 전용 — 페이지 인디케이터 라벨로 이동을 확인.
        app.swipeLeft()
        XCTAssertTrue(app.descendants(matching: .any)["Intro 2 of 3"].waitForExistence(timeout: 4),
                      "스와이프 → 인트로 2장")
        app.swipeLeft()
        XCTAssertTrue(app.descendants(matching: .any)["Intro 3 of 3"].waitForExistence(timeout: 4),
                      "스와이프 → 인트로 3장(마지막)")
        XCTAssertTrue(letsStart.waitForExistence(timeout: 4), "인트로 마지막 장에서 Let's Start 등장")
        letsStart.tap()

        // 셋업 시트(풀스크린) — Step 1(가구)·Step 2(취향)는 "Next"로 진행, 단계는 상단 라벨로 확인.
        let next = app.buttons["Next"]
        XCTAssertTrue(app.staticTexts["Step 1 of 3"].waitForExistence(timeout: 4), "셋업 시트 Step 1 진입")
        next.tap()   // Step 1 → 2
        XCTAssertTrue(app.staticTexts["Step 2 of 3"].waitForExistence(timeout: 4), "Next → Step 2")
        next.tap()   // Step 2 → 3(알림 프라이밍)
        XCTAssertTrue(app.staticTexts["Step 3 of 3"].waitForExistence(timeout: 4), "Next → Step 3(알림)")

        // Step 3(알림 프라이밍) — 실제 권한 프롬프트를 띄우지 않는 "Maybe later" 경로.
        let later = app.buttons["Maybe later"]
        XCTAssertTrue(later.waitForExistence(timeout: 4), "알림 프라이밍 스킵 경로")
        later.tap()

        // "Start" 도장이 0.75초 뒤 onFinish() → 로그인 게이트 없이 곧장 메인(하단 네비 노출).
        XCTAssertTrue(app.buttons["Fridge"].waitForExistence(timeout: 8),
                      "셋업 완료 후 게스트로 메인 탭바에 곧장 도달해야 한다")
    }

    /// 상단 "Skip"(언제든 건너뛰기)은 셋업 시트 없이 즉시 onFinish() → 로그인 게이트 없이
    /// 곧장 메인(게스트)에 도달해야 한다.
    func testOnboarding_SkipButton_ReachesGuestMain() {
        let app = launchFreshOnboarding()

        let skip = app.buttons["Skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 8), "인트로 상단 Skip 버튼")
        skip.tap()

        XCTAssertTrue(app.buttons["Fridge"].waitForExistence(timeout: 8),
                      "건너뛰기 → 게스트로 메인 탭바에 곧장 도달해야 한다")
    }

    // MARK: 냉장고 — 상단 탭 셋(In stock · To buy · History) · 통합 정렬/보기 메뉴

    /// 탭 행이 화면의 IA다: 세 알약이 처음부터 다 보이고, 탭하면 아래 콘텐츠가 갈리며,
    /// 선택 상태가 알약에 남는다. 옛 요약 두 버튼·헤더 리포트 버튼(커버 진입)은 여기서 사라졌다.
    func testFridge_ThreeTabs_SwitchPanes_SortMenu_CompactToggle() {
        let app = XCUIApplication()
        // -uiTestSampleFridge: 기기에 남은 사용자 데이터와 무관하게 샘플 냉장고로 고정(결정적 상태).
        app.launchArguments = ["-skipAuth", "-onboarding.done", "YES", "-fridgeTab", "-uiTestSampleFridge"]
        app.launch()

        let stockTab = app.buttons["In stock"]
        let toBuyTab = app.buttons["To buy"]
        let historyTab = app.buttons["History"]

        // 세 탭 모두 스와이프 없이 처음부터 보이고 눌린다(커버 뒤에 숨는 목적지가 없다).
        XCTAssertTrue(stockTab.waitForExistence(timeout: 8), "In stock 탭")
        XCTAssertTrue(toBuyTab.waitForExistence(timeout: 4), "To buy 탭")
        XCTAssertTrue(historyTab.waitForExistence(timeout: 4), "History 탭")
        XCTAssertTrue(stockTab.isHittable && toBuyTab.isHittable && historyTab.isHittable,
                      "세 탭 모두 바로 누를 수 있어야 한다")

        // 기본 탭 = In stock. 선택 상태가 알약에만 남는다(§13.5 — 탭은 내비라 선택이 잉크 솔리드).
        XCTAssertTrue(stockTab.isSelected, "기본 탭은 In stock이어야 한다")
        XCTAssertFalse(toBuyTab.isSelected, "선택은 하나뿐")
        XCTAssertFalse(historyTab.isSelected, "선택은 하나뿐")
        // In stock 패인의 고유 콘텐츠 — 영수증 스택과 목록 조작 크롬.
        XCTAssertTrue(app.staticTexts["Beef"].waitForExistence(timeout: 4), "재고 영수증 카드")
        XCTAssertTrue(app.buttons["Sort: Expiring first"].exists, "재고 패인의 정렬 칩")
        attach(app, named: "fridge-tab-in-stock")

        // To buy 탭 — 하단 도킹 "Add item"과 행별 Add/Skip이 커버 때 그대로 살아 있다.
        toBuyTab.tap()
        XCTAssertTrue(app.buttons["Add item"].waitForExistence(timeout: 4), "To buy 패인의 직접 담기 CTA")
        XCTAssertFalse(app.buttons["Sort: Expiring first"].exists, "재고 패인 크롬은 함께 사라져야 한다")
        XCTAssertTrue(toBuyTab.isSelected, "탭하면 선택 상태가 옮겨간다")
        XCTAssertFalse(stockTab.isSelected, "직전 탭의 선택은 풀린다")
        attach(app, named: "fridge-tab-to-buy")

        // History 탭 — 정산서는 도넛이 아니라 영수증(§13.9): 두 행·낭비율 도장·자주 버린 재료.
        historyTab.tap()
        XCTAssertTrue(app.staticTexts["Tally · past 30 days"].waitForExistence(timeout: 4),
                      "History 패인의 첫 카드는 30일 정산서다")
        XCTAssertFalse(app.buttons["Add item"].exists, "To buy 패인의 CTA는 함께 사라져야 한다")
        XCTAssertTrue(historyTab.isSelected, "History가 선택된다")
        attach(app, named: "fridge-tab-history")

        // 다시 In stock — 패인 왕복 뒤에도 목록 조작 크롬이 그대로 돌아온다.
        stockTab.tap()
        XCTAssertTrue(stockTab.isSelected, "In stock으로 복귀")
        XCTAssertTrue(app.staticTexts["Beef"].waitForExistence(timeout: 4), "재고 영수증 카드 복귀")

        // 보기 토글(원탭 버튼) — 간편보기 전환(수량 텍스트가 노출되는 행으로 바뀜)
        let toCompact = app.buttons["Switch to simple view"]
        XCTAssertTrue(toCompact.waitForExistence(timeout: 4), "보기 토글 버튼")
        toCompact.tap()
        let compactRow = app.descendants(matching: .any)
            // 수량은 숫자와 단위를 줄바꿈 없는 공백으로 묶는다(Quantity.text) — 일반 공백으로 찾으면 안 걸린다.
            .matching(NSPredicate(format: "label CONTAINS %@", "300\u{00A0}g")).firstMatch
        XCTAssertTrue(compactRow.waitForExistence(timeout: 4), "간편보기 행(수량 노출)로 전환")

        // 정렬 메뉴(정렬 전용) — 전환이 라벨에 반영
        let menu = app.buttons["Sort: Expiring first"]
        XCTAssertTrue(menu.waitForExistence(timeout: 4), "기본 정렬은 임박한 순")
        menu.tap()
        app.buttons["Recently added"].tap()
        XCTAssertTrue(app.buttons["Sort: Recently added"].waitForExistence(timeout: 4),
                      "정렬 선택이 라벨에 반영돼야 한다")

        // 상태 원복(스택 보기·임박한 순) — 테스트가 기기 저장 상태를 오염시키지 않게.
        app.buttons["Switch to stack view"].tap()
        XCTAssertTrue(app.staticTexts["Beef"].waitForExistence(timeout: 4), "스택 카드 복귀")
        app.buttons["Sort: Recently added"].tap()
        app.buttons["Expiring first"].tap()
        XCTAssertTrue(app.buttons["Sort: Expiring first"].waitForExistence(timeout: 4), "기본 정렬 복귀")
    }

    // MARK: 로그인 화면 요소

    func testAuthView_ShowsAllEntryPoints() {
        let app = XCUIApplication()
        app.launchArguments = ["-authView"]
        app.launch()

        XCTAssertTrue(app.textFields["Email"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.secureTextFields.firstMatch.exists)
        XCTAssertTrue(app.buttons["Continue with Apple"].exists)
        XCTAssertTrue(app.buttons["Continue with Google"].exists)
        XCTAssertTrue(app.buttons["Browse without an account"].exists)
        XCTAssertTrue(app.buttons["Sign up"].exists, "가입 모드 전환 링크")
    }
}
