import XCTest

/// 물리 필드가 **화면 전체 배경**으로 확장된 뒤에도(헤더·배너 뒤까지 재료가 굴러다닌다)
/// 위층 UI의 탭이 그대로 통하는지 — 즉 SpriteView가 제스처를 삼키는 영역이 없는지 검증한다.
///
/// `isHittable`이 이 검증에 정확히 맞는 도구다: 요소 중심점의 히트테스트가 실제로 그 요소에
/// 도달하는지를 보므로, SpriteView가 위에 얹혀 있으면 false가 된다.
final class MainFieldTouchUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchMain() -> XCUIApplication {
        let app = XCUIApplication()
        // 온보딩·로그인 건너뛰고 샘플 냉장고로 고정 — 재료가 있어야 물리 필드가 실제로 깔린다.
        app.launchArguments = ["-skipOnboarding", "-skipAuth", "-uiTestSampleFridge"]
        app.launch()
        return app
    }

    /// 하단 CTA와 탭바 — 물리 필드 바깥이지만 레이어링 회귀의 1차 방어선.
    func testFullScreenField_CTAAndTabBarStayHittable() {
        let app = launchMain()

        let cta = app.buttons["Start cooking"]
        XCTAssertTrue(cta.waitForExistence(timeout: 15), "메인 CTA가 떠야 한다")
        XCTAssertTrue(cta.isHittable, "전체 화면 물리 필드가 요리시작 탭을 삼키면 안 된다")

        for label in ["Home", "Fridge", "Add", "Profile"] {
            let item = app.buttons[label]
            XCTAssertTrue(item.exists, "\(label) 네비 항목이 있어야 한다")
            XCTAssertTrue(item.isHittable, "물리 필드가 \(label) 탭을 삼키면 안 된다")
        }
    }

    /// MORNING ALERTS 배너 버튼 — **물리 필드가 바로 뒤까지 깔린 구간**이라 이 검증이 핵심이다.
    /// 배너는 @AppStorage 상태(이미 본 적 있음/알림 켜짐)에 따라 안 뜰 수 있어, 뜬 경우에만 검증한다.
    func testFullScreenField_AlertBannerButtonsStayHittable() throws {
        let app = launchMain()
        XCTAssertTrue(app.buttons["Start cooking"].waitForExistence(timeout: 15), "메인이 떠야 한다")

        let later = app.buttons["Later"]
        let turnOn = app.buttons["Turn on"]
        try XCTSkipUnless(later.exists && turnOn.exists,
                          "알림 배너가 표시되지 않는 상태(이미 본 적 있음/알림 켜짐) — 건너뜀")

        XCTAssertTrue(turnOn.isHittable, "배너 'Turn on'이 물리 필드에 가려지면 안 된다")
        XCTAssertTrue(later.isHittable, "배너 'Later'가 물리 필드에 가려지면 안 된다")

        // 실제로 눌러서 반응하는지까지 — 히트테스트만으로는 탭이 먹히는지 알 수 없다.
        later.tap()
        XCTAssertTrue(later.waitForNonExistence(timeout: 5),
                      "'Later'를 누르면 배너가 사라져야 한다(탭이 실제로 전달됐다는 증거)")
    }
}
