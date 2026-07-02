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
        let next = app.buttons["다음"]
        XCTAssertTrue(next.waitForExistence(timeout: 8), "온보딩 첫 페이지가 떠야 한다")
        for _ in 0..<5 {
            next.tap()
        }

        let later = app.buttons["나중에 할게요"]
        XCTAssertTrue(later.waitForExistence(timeout: 4), "알림 프라이밍 페이지 도달")
        later.tap()

        // 온보딩 종료 → 로그인 게이트
        let guest = app.buttons["계정 없이 둘러보기"]
        XCTAssertTrue(guest.waitForExistence(timeout: 6), "나중에 할게요 → 로그인 화면으로 전환돼야 한다")
        guest.tap()

        // 게스트 → 메인(하단 네비 노출)
        XCTAssertTrue(app.buttons["Fridge"].waitForExistence(timeout: 6), "게스트 진입 후 메인 탭바가 보여야 한다")
    }

    func testOnboarding_SkipButton_GoesToLogin() {
        let app = launchFreshOnboarding()

        let skip = app.buttons["건너뛰기"]
        XCTAssertTrue(skip.waitForExistence(timeout: 8))
        skip.tap()

        XCTAssertTrue(app.buttons["계정 없이 둘러보기"].waitForExistence(timeout: 6),
                      "건너뛰기 → 로그인 화면으로 전환돼야 한다")
    }

    // MARK: 냉장고 — 리포트 배너 · 정렬 · 간편보기

    func testFridge_ReportBand_SortMenu_CompactToggle() {
        let app = XCUIApplication()
        app.launchArguments = ["-skipAuth", "-onboarding.done", "YES", "-fridgeTab"]
        app.launch()

        // 리포트 배너 → History 시트
        let report = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "무낭비 리포트")).firstMatch
        XCTAssertTrue(report.waitForExistence(timeout: 8), "무낭비 리포트 배너가 보여야 한다")
        report.tap()
        XCTAssertTrue(app.staticTexts["History"].waitForExistence(timeout: 4), "리포트 배너 → History 시트")
        app.buttons["Close"].firstMatch.tap()

        // 간편보기 토글
        let toCompact = app.buttons["간편보기로 전환"]
        XCTAssertTrue(toCompact.waitForExistence(timeout: 4))
        toCompact.tap()
        XCTAssertTrue(app.buttons["스택 보기로 전환"].waitForExistence(timeout: 4), "간편보기 상태로 전환돼야 한다")

        // 정렬 메뉴 — 임박한 순 → 최근 등록순
        let sortMenu = app.buttons["정렬: 임박한 순"]
        XCTAssertTrue(sortMenu.waitForExistence(timeout: 4), "기본 정렬은 임박한 순")
        sortMenu.tap()
        let recent = app.buttons["최근 등록순"]
        XCTAssertTrue(recent.waitForExistence(timeout: 4))
        recent.tap()
        XCTAssertTrue(app.buttons["정렬: 최근 등록순"].waitForExistence(timeout: 4),
                      "정렬 선택이 라벨에 반영돼야 한다")
    }

    // MARK: 로그인 화면 요소

    func testAuthView_ShowsAllEntryPoints() {
        let app = XCUIApplication()
        app.launchArguments = ["-authView"]
        app.launch()

        XCTAssertTrue(app.textFields["Email"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.secureTextFields.firstMatch.exists)
        XCTAssertTrue(app.buttons["Apple로 계속하기"].exists)
        XCTAssertTrue(app.buttons["Google로 계속하기"].exists)
        XCTAssertTrue(app.buttons["계정 없이 둘러보기"].exists)
        XCTAssertTrue(app.buttons["가입하기"].exists, "가입 모드 전환 링크")
    }
}
