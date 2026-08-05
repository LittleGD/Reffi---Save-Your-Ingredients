import XCTest

/// 오더 티켓 축약↔펼침(§13.5) — 덱 앞 티켓은 **음식 아이콘 + 메뉴명만** 보이는 축약 본문으로 열리고,
/// 끌어올리거나 탭해야 상세(ON THE TICKET 체크리스트 · Cook this 발주 CTA)가 나타난다.
/// 카드 크기는 두 상태가 같고 바뀌는 건 콘텐츠뿐이다.
///
/// 계약은 넷이다: ① 축약이 기본값 ② 펼침 트리거가 실제로 상세를 켠다 ③ **축이 갈리지 않은 드래그는
/// 아무 것도 커밋하지 않는다** ④ 펼친 본문(내부 ScrollView) 위 **수평 플릭이 덱 넘김에 도달한다**.
/// ③④는 제스처 중재를 덱 한 곳(`RecipeMemoCarousel.frontDrag`)으로 모은 뒤의 회귀 방지선이다.
final class CookTicketCollapseUITests: XCTestCase {

    /// 커밋 임계(`RecipeMemoCarousel.expandCommit`, 예측 변위 56pt)와 플릭 임계(160pt).
    /// 아래 드래그 벡터는 전부 **앱 좌표계 절대 오프셋(pt)** 이라 요소 프레임·Dynamic Type이 바뀌어도
    /// 실제 이동량이 따라 변하지 않는다(정규화 오프셋 배수를 쓰면 임계 대비 마진이 조용히 달라진다).
    private let expandCommit: CGFloat = 56
    private let flickCommit: CGFloat = 160

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// `-cookCarousel`: 온보딩·로그인을 건너뛰고 샘플 냉장고로 고정한 뒤 티켓 덱을 자동 오픈한다
    /// (`-uiTestSampleFridge`로 기기에 남은 사용자 데이터와 무관한 결정적 상태를 만든다).
    private func launchDeck() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-skipAuth", "-uiTestSampleFridge", "-cookCarousel"]
        app.launch()
        return app
    }

    /// N번 티켓의 축약 본문. 라벨이 `"Ticket N: 메뉴명"`이라 덱에 겹친 티켓들이 번호로 구분된다
    /// (덱은 랭킹 1위를 앞에 두고 열린다). **맨 앞인지**는 `isHittable`로 따로 확인한다 —
    /// 앞 티켓만 `allowsHitTesting(true)`이기 때문이다.
    private func ticketStub(_ app: XCUIApplication, number: Int) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Ticket \(number):")).firstMatch
    }

    func testTicketDeck_OpensCollapsed_TapRevealsDetails() {
        let app = launchDeck()

        // 덱이 실제로 열렸는지 — 커버 헤더 타이틀로 확인(빈 상태면 티켓 자체가 없다).
        XCTAssertTrue(app.staticTexts["Today's tickets"].waitForExistence(timeout: 20),
                      "요리 시작 없이도 -cookCarousel로 티켓 덱이 열려야 한다")

        // (a) 축약 — 앞 티켓은 메뉴명(축약 본문)만 보이고, 상세 섹션은 아직 없다.
        let stub = ticketStub(app, number: 1)
        XCTAssertTrue(stub.waitForExistence(timeout: 8), "앞 티켓은 큰 메뉴 이름이 보이는 축약 본문이어야 한다")
        XCTAssertFalse(app.staticTexts["ON THE TICKET"].exists,
                       "축약 상태엔 재료 체크리스트 섹션이 없어야 한다")
        XCTAssertFalse(app.buttons["Cook this"].exists,
                       "축약 상태엔 발주 CTA가 없어야 한다(발주는 펼친 뒤에)")

        // (b) 탭 → 펼침. 상세 전부가 한 번에 등장한다.
        stub.tap()
        XCTAssertTrue(app.staticTexts["ON THE TICKET"].waitForExistence(timeout: 8),
                      "티켓을 탭하면 재료 체크리스트가 나와야 한다")
        XCTAssertTrue(app.buttons["Cook this"].waitForExistence(timeout: 4),
                      "펼친 티켓엔 발주 CTA가 있어야 한다")
        XCTAssertTrue(stub.waitForNonExistence(timeout: 4),
                      "펼친 앞 티켓엔 축약 본문이 남아 있으면 안 된다")
    }

    /// 정본 제스처 — **위로 끌어올려 펼치고, 헤더를 아래로 끌어 접는다**. 탭은 대체 경로이고 실제 손은
    /// 이 드래그를 쓰므로, 두 방향 모두 임계를 넘겼을 때 커밋되는지 확인한다.
    func testTicketDeck_DragUpExpands_HeaderDragDownCollapses() {
        let app = launchDeck()

        let stub = ticketStub(app, number: 1)
        XCTAssertTrue(stub.waitForExistence(timeout: 20), "축약 본문으로 덱이 열려야 한다")

        // 위로 180pt(임계 56pt의 약 3.2배). 느린 드래그라 예측 변위 ≈ 실제 변위 → 판정이 결정적이다.
        let stubCenter = stub.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        stubCenter.press(forDuration: 0.1,
                         thenDragTo: stubCenter.withOffset(CGVector(dx: 0, dy: -180)))
        XCTAssertTrue(app.staticTexts["ON THE TICKET"].waitForExistence(timeout: 8),
                      "위로 \(Int(180 / expandCommit))배 넘게 끌어올리면 상세가 펼쳐져야 한다")

        // 헤더를 아래로 180pt(같은 배수). 본문(ScrollView) 위 세로 드래그는 내부 스크롤이 가져가므로
        // 접기는 헤더·발주 밴드처럼 스크롤 밖 영역에서 시작해야 덱까지 도달한다.
        let orderNumber = app.staticTexts["#01"]
        XCTAssertTrue(orderNumber.exists, "펼친 뒤에도 앞 티켓 헤더는 같은 자리에 있다")
        let headerPoint = orderNumber.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        headerPoint.press(forDuration: 0.1,
                          thenDragTo: headerPoint.withOffset(CGVector(dx: 0, dy: 180)))
        XCTAssertTrue(app.staticTexts["ON THE TICKET"].waitForNonExistence(timeout: 8),
                      "헤더를 임계의 \(Int(180 / expandCommit))배 아래로 끌면 축약으로 돌아가야 한다")
        XCTAssertTrue(stub.waitForExistence(timeout: 4), "축약 본문이 다시 보여야 한다")
    }

    /// 애매 구간(45° 대각) — 어느 축도 1.4배 우세하지 않아 `dragAxis`가 끝까지 nil로 남는다.
    /// 드래그 내내 화면 반응이 없는 구간이므로, 놓는 순간 상태가 뒤집히면 사용자는 원인을 못 찾는다.
    /// **펼침도 넘김도 일어나지 않아야 한다.**
    func testTicketDeck_AmbiguousDiagonalFlick_CommitsNothing() {
        let app = launchDeck()

        let stub = ticketStub(app, number: 1)
        XCTAssertTrue(stub.waitForExistence(timeout: 20), "축약 본문으로 덱이 열려야 한다")
        XCTAssertTrue(stub.isHittable, "1번 티켓이 맨 앞이어야 한다(앞 티켓만 히트테스트를 받는다)")

        // Δx = Δy = 140pt인 정확한 45° — 두 축 모두 임계(각 56·160pt)를 훌쩍 넘지만 우세 축이 없다.
        // XCUITest는 시작·끝점을 선형 보간하므로 중간 샘플도 전부 45°다.
        let center = stub.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        center.press(forDuration: 0.1, thenDragTo: center.withOffset(CGVector(dx: -140, dy: -140)))

        XCTAssertFalse(app.staticTexts["ON THE TICKET"].waitForExistence(timeout: 3),
                       "축이 갈리지 않은 대각 플릭은 티켓을 펼치지 않아야 한다")
        XCTAssertTrue(stub.exists, "축약 본문이 그대로 있어야 한다")
        XCTAssertTrue(stub.isHittable, "덱도 넘어가지 않아야 한다(1번 티켓이 여전히 맨 앞)")
    }

    /// 펼친 상태에서 **본문(내부 세로 ScrollView) 위 수평 플릭이 덱 넘김에 도달**하는지 —
    /// 접기 그립을 없애고 제스처를 덱 한 곳으로 모은 뒤, 펼친 티켓에서 플릭 가능한 영역이
    /// 헤더·발주 밴드 주변만 남지 않는다는 실증이다(자식 스크롤이 수평까지 삼키면 여기서 깨진다).
    func testTicketDeck_HorizontalFlickOverExpandedBody_AdvancesDeck() {
        let app = launchDeck()

        let first = ticketStub(app, number: 1)
        XCTAssertTrue(first.waitForExistence(timeout: 20), "축약 본문으로 덱이 열려야 한다")
        first.tap()

        let ticketSection = app.staticTexts["ON THE TICKET"]
        XCTAssertTrue(ticketSection.waitForExistence(timeout: 8), "탭하면 상세가 펼쳐져야 한다")

        // 'ON THE TICKET'은 중간 ScrollView 안에 있다 — 여기서 시작해 오른쪽으로 240pt
        // (플릭 임계 160pt의 1.5배). 세로 성분 0이라 축 판별은 수평으로만 갈린다.
        let inBody = ticketSection.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5))
        inBody.press(forDuration: 0.1, thenDragTo: inBody.withOffset(CGVector(dx: 240, dy: 0)))

        XCTAssertTrue(ticketSection.waitForNonExistence(timeout: 8),
                      "플릭 임계의 \(240 / flickCommit)배로 밀었으면 덱까지 도달해 다음 티켓으로 넘어가야 한다"
                      + "(새 앞 티켓은 축약부터)")
        let second = ticketStub(app, number: 2)
        XCTAssertTrue(second.waitForExistence(timeout: 8), "2번 티켓이 축약 본문으로 올라와야 한다")
        XCTAssertTrue(second.isHittable, "2번 티켓이 맨 앞이어야 한다(앞 티켓만 히트테스트를 받는다)")
    }
}
