import XCTest

/// 티켓 덱 플릭 방향 의미론(§13.6 4번) + 단서 카드 콘텐츠(§13.5) 회귀 방지선.
///
/// 수평 플릭은 **방향이 곧 의미**다 — 왼쪽 = Pass(다음 티켓), 오른쪽 = Cook(발주).
/// 계약은 넷이다: ① 왼쪽 = 다음 티켓 ② 오른쪽 = 발주(넘김이 아니다 — **1번** 티켓 그대로 발주된다)
/// ③ **축이 갈리지 않은 대각 드래그는 아무 것도 커밋하지 않는다** ④ **카드 본문(내부 세로 ScrollView)
/// 위에서 시작한 수평 플릭도 덱 넘김에 도달한다**.
///
/// ④가 특히 중요하다 — 단서 카드는 축약 상태가 없어 앞 티켓이 **항상** `middleScroll`을 품은 상태이고,
/// 그 본문이 기본 텍스트 크기에서 다 들어가 스크롤을 발동시키지 않는다. 즉 카드 본문이 **기본 표면**이라
/// 여기서 플릭이 안 되면 실사용에서 플릭이 거의 안 되는 것과 같다.
///
/// 여기에 단서 카드 자체의 계약 둘을 더한다: ⑤ D-day 칩은 soon·urgent에만 붙는다 ⑥ 티켓 어디에도
/// 조리 단계 텍스트가 없고 조리 화면은 영상 CTA가 조리법의 1차 경로다.
final class CookTicketFlickUITests: XCTestCase {

    /// 플릭 커밋 임계(`RecipeMemoCarousel.flickCommit`, 예측 변위 160pt).
    /// 아래 드래그 벡터는 전부 **앱 좌표계 절대 오프셋(pt)** 이라 요소 프레임·Dynamic Type이 바뀌어도
    /// 실제 이동량이 따라 변하지 않는다(정규화 오프셋 배수를 쓰면 임계 대비 마진이 조용히 달라진다).
    private let flickCommit: CGFloat = 160
    /// 드래그 거리 — 임계의 1.5배. 느린 드래그라 예측 변위 ≈ 실제 변위로 판정이 결정적이다.
    private let flickDistance: CGFloat = 240

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// `-cookCarousel`: 온보딩·로그인을 건너뛰고 샘플 냉장고로 고정한 뒤 티켓 덱을 자동 오픈한다
    /// (`-uiTestSampleFridge`로 기기에 남은 사용자 데이터와 무관한 결정적 상태를 만든다).
    private func launchDeck(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-skipAuth", "-uiTestSampleFridge", "-cookCarousel"]
            + extraArguments
        app.launch()
        XCTAssertTrue(app.staticTexts["Today's tickets"].waitForExistence(timeout: 30),
                      "요리 시작 없이도 -cookCarousel로 티켓 덱이 열려야 한다")
        return app
    }

    /// 티켓의 주문 번호("#01"·"#02"…). 겹쳐 쌓인 뒤 티켓도 머리(헤더)는 렌더하므로 **번호는 전부
    /// 트리에 존재한다** — "몇 번이 맨 앞인가"는 존재가 아니라 `isHittable`로 가른다(앞 티켓만
    /// `allowsHitTesting(true)`).
    private func orderNumber(_ app: XCUIApplication, _ number: Int) -> XCUIElement {
        app.staticTexts[String(format: "#%02d", number)]
    }

    /// N번 티켓이 맨 앞으로 올라올 때까지 기다린다.
    private func waitUntilFront(_ element: XCUIElement, timeout: TimeInterval = 10, _ message: String) {
        let hittable = expectation(for: NSPredicate(format: "isHittable == true"), evaluatedWith: element)
        XCTAssertEqual(XCTWaiter().wait(for: [hittable], timeout: timeout), .completed, message)
    }

