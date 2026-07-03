import XCTest

/// 핵심 유저 플로우 E2E — 실제 탭으로 게이트 전환(온보딩→로그인→메인)과
/// 냉장고 컨트롤(리포트 배너·정렬·간편보기)을 검증한다.
final class ReffiFlowUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// 온보딩을 처음부터, 게스트/세션 없이 시작.
    private func launchFreshOnboarding() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-resetOnboarding", "-authGate"]
        app.launch()
        return app
    }

    // MARK: 사용자 보고 시나리오 — "나중에 할게요"가 다음 게이트(로그인)로 이어지는가

    func testOnboarding_LaterButton_ReachesLoginThenGuestMain() {
        let app = launchFreshOnboarding()

        // 가치 3장 + 가구 + 취향 = "다음" 5회 → 알림 페이지
        let next = app.buttons["Next"]
        XCTAssertTrue(next.waitForExistence(timeout: 8), "온보딩 첫 페이지가 떠야 한다")
        for _ in 0..<5 {
            next.tap()
        }

        let later = app.buttons["Maybe later"]
        XCTAssertTrue(later.waitForExistence(timeout: 4), "알림 프라이밍 페이지 도달")
        later.tap()

        // 온보딩 종료 → 로그인 게이트
        let guest = app.buttons["Browse without an account"]
        XCTAssertTrue(guest.waitForExistence(timeout: 6), "나중에 할게요 → 로그인 화면으로 전환돼야 한다")
        guest.tap()

        // 게스트 → 메인(하단 네비 노출)
        XCTAssertTrue(app.buttons["Fridge"].waitForExistence(timeout: 6), "게스트 진입 후 메인 탭바가 보여야 한다")
    }

    func testOnboarding_SkipButton_GoesToLogin() {
        let app = launchFreshOnboarding()

        let skip = app.buttons["Skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 8))
        skip.tap()

        XCTAssertTrue(app.buttons["Browse without an account"].waitForExistence(timeout: 6),
                      "건너뛰기 → 로그인 화면으로 전환돼야 한다")
    }

    // MARK: 냉장고 — 요약 카드(리포트·장보기) · 통합 정렬/보기 메뉴

    func testFridge_ReportBand_SortMenu_CompactToggle() {
        let app = XCUIApplication()
        app.launchArguments = ["-skipAuth", "-onboarding.done", "YES", "-fridgeTab"]
        app.launch()

        // 페이저 1장 = 장보기(빈도 우선), 2장 = 무낭비 리포트(스와이프로 진입)
        let toBuy = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Shopping list")).firstMatch
        XCTAssertTrue(toBuy.waitForExistence(timeout: 8), "장보기 카드가 1장이어야 한다")
        toBuy.swipeLeft()

        let report = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open no-waste report")).firstMatch
        XCTAssertTrue(report.waitForExistence(timeout: 4), "스와이프하면 리포트 카드")
        report.tap()
        XCTAssertTrue(app.staticTexts["History"].waitForExistence(timeout: 4), "리포트 카드 → History 시트")
        app.buttons["Close"].firstMatch.tap()

        // 보기 토글(원탭 버튼) — 간편보기 전환(수량 텍스트가 노출되는 행으로 바뀜)
        let toCompact = app.buttons["Switch to simple view"]
        XCTAssertTrue(toCompact.waitForExistence(timeout: 4), "보기 토글 버튼")
        toCompact.tap()
        let compactRow = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "300 g")).firstMatch
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
        XCTAssertTrue(app.staticTexts["Meat · Beef"].waitForExistence(timeout: 4), "스택 카드 복귀")
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