    /// 절대 pt 수평 드래그. 시작점 x는 정규화(화면 폭 비율), y는 절대 pt로 준다 —
    /// 왼쪽으로 240pt를 밀 폭이 남도록 시작점을 오른쪽에 둔다(반대 방향이면 왼쪽에서 시작).
    private func horizontalFlick(_ app: XCUIApplication, startX: CGFloat, y: CGFloat, dx: CGFloat) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: startX, dy: 0))
            .withOffset(CGVector(dx: 0, dy: y))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: dx, dy: 0)))
    }

    // MARK: - ① 왼쪽 = Pass

    /// **왼쪽 플릭 = Pass** — 앞 티켓이 덱 뒤로 들어가고 2번이 올라온다. 발주가 아니다.
    func testTicketDeck_LeftFlick_PassesToNextTicket() {
        let app = launchDeck()

        let first = orderNumber(app, 1)
        waitUntilFront(first, "1번 티켓이 맨 앞으로 열려야 한다")

        horizontalFlick(app, startX: 0.85, y: first.frame.midY, dx: -flickDistance)

        let second = orderNumber(app, 2)
        waitUntilFront(second,
                       "임계의 \(flickDistance / flickCommit)배로 왼쪽에 밀었으면 2번 티켓이 맨 앞으로 올라와야 한다")
        XCTAssertFalse(first.isHittable, "1번 티켓은 덱 뒤로 들어가 맨 앞이 아니어야 한다")
        XCTAssertFalse(app.staticTexts["ORDER · FIRED"].exists, "왼쪽 플릭은 발주가 아니다")
    }

    // MARK: - ② 오른쪽 = Cook

    /// **오른쪽 플릭 = Cook(발주)** — 넘김이 아니라 "Cook this" 버튼과 같은 발주다.
    /// 발주가 성립하면 커버가 스스로 닫히고 조리 화면(`ORDER · FIRED`)이 열린다.
    /// 조리 화면의 메뉴명이 **1번 티켓 이름**이어야 한다 — 덱을 먼저 넘긴 뒤 발주한 게 아니라는 증거다.
    func testTicketDeck_RightFlick_FiresTheFrontTicket() {
        let app = launchDeck()

        let first = orderNumber(app, 1)
        waitUntilFront(first, "1번 티켓이 맨 앞으로 열려야 한다")

        // 메뉴명은 시드에서 오므로 테스트에 이름을 박지 않는다(레시피 하드코딩 금지) — 앞 티켓에서 읽어 온다.
        let menu = app.staticTexts["ticket.menuName"].label
        XCTAssertFalse(menu.isEmpty, "앞 티켓에서 메뉴명을 읽지 못했다")

        horizontalFlick(app, startX: 0.15, y: first.frame.midY, dx: flickDistance)

        // 발주 → START 슬램을 보여준 뒤(1.25초) 커버가 닫히고 조리 화면이 열린다.
        XCTAssertTrue(app.staticTexts["ORDER · FIRED"].waitForExistence(timeout: 20),
                      "오른쪽으로 임계의 \(flickDistance / flickCommit)배를 밀었으면 발주돼 조리 화면까지 가야 한다")
        XCTAssertTrue(app.staticTexts[menu].exists,
                      "발주된 티켓은 1번(\(menu))이어야 한다 — 오른쪽 플릭은 덱을 넘기지 않는다")
    }

    // MARK: - ③ 애매 대각 = 무커밋

    /// 애매 구간(45° 대각) — 어느 축도 1.4배 우세하지 않아 `dragAxis`가 끝까지 nil로 남는다.
    /// 드래그 내내 화면 반응이 없는 구간이므로, 놓는 순간 상태가 뒤집히면 사용자는 원인을 못 찾는다.
    /// **넘김도 발주도 일어나지 않아야 한다.**
    func testTicketDeck_AmbiguousDiagonalFlick_CommitsNothing() {
        let app = launchDeck()

        let first = orderNumber(app, 1)
        waitUntilFront(first, "1번 티켓이 맨 앞으로 열려야 한다")

        // Δx = Δy = 200pt인 정확한 45° — 두 축 모두 임계를 훌쩍 넘지만 우세 축이 없다.
        // XCUITest는 시작·끝점을 선형 보간하므로 중간 샘플도 전부 45°다.
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0))
            .withOffset(CGVector(dx: 0, dy: first.frame.midY + 200))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: -200, dy: -200)))

        // 덱 회전 스프링이 끝나고도 아무 것도 안 바뀌었음을 본다.
        let settled = expectation(description: "덱 정착 대기")
        _ = XCTWaiter().wait(for: [settled], timeout: 2)
        XCTAssertTrue(first.isHittable, "1번 티켓이 여전히 맨 앞이어야 한다")
        XCTAssertFalse(orderNumber(app, 2).isHittable, "축이 갈리지 않은 대각 플릭은 덱을 넘기지 않아야 한다")
        XCTAssertFalse(app.staticTexts["ORDER · FIRED"].exists, "대각 플릭은 발주도 아니다")
    }

    // MARK: - ④ 카드 본문(세로 ScrollView) 위 수평 플릭

    /// 카드 본문 위에서 시작한 수평 플릭이 덱 넘김에 도달하는지 — 단서 카드는 축약이 없어 앞 티켓이
    /// **항상** 내부 세로 ScrollView(`middleScroll`)를 품으므로, 여기가 예외가 아니라 **기본 표면**이다.
    /// 자식 스크롤이 수평까지 삼키면 여기서 깨진다.
    func testTicketDeck_HorizontalFlickOverCardBody_AdvancesDeck() {
        let app = launchDeck()

        let ticketSection = app.staticTexts["ON THE TICKET"]
        XCTAssertTrue(ticketSection.waitForExistence(timeout: 10),
                      "단서 카드는 펼침 단계 없이 곧장 재료 블록을 보여야 한다")
        let first = orderNumber(app, 1)
        waitUntilFront(first, "1번 티켓이 맨 앞이어야 한다")

        // 'ON THE TICKET' 라벨 **아래** = 재료 줄들이 있는 지점(중간 ScrollView 안쪽).
        // 시작점을 오른쪽에 두는 이유는 폭이다 — 왼쪽 끝에서 240pt를 밀면 좌표가 화면 밖으로 나간다.
        horizontalFlick(app, startX: 0.78, y: ticketSection.frame.maxY + 24, dx: -flickDistance)

        let second = orderNumber(app, 2)
        waitUntilFront(second, "카드 본문(재료 줄) 위에서 민 수평 플릭도 덱까지 도달해야 한다")
        XCTAssertFalse(first.isHittable, "1번 티켓은 덱 뒤로 들어가야 한다")
    }

    // MARK: - ⑤ D-day 칩은 soon·urgent에만

    /// 단서 카드의 D-day 칩은 `.soon`(D-3~D-1)·`.urgent`(D-0/지남)에만 붙는다 — 아직 여유 있는
    /// 재료의 카운트다운은 노이즈다. D-day 라벨은 "Overdue" / "Today" / "Nd"(N일 남음)이므로,
    /// **N ≥ 4인 칩이 하나라도 보이면 fresh 재료에 칩이 붙은 것**이다(조건이 뒤집힌 회귀).
    func testClueCard_DDayChip_OnlyForSoonAndUrgentIngredients() {
        let app = launchDeck()
        XCTAssertTrue(app.staticTexts["ON THE TICKET"].waitForExistence(timeout: 10), "재료 블록이 있어야 한다")

        let labels = app.staticTexts.allElementsBoundByIndex.map(\.label)
        let dayChips = labels.compactMap { label -> Int? in
            guard label.count >= 2, label.hasSuffix("d"), let n = Int(label.dropLast()) else { return nil }
            return n
        }
        for days in dayChips {
            XCTAssertLessThanOrEqual(days, 3,
                                     "D-\(days) 재료는 fresh다 — 단서 카드에 D-day 칩이 붙으면 안 된다")
        }
        // 비어 있는 계약이 되지 않게: 임박 재료 칩은 실제로 떠야 한다(덱은 먼저 상하는 순으로 랭크된다).
        let hasUrgentChip = labels.contains("Today") || labels.contains("Overdue") || !dayChips.isEmpty
        XCTAssertTrue(hasUrgentChip, "임박 재료에는 D-day 칩이 실제로 붙어야 한다")
    }

    // MARK: - ⑦ 부족 재료 → To buy 원탭 (§13.5 ⑨)

    /// 부족 재료 유무 판정 — 32차부터 "Short: …" 텍스트가 아니라 **패널 버튼**의 존재가 그 증거다.
    /// 버튼에 접근성 라벨을 주면 자식 `Text`들은 개별 접근성 원소로 더는 노출되지 않으므로(SwiftUI가
    /// 라벨 있는 버튼을 원소 하나로 접는다), `app.staticTexts`가 아니라 `shortPanelButton`과 같은
    /// 버튼 조회여야 한다.
    private func shortLine(_ app: XCUIApplication) -> XCUIElement {
        shortPanelButton(app)
    }

    /// 부족 재료 진입점 — **전폭 패널 버튼**(32차, 옛 "Short:" 텍스트 + 옆 알약을 하나로 합쳤다).
    /// 라벨이 "N ingredients short. Add to list."로 개수형이라 `confirmAddButton`과 같은 이유로
    /// 정규식(접미어) 매칭이다 — 정확한 문자열이 아니라 값이 낀 문장이라 `app.buttons["..."]`
    /// 정확 일치로는 못 집는다.
    private func shortPanelButton(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", "Add to list.")).firstMatch
    }

    /// 앞 티켓의 부족 재료 패널을 손가락이 닿는 자리까지 들인다.
    /// 패널은 `middleScroll`(카드 안쪽 세로 ScrollView) 안에 있어, 재료가 많거나 큰 글자에서는
    /// 접힌 아래쪽에 있을 수 있다 — 그때만 본문을 위로 민다. **세로 드래그는 덱의 축 잠금에서
    /// '커밋 없음'이라 티켓을 넘기지 않는다**(계약 ③), 즉 안쪽 스크롤만 움직인다.
    private func revealAddToBuyPill(_ app: XCUIApplication) -> Bool {
        let panel = shortPanelButton(app)
        guard panel.waitForExistence(timeout: 3) else { return false }
        if panel.isHittable { return true }
        let anchor = app.staticTexts["ON THE TICKET"]
        guard anchor.exists else { return false }
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0))
            .withOffset(CGVector(dx: 0, dy: anchor.frame.maxY + 40))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -120)))
        return panel.isHittable
    }

    /// 스크린샷 첨부 — 실패했을 때만이 아니라 **항상** 남긴다(이 흐름은 눈으로 봐야 납득되는 배선이다).
    private func attachScreenshot(_ app: XCUIApplication, named name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    // MARK: 담기 3단 팝업 헬퍼

    /// 고르기 팝업의 체크 행 — 라벨은 재료 이름, 값은 `Checked`/`Not checked`다.
    /// 이름을 테스트에 박지 않고 **팝업이 실제로 세운 줄**을 읽는다(표기는 사전 표제어로 정리된다).
    private func checkedRows(_ app: XCUIApplication) -> XCUIElementQuery {
        // 42차 — 상태 채널 단일화(§14.7)로 값("Checked")이 사라졌다: 행은 식별자, 상태는 isSelected.
        app.buttons.matching(NSPredicate(format: "identifier == %@ AND selected == 1", "dialog.row"))
    }

    /// 확정 CTA — 라벨이 개수형("Add 2 items" / "Add 1 item")이라 정규식으로 잡는다.
    /// 진입 패널("N ingredients short. Add to list.")과 라벨이 갈려 있어 이 조회가 패널을 집지 않는다.
    private func confirmAddButton(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label MATCHES %@", "Add [0-9]+ items?")).firstMatch
    }

    /// 부족 재료 패널을 눌러 고르기 팝업까지 연다 — 열렸으면 true.
    @discardableResult
    private func openPickDialog(_ app: XCUIApplication) -> Bool {
        shortPanelButton(app).tap()
        return app.staticTexts["Pick what to add"].waitForExistence(timeout: 5)
    }

    /// 냉장고 To buy 패인으로 이동(덱은 이미 닫힌 상태여야 한다).
    private func openToBuyPane(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["Fridge"].waitForExistence(timeout: 10), "메인으로 돌아와야 한다")
        app.buttons["Fridge"].tap()
        let toBuyTab = app.buttons["To buy"]
        XCTAssertTrue(toBuyTab.waitForExistence(timeout: 10), "냉장고 페이지에 To buy 탭이 있어야 한다")
        toBuyTab.tap()
        XCTAssertTrue(app.buttons["Add item"].waitForExistence(timeout: 10), "To buy 패인이 열려야 한다")
    }

    /// 화면에 보이는 모든 텍스트(소문자) — 목록 대조용.
    private func visibleTexts(_ app: XCUIApplication) -> [String] {
        app.staticTexts.allElementsBoundByIndex.map { $0.label.lowercased() }
    }

    // MARK: - ⑦ 담기 3단 팝업 — 해피 패스 (고르기 → 알림 → 이동)

    /// **담기 흐름 전체**(§13.5 ⑨ · §14.7) — 유닛 테스트가 닿지 못하는 런타임 배선이 대상이다:
    /// ① 알약이 고르기 팝업을 연다 ② 체크를 푼 재료는 **담기지 않는다** ③ 알림 팝업이 결과를 말한다
    /// ④ 이동 질문에서 "보기"를 고르면 **냉장고의 To buy 패인에 착지**한다(덱 커버 해체 → 탭 전환)
    /// ⑤ 착지한 목록에 체크한 것은 있고 푼 것은 없다.
    ///
    /// 재료 이름은 시드에서 오므로 테스트에 박지 않는다 — 팝업이 세운 줄에서 읽어 목록과 대조한다.
    func testTicketDeck_AddFlow_PicksItemsThenLandsOnToBuyPane() throws {
        let app = launchDeck()
        try XCTSkipUnless(frontTicketWithShortLine(app),
                          "덱을 한 바퀴 돌 동안 부족 재료 패널이 있는 티켓이 없었다 — 시드가 바뀌었는지 확인 필요")
        attachScreenshot(app, named: "a-ticket-with-pill")

        XCTAssertTrue(openPickDialog(app), "알약을 누르면 고르기 팝업이 떠야 한다")
        let rows = checkedRows(app)
        XCTAssertGreaterThan(rows.count, 0, "고르기 팝업엔 부족 재료가 줄로 서야 한다")
        // 기본은 **전부 체크** — 이 팝업의 기본값이 '아무것도 안 담음'이면 흔한 경우에 손이 더 간다.
        XCTAssertEqual(rows.count, app.buttons.matching(
            NSPredicate(format: "identifier == %@", "dialog.row")).count,
                       "처음엔 모든 줄이 체크돼 있어야 한다")
        attachScreenshot(app, named: "b-pick-dialog")

        // 부족 재료가 둘 이상일 때만 '하나 풀기'를 검증할 수 있다(1종 티켓이면 대상이 없다).
        let total = rows.count
        try XCTSkipUnless(total >= 2, "부족 재료가 1종인 티켓이라 '체크 풀기'를 검증할 수 없다")
        let dropped = rows.element(boundBy: total - 1).label
        let kept = rows.element(boundBy: 0).label
        rows.element(boundBy: total - 1).tap()
        XCTAssertTrue(app.buttons.matching(
            NSPredicate(format: "identifier == %@ AND selected == 0", "dialog.row")).count == 1,
                      "체크를 푼 줄은 정확히 하나여야 한다")
        attachScreenshot(app, named: "c-pick-dialog-one-unchecked")

        let confirm = confirmAddButton(app)
        XCTAssertTrue(confirm.exists, "확정 CTA는 개수형 라벨이어야 한다")
        XCTAssertEqual(confirm.label, total - 1 == 1 ? "Add 1 item" : "Add \(total - 1) items",
                       "CTA 라벨의 개수는 체크된 줄 수와 같아야 한다")
        confirm.tap()

        // 팝업② 담김 알림 — 새로 담긴 게 있으므로 개수형 제목이 선다.
        let addedTitle = app.staticTexts.matching(
            NSPredicate(format: "label MATCHES %@", "Added [0-9]+ items?")).firstMatch
        XCTAssertTrue(addedTitle.waitForExistence(timeout: 5), "담김 알림이 떠야 한다")
        XCTAssertFalse(app.staticTexts["Pick what to add"].exists, "두 팝업이 겹쳐 뜨면 안 된다")
        attachScreenshot(app, named: "d-added-dialog")
        app.buttons["OK"].tap()

        // 팝업③ 이동 질문
        XCTAssertTrue(app.staticTexts["View your To buy list?"].waitForExistence(timeout: 5),
                      "확인을 누르면 이동 질문이 떠야 한다")
        attachScreenshot(app, named: "e-move-dialog")
        app.buttons["View"].tap()

        // 덱 커버가 걷히고 냉장고의 To buy 패인에 착지한다 — 라우터 없이 클로저 체인으로 간다.
        XCTAssertTrue(app.staticTexts["Grocery memo"].waitForExistence(timeout: 15),
                      "보기를 고르면 냉장고의 To buy 패인에 착지해야 한다")
        XCTAssertTrue(app.buttons["Add item"].waitForExistence(timeout: 5), "To buy 패인의 도킹 CTA")
        XCTAssertFalse(app.staticTexts["Today's tickets"].exists, "덱은 걷혀 있어야 한다")
        attachScreenshot(app, named: "f-to-buy-after-view")

        // 체크한 것은 있고, 푼 것은 없다.
        let texts = visibleTexts(app)
        XCTAssertTrue(texts.contains { $0.contains(kept.lowercased()) },
                      "체크한 재료(\(kept))가 목록(\(texts))에 있어야 한다")
        XCTAssertFalse(texts.contains { $0 == dropped.lowercased() },
                       "체크를 푼 재료(\(dropped))는 목록(\(texts))에 없어야 한다")
    }

    // MARK: - ⑦-b X로 닫으면 아무것도 담기지 않는다

    /// 고르기 팝업의 우상단 X는 **아무것도 하지 않고** 닫는 길이다 — 담기지도, 다음 팝업이 뜨지도 않는다.
    /// 이 길이 없으면 팝업을 연 순간부터 담기를 무르는 방법이 사라진다.
    func testTicketDeck_AddFlow_CloseAddsNothing() throws {
        let app = launchDeck()
        try XCTSkipUnless(frontTicketWithShortLine(app), "부족 재료 패널이 있는 티켓이 없었다")
        XCTAssertTrue(openPickDialog(app), "고르기 팝업")

        // 덱 커버의 닫기 X와 라벨이 같으므로 식별자로 가른다.
        app.buttons["dialog.close"].tap()
        XCTAssertFalse(app.staticTexts["Pick what to add"].waitForExistence(timeout: 2), "팝업은 닫힌다")
        XCTAssertFalse(app.staticTexts["View your To buy list?"].exists, "이동 질문이 뜨면 안 된다")
        XCTAssertTrue(app.staticTexts["Today's tickets"].exists, "보던 티켓 덱에 그대로 머문다")
        XCTAssertTrue(shortLine(app).exists, "같은 티켓이어야 한다")

        // 목록은 비어 있어야 한다 — `-uiTestSampleFridge`가 장보기 메모를 비우고 시작한다.
        app.buttons["Close"].firstMatch.tap()
        openToBuyPane(app)
        XCTAssertTrue(app.staticTexts["Nothing on the list"].waitForExistence(timeout: 5),
                      "X로 닫았으므로 장보기 메모는 비어 있어야 한다")
        attachScreenshot(app, named: "g-to-buy-still-empty")
    }

    // MARK: - ⑦-c 이동 질문에서 취소하면 티켓에 남는다

    /// 마지막 질문의 취소는 **이동만** 거절한다 — 담기는 이미 끝났고, 화면은 덱에 머문다.
    func testTicketDeck_AddFlow_CancelKeepsYouOnTheTicket() throws {
        let app = launchDeck()
        try XCTSkipUnless(frontTicketWithShortLine(app), "부족 재료 패널이 있는 티켓이 없었다")
        XCTAssertTrue(openPickDialog(app), "고르기 팝업")
        confirmAddButton(app).tap()
        XCTAssertTrue(app.buttons["OK"].waitForExistence(timeout: 5), "담김 알림")
        app.buttons["OK"].tap()
        XCTAssertTrue(app.staticTexts["View your To buy list?"].waitForExistence(timeout: 5), "이동 질문")
        // 42차 — 담기는 이미 커밋된 뒤라 "Cancel"이 아니라 "Later"다. `app.buttons` 전역이 아니라
        // alerts 스코프로 잡는 이유: fullScreenCover 밑 MainView 배너의 "Later"가 접근성 트리에
        // 새는 기존 결함이 있어(별도 안건) 전역 조회는 다중 매치가 난다.
        app.alerts.buttons["Later"].firstMatch.tap()

        XCTAssertTrue(app.staticTexts["Today's tickets"].waitForExistence(timeout: 5),
                      "취소하면 보던 덱에 그대로 머문다")
        XCTAssertFalse(app.staticTexts["Grocery memo"].exists, "냉장고로 옮겨 가면 안 된다")

        // 담기 자체는 취소되지 않는다 — 목록에는 남아 있다.
        app.buttons["Close"].firstMatch.tap()
        openToBuyPane(app)
        XCTAssertFalse(app.staticTexts["Nothing on the list"].exists,
                       "이동만 취소했을 뿐 담기는 끝났으므로 목록이 비어 있으면 안 된다")
        attachScreenshot(app, named: "h-to-buy-after-cancel")
    }

    // MARK: - ⑦-d 발주 직후 창 — 팝업이 떠 있는 동안 덱 닫기는 **미뤄진다**

    /// 발주 후 덱 커버는 유예 뒤 닫힌다. 그 창 안에서 팝업을 열면 커버가 그냥 닫혀선 안 된다 —
    /// 부모가 걷히면 사용자가 방금 띄운 질문이 함께 사라진다(10차에 실측한 캐스케이드).
    /// 그리고 **미룸은 취소가 아니다**: 팝업 흐름이 끝나면 미뤄 둔 발주 전환(ORDER · FIRED)이 이어진다.
    /// 기본 1.25초 창은 자동화로 재현이 어려워 `-fireDismissDelay 6`으로 창만 넓힌다(메커니즘은 동일).
    func testTicketDeck_AddFlowDuringFireWindow_DefersDeckDismissThenResumes() throws {
        let app = launchDeck(extraArguments: ["-fireDismissDelay", "6"])
        try XCTSkipUnless(frontTicketWithShortLine(app), "부족 재료 패널이 있는 티켓이 없었다")

        let firedAt = Date()
        fireFrontTicket(app)
        XCTAssertTrue(shortPanelButton(app).waitForExistence(timeout: 3),
                      "발주 직후에도 담기 패널은 남아 있어야 한다")
        XCTAssertTrue(openPickDialog(app), "발주 창 안에서 고르기 팝업이 떠야 한다")

        // 지연 닫기 시점(발주 + 6초)을 **일부러 넘긴다**.
        let deadline = firedAt.addingTimeInterval(9)
        while Date() < deadline, app.staticTexts["Pick what to add"].exists { }
        XCTAssertTrue(app.staticTexts["Pick what to add"].exists,
                      "지연 닫기 시점을 넘겨도 팝업은 살아 있어야 한다(덱 닫기가 미뤄진다)")
        XCTAssertFalse(app.staticTexts["ORDER · FIRED"].exists,
                       "팝업이 떠 있는 동안엔 조리 화면으로 넘어가지 않는다")
        attachScreenshot(app, named: "i-pick-dialog-survives-fire-window")

        confirmAddButton(app).tap()
        XCTAssertTrue(app.buttons["OK"].waitForExistence(timeout: 5), "담김 알림")
        app.buttons["OK"].tap()
        XCTAssertTrue(app.staticTexts["View your To buy list?"].waitForExistence(timeout: 5), "이동 질문")
        app.alerts.buttons["Later"].firstMatch.tap()   // 42차 개명 + alerts 스코프(위 주석 참조)

        // 미뤄 둔 전환이 이어진다 — 취소는 이동을 거절한 것이지 발주를 되돌린 것이 아니다.
        XCTAssertTrue(app.staticTexts["ORDER · FIRED"].waitForExistence(timeout: 20),
                      "취소로 흐름이 끝나면 미뤄 뒀던 발주 전환이 이어져 조리 화면으로 가야 한다")
        attachScreenshot(app, named: "j-fired-transition-resumed")
    }


    /// 앞 티켓을 발주한다 — CTA는 **덱 밖 화면 하단에 도킹된 한 개**다(46차).
    ///
    /// 이 헬퍼는 원래 "티켓 종이 안의 CTA"를 상대했다: 뒤 티켓(depth 1)도 풀 렌더라 같은 라벨이
    /// 트리에 2개 있었고, `firstMatch`가 탭 불가능한 뒤 버튼을 집어 탭이 hit point {-1,-1}로
    /// 조용히 유실되곤 했다(발주가 없어도 중간 단언은 공허하게 참이라 마지막에서야 무너졌다).
    /// CTA가 종이 밖으로 나가면서 그 애매성 자체가 사라졌으므로, 다중 매칭 방어와 "1개로 줄어든다"는
    /// 판정은 **의미가 없어졌다** — 도킹 버튼은 덱이 살아 있는 동안 계속 한 개다.
    /// 발주 성립은 호출부가 뒤에서 "ORDER · FIRED"로 확인한다.
    private func fireFrontTicket(_ app: XCUIApplication) {
        let cook = app.buttons["Cook this"]
        XCTAssertTrue(cook.waitForExistence(timeout: 10), "하단 도킹 'Cook this'가 없다")
        XCTAssertTrue(cook.isHittable, "도킹 CTA가 탭 불가능하다 — 네비·페이드 띠에 가렸을 가능성")
        cook.tap()
    }

    /// 부족 재료가 있는 앞 티켓을 찾아 알약까지 노출한다 — 못 찾으면 false(호출부가 skip).
    /// 덱은 최대 4장까지 왼쪽 플릭(Pass)으로 돌려 본다.
    private func frontTicketWithShortLine(_ app: XCUIApplication) -> Bool {
        for _ in 0..<4 {
            _ = orderNumber(app, 1).waitForExistence(timeout: 10)
            if shortLine(app).exists, revealAddToBuyPill(app) { return true }
            let anchor = app.staticTexts["ON THE TICKET"]
            guard anchor.exists else { return false }
            horizontalFlick(app, startX: 0.85, y: anchor.frame.midY, dx: -flickDistance)
            _ = XCTWaiter().wait(for: [expectation(description: "덱 회전 대기")], timeout: 1.5)
        }
        return false
    }

    // MARK: - ⑧ 발주 직후에도 담기 알약은 살아 있다

    /// 발주(fire) 뒤에도 부족 재료는 여전히 부족하다 — 오히려 그때 더 사야 한다.
    /// `MainView.fire`는 발주 뒤 유예를 두고 덱 커버를 닫는데, **알약을 누르지 않으면** 그 창에
    /// 경쟁할 상대가 없다(팝업을 여는 경로는 위 ⑦-d가 따로 잠근다).
    /// 이 테스트는 발주 뒤에도 알약이 사라지지 않고 전환이 정시에 이어진다는 것만 고정한다.
    func testTicketDeck_AddToBuyPill_SurvivesFiring() throws {
        let app = launchDeck()
        try XCTSkipUnless(frontTicketWithShortLine(app),
                          "부족 재료 패널이 있는 티켓이 없었다 — 시드 확인 필요")

        fireFrontTicket(app)
        XCTAssertTrue(shortPanelButton(app).exists,
                      "발주 직후에도 담기 패널은 남아 있어야 한다(부족하다는 사실은 발주로 바뀌지 않는다)")
        // 발주 전환은 그대로 이어진다 — 담기 흐름이 그것을 붙잡지 않는다.
        XCTAssertTrue(app.staticTexts["ORDER · FIRED"].waitForExistence(timeout: 15),
                      "발주 1.25초 뒤 덱이 닫히고 조리 화면으로 넘어가야 한다")
    }

    // MARK: - ⑥ 단계 텍스트 없음 · 영상 CTA · 주방 전표(39차)

    /// 티켓 본문은 여전히 "무엇을 만들지"의 단서까지만 준다 — 단계 텍스트는 티켓 어디에도 없고,
    /// 영상 CTA는 여전히 조리법의 1차 경로다(§13.6 4-1, 39차가 유지한 절반의 테제). 다른 절반 —
    /// "단계는 아예 안 보여준다" — 은 이번에 부분적으로 뒤집혔다: 옛 기대치 캡션 대신 조용한
    /// 옵트인 링크가 서고(시드 레시피는 전량 단계를 갖고 있어 이 경로에서 항상 뜬다), 단계
    /// 자체는 여전히 티켓 표면엔 한 글자도 없다 — 링크 뒤 시트에만 산다.
    func testCookTicket_NoStepText_AndVideoCTAIsThePrimaryPath() {
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-skipAuth", "-uiTestSampleFridge", "-cookTicket"]
        app.launch()

        XCTAssertTrue(app.staticTexts["ORDER · FIRED"].waitForExistence(timeout: 30),
                      "-cookTicket으로 조리 화면이 열려야 한다")

        // 영상이 조리법의 1차 경로 — 아이콘 단독이 아니라 라벨 있는 와이드 CTA다.
        XCTAssertTrue(app.buttons["Open recipe videos"].waitForExistence(timeout: 10),
                      "조리 화면엔 영상 CTA가 있어야 한다")
        // 옛 "Cook it your way. The video has the details." 캡션은 걷혔다 — 시드 레시피는 전량
        // 단계를 갖고 있으므로(recipes-seed.json 실측 80/80) 이 경로에선 항상 옵트인 링크가 대신 선다.
        XCTAssertFalse(app.staticTexts["Cook it your way. The video has the details."].exists,
                       "옛 기대치 캡션은 더 이상 없어야 한다")
        XCTAssertTrue(app.buttons["How to cook"].waitForExistence(timeout: 4),
                      "단계가 있는 레시피엔 주방 전표를 여는 조용한 링크가 서야 한다")

        // 히어로 아래 요리 소개 한 줄 — 시드 레시피에는 반드시 있다(§13.6 4-1).
        // 문구는 시드에서 오므로 테스트에 박지 않고 식별자로 집는다(`ticket.menuName` 선례).
        let intro = app.staticTexts["cook.intro"]
        XCTAssertTrue(intro.waitForExistence(timeout: 10),
                      "조리 티켓 히어로 아래에 요리 소개가 있어야 한다")
        XCTAssertFalse(intro.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                       "요리 소개가 빈 문자열이면 캡션이 여백만 벌린다")
        attachScreenshot(app, named: "cook-ticket-hero-and-intro")   // 시각 표면이라 눈으로 볼 근거를 남긴다

        // 단계 섹션·체크리스트는 여전히 티켓 표면엔 없다(위약 UI 금지 — 39차도 이 불변식은 지킨다).
        XCTAssertFalse(app.staticTexts["STEPS"].exists, "조리 화면에 단계 섹션이 남아 있으면 안 된다")
        XCTAssertFalse(app.staticTexts["PREP"].exists, "조리 화면에 PREP 섹션이 남아 있으면 안 된다")
    }

    /// 주방 전표 시트 — 링크 → 열기 → 체크 → 닫기 → 다시 열기 → 여전히 체크됨(같은 세션 내 왕복).
    /// 완전한 앱 재실행 왕복은 `FridgeStoreTests.decodesCookSessionWithStepsAndCompletedSteps`·
    /// `cookSnapshotsStepsAndToggleCookStepFlipsCompletion`(유닛)이 대신 고정한다 — 정직하게 기록해
    /// 둔다: `-uiTestSampleFridge`가 매 런치 샘플을 강제 리셋해 UI 테스트로 재실행 영속성을
    /// 재현하려면 그 인자를 뺀 두 번째 런치가 필요한데, 그러면 이 스위트의 다른 테스트들과
    /// 격리가 깨진다(먼저 어떤 상태가 남았는지에 의존하게 된다).
    func testKitchenCopySheet_ChecksPersistAcrossOpenClose() {
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-skipAuth", "-uiTestSampleFridge", "-cookTicket"]
        app.launch()

        let link = app.buttons["How to cook"]
        XCTAssertTrue(link.waitForExistence(timeout: 30))
        link.tap()

        // 크라운 헤더 — 50차로 크라운("KITCHEN COPY")과 레시피명(타이틀, 시드에서 온다)이 다른 줄로
        // 갈렸지만 `.accessibilityElement(children: .combine)`은 그대로라 결합 라벨은 여전히
        // "KITCHEN COPY"로 시작한다 — 접두사만 확인.
        // 존재 확인 외에, 닫기 드래그의 시작점으로도 재사용한다(아래) — 스크롤 리스트 **밖**의
        // 고정 영역이라 드래그 시작점으로 안전하다.
        let crownHeader = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "KITCHEN COPY")).firstMatch
        XCTAssertTrue(crownHeader.waitForExistence(timeout: 6), "주방 전표 시트가 열리면 크라운 헤더가 있어야 한다")

        // 첫 단계 행을 찾아 체크 — 단계 문장은 시드 데이터라 텍스트를 박지 않고 첫 번째 버튼으로 집는다.
        // **`app.scrollViews.buttons`로 앱 전체를 뒤지면 안 된다**(실측으로 잡은 함정 — 처음엔 그렇게
        // 짰다가 매번 "not hittable"로 깨졌다): 시트 밑에 딤 처리된 `CookingStepsView` 배경도 자기
        // ScrollView와 버튼("Open recipe videos" 등)을 그대로 트리에 남겨 두고, 문서 순서상 그쪽이
        // 시트보다 먼저 걸린다 — `.firstMatch`가 시트의 체크 행이 아니라 배경의 "Open recipe videos"를
        // 집어 버렸다(`app.debugDescription` 캡처로 정확한 프레임까지 대조해 확인). 그 버튼이 안 눌리는
        // 건 버그가 아니라 **정확한 동작**이다 — 모달 시트 밑 콘텐츠는 히트 테스트에서 빠지는 게 맞다.
        // 시트 자신의 리스트에만 식별자(`kitchenCopy.steps`, `KitchenCopySheet.swift`)를 달아 좁힌다.
        let firstStep = app.scrollViews["kitchenCopy.steps"].buttons.firstMatch
        XCTAssertTrue(firstStep.waitForExistence(timeout: 4), "체크할 단계 행이 있어야 한다")
        let stepLabel = firstStep.label
        // 42차 — 단계 완료는 "선택"이 아니라 도메인 값(Done/Not done)으로 말한다(§14.7 상태 채널 단일화).
        XCTAssertEqual(firstStep.value as? String, "Not done", "처음엔 아무 단계도 체크돼 있지 않아야 한다")
        firstStep.tap()
        XCTAssertEqual(firstStep.value as? String, "Done", "탭하면 그 단계가 체크 상태가 돼야 한다")

        // 닫기 — 시스템 시트의 스와이프 다운 드래그(핸들 제스처)로 닫는다.
        // `app.swipeDown()`(앱 전체 기준 제스처)은 안 된다 — 실측: 시작점이 리스트(`ScrollView`)
        // 안쪽에 찍혀 시트 드래그가 아니라 리스트 스크롤로 먹혔다(시트가 안 닫힘). 크라운 헤더는
        // 그 리스트 **밖**의 고정 영역이라, 거기서 시작해 충분히 길게(500pt) 끌어야 인터랙티브
        // 디스미스 임계를 확실히 넘는다.
        let dragStart = crownHeader.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let dragEnd = dragStart.withOffset(CGVector(dx: 0, dy: 500))
        dragStart.press(forDuration: 0.05, thenDragTo: dragEnd)
        // 닫힘은 애니메이션이라 즉시 `.exists`를 재면 전환 중간에 걸릴 수 있다 — 짧게 유예한 뒤 확인한다.
        Thread.sleep(forTimeInterval: 0.6)
        let crown = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "KITCHEN COPY")).firstMatch
        XCTAssertFalse(crown.exists, "스와이프 다운으로 시트가 닫혀야 한다")

        link.tap()   // 다시 열기
        let reopenedStep = app.scrollViews["kitchenCopy.steps"].buttons.matching(NSPredicate(format: "label == %@", stepLabel)).firstMatch
        XCTAssertTrue(reopenedStep.waitForExistence(timeout: 4))
        XCTAssertEqual(reopenedStep.value as? String, "Done", "닫았다 다시 열어도 체크 상태가 세션에 남아 있어야 한다")
    }

    /// 단계가 없는 레시피(커스텀 레시피, 33c8861 — 편집기가 단계를 더 이상 받지 않는다)로 발주하면
    /// 링크 자체가 서지 않아야 한다 — "링크 부재 · 나머지는 그대로"(지시문 3번). 영상 CTA는 이
    /// 경로에서도 그대로다.
    func testCookTicket_NoStepsRecipe_HidesTheKitchenCopyLink() {
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-skipAuth", "-uiTestSampleFridge", "-cookTicket.noSteps"]
        app.launch()

        XCTAssertTrue(app.staticTexts["ORDER · FIRED"].waitForExistence(timeout: 30),
                      "-cookTicket.noSteps로도 조리 화면이 열려야 한다")
        XCTAssertTrue(app.buttons["Open recipe videos"].waitForExistence(timeout: 10),
                      "단계가 없어도 영상 CTA는 그대로여야 한다")
        XCTAssertFalse(app.buttons["How to cook"].exists,
                       "단계가 없는 레시피엔 주방 전표 링크가 서면 안 된다")
    }
}
