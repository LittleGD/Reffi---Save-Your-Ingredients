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

    // MARK: - ⑦ 부족 재료 → To buy (중첩 커버 · 환경 전파)

    /// Short 줄("Short: …") — 표기는 시드에서 오므로 접두사로만 잡는다.
    private func shortLine(_ app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Short: '")).firstMatch
    }

    /// 앞 티켓의 "Add to To buy" 칩을 손가락이 닿는 자리까지 들인다.
    /// 칩은 `middleScroll`(카드 안쪽 세로 ScrollView) 안에 있어, 재료가 많거나 큰 글자에서는
    /// 접힌 아래쪽에 있을 수 있다 — 그때만 본문을 위로 민다. **세로 드래그는 덱의 축 잠금에서
    /// '커밋 없음'이라 티켓을 넘기지 않는다**(계약 ③), 즉 안쪽 스크롤만 움직인다.
    private func revealAddToBuyChip(_ app: XCUIApplication) -> Bool {
        let chip = app.buttons["Add to To buy"]
        guard chip.waitForExistence(timeout: 3) else { return false }
        if chip.isHittable { return true }
        let anchor = app.staticTexts["ON THE TICKET"]
        guard anchor.exists else { return false }
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0))
            .withOffset(CGVector(dx: 0, dy: anchor.frame.maxY + 40))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -120)))
        return chip.isHittable
    }

    /// 스크린샷 첨부 — 실패했을 때만이 아니라 **항상** 남긴다(이 흐름은 눈으로 봐야 납득되는 배선이다).
    private func attachScreenshot(_ app: XCUIApplication, named name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// **"Add to To buy" 칩 → 살 것 목록**(§13.5 ⑩). 유닛 테스트가 닿지 못하는 **런타임 배선** 셋이 대상이다:
    /// ① 칩 탭이 `store.addToBuy`까지 실제로 도달하는가 ② 덱(그 자체가 이미 풀스크린 커버) **위에**
    /// `ShoppingListView` 커버가 중첩 프레젠테이션되며 환경(`FridgeStore`·`ProfileStore`)이 전파되는가
    /// — 누락이면 `@Environment` 강제 언랩에서 즉시 크래시라 이 테스트가 유일한 방지선이다
    /// ③ 커버를 닫으면 **원래 티켓으로 복귀**하는가(덱이 띄운 이유가 곧 이것이다).
    ///
    /// 재료 이름은 시드에서 오므로 테스트에 박지 않는다 — Short 줄에서 읽어 To buy 행과 대조한다.
    /// 대조는 **포함 관계**로 본다: 담길 때 표기가 사전 표제어로 정리되기 때문이다
    /// (레시피 원문 "minced garlic" → 목록엔 "Garlic", `RecipeRecommender.toBuyEntry`).
    func testTicketDeck_AddToBuyChip_AddsMissingAndOpensToBuyOverTheDeck() throws {
        let app = launchDeck()

        // 부족 재료가 있는 티켓을 찾는다 — 없으면 왼쪽 플릭(Pass)으로 다음 티켓을 본다.
        // 샘플 냉장고(13종)로는 상위 티켓 대부분에 부족 재료가 뜨지만, 시드가 바뀌어 하나도 없으면
        // 이 테스트는 검증 대상이 사라진 것이라 실패가 아니라 skip이 맞다.
        try XCTSkipUnless(frontTicketWithShortLine(app),
                          "덱을 한 바퀴 돌 동안 'Short:' 부족 재료가 있는 티켓이 없었다 — 시드가 바뀌었는지 확인 필요")

        // 담기 전 Short 줄을 읽어 둔다(탭하면 커버가 덮어 못 읽는다).
        let shortText = shortLine(app).label
        XCTAssertTrue(shortText.count > "Short: ".count, "Short 줄에서 부족 재료를 읽지 못했다")
        attachScreenshot(app, named: "a-expanded-card-with-chip")

        app.buttons["Add to To buy"].tap()

        // ② 중첩 커버 — 여기서 환경이 안 전파되면 앱이 죽어 아래 단언 전에 테스트가 무너진다.
        XCTAssertTrue(app.staticTexts["To buy"].waitForExistence(timeout: 15),
                      "칩을 누르면 살 것(To buy) 커버가 덱 위에 열려야 한다")
        attachScreenshot(app, named: "b-to-buy-after-tap")

        // ① 담기 — 샘플 로드가 manualToBuy를 비우므로(`FridgeStore.loadSampleData`),
        // "Added by you" 구역은 **이번 탭이 만든 것**일 수밖에 없다(인과 증거).
        XCTAssertTrue(app.staticTexts["Added by you"].waitForExistence(timeout: 5),
                      "직접 담은 구역이 생겨야 한다 — 칩이 store.addToBuy까지 도달했다는 증거")

        // 행 이름은 Add 버튼의 접근성 라벨("Restock <이름>")에서 읽는다.
        let restocked = app.buttons.allElementsBoundByIndex
            .map(\.label)
            .filter { $0.hasPrefix("Restock ") }
            .map { String($0.dropFirst("Restock ".count)) }
        XCTAssertFalse(restocked.isEmpty, "목록에 담긴 행이 하나도 없다")

        let short = shortText.lowercased()
        let matched = restocked.first { short.contains($0.lowercased()) }
        XCTAssertNotNil(matched,
                        "부족했던 재료가 목록에 없다 — Short: \(shortText) / 담긴 행: \(restocked)")

        // ③ 닫으면 원래 티켓으로 복귀 — 덱이 커버를 소유하는 이유가 이것이다
        // (메인에서 띄웠으면 커버 2장이 충돌해 티켓으로 못 돌아온다).
        app.buttons["Close"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Today's tickets"].waitForExistence(timeout: 10),
                      "To buy를 닫으면 티켓 덱으로 돌아와야 한다")
        XCTAssertTrue(shortLine(app).waitForExistence(timeout: 5),
                      "돌아온 자리는 방금 보던 그 티켓이어야 한다(Short 줄이 그대로)")
    }

    /// 부족 재료가 있는 앞 티켓을 찾아 칩까지 노출한다 — 못 찾으면 false(호출부가 skip).
    /// 덱은 최대 4장까지 왼쪽 플릭(Pass)으로 돌려 본다.
    private func frontTicketWithShortLine(_ app: XCUIApplication) -> Bool {
        for _ in 0..<4 {
            _ = orderNumber(app, 1).waitForExistence(timeout: 10)
            if shortLine(app).exists, revealAddToBuyChip(app) { return true }
            let anchor = app.staticTexts["ON THE TICKET"]
            guard anchor.exists else { return false }
            horizontalFlick(app, startX: 0.85, y: anchor.frame.midY, dx: -flickDistance)
            _ = XCTWaiter().wait(for: [expectation(description: "덱 회전 대기")], timeout: 1.5)
        }
        return false
    }

    // MARK: - ⑧ 발주 직후 창에서 To buy를 열어도 커버가 걷히지 않는다

    /// **발주(fire) 지연 닫기 vs 중첩 To buy 커버의 경쟁 상태**(리뷰 HIGH).
    /// `MainView.fire`는 발주 1.25초 뒤 덱 커버를 닫는다(슬램을 보여준 뒤 조리 화면으로 넘기려고).
    /// 그런데 "Add to To buy" 칩은 **발주 후에도 살아 있는 게 설계 의도**라, 그 1.25초 창 안에서
    /// To buy를 열면 지연 닫기가 **부모 커버를 닫으며 방금 연 자식 커버까지 함께 걷어간다**
    /// — 사용자는 장보기 목록 대신 조리 화면에 떨어진다.
    ///
    /// 이 테스트는 그 창을 **의도적으로** 노린다: "Cook this" 직후 곧바로 칩을 누르고,
    /// 지연 닫기 시점을 **넘긴 뒤에도** To buy가 그대로 떠 있는지 본다.
    ///
    /// 창은 `-fireDismissDelay`로 넓힌다(프로덕션은 1.25초 그대로). XCUITest는 탭마다 app-idle을
    /// 기다리는데 그 대기 대상이 바로 이 전환이라, 기본 1.25초에서는 **두 번째 탭이 항상 창 밖으로
    /// 밀린다**(실측: 엘리먼트 탭 1.25s · 좌표 탭 1.40s로 2회 모두 미관측). 닫기 로직 자체는
    /// 그대로 타므로 검증 대상은 실제 코드 경로다.
    func testTicketDeck_AddToBuyRightAfterFiring_KeepsToBuyPresented() throws {
        let dismissDelay: TimeInterval = 6
        let app = launchDeck(extraArguments: ["-fireDismissDelay", "\(Int(dismissDelay))"])
        try XCTSkipUnless(frontTicketWithShortLine(app),
                          "부족 재료가 있는 티켓이 없어 발주-경쟁 창을 만들 수 없다")

        // 덱은 뒤 티켓의 CTA도 트리에 들고 있다(가려졌을 뿐) — **맨 앞 티켓만** `allowsHitTesting(true)`라
        // 히트 가능 여부로 앞 카드의 버튼을 고른다. 뒤 카드 버튼을 누르면 발주 자체가 안 일어난다.
        let chip = app.buttons["Add to To buy"]
        let cook = try XCTUnwrap(
            app.buttons.matching(identifier: "Cook this").allElementsBoundByIndex.first { $0.isHittable },
            "미발주 티켓에는 히트 가능한 'Cook this' CTA가 있어야 한다")

        // 두 탭 모두 **좌표 탭**이다 — 엘리먼트 탭은 매번 쿼리·히트포인트 계산·idle 대기를 거쳐
        // 1.25초 창을 그냥 넘겨버린다(실측: 엘리먼트 탭이면 lag ≈ 1.25s로 창 밖). 좌표는 발주 **전**에
        // 미리 읽어 둔다. 발주로 fireBand가 바뀌어도 `middleScroll`은 VStack에서 header 바로 아래라
        // 위쪽 기준점이 그대로여서 칩의 절대 y가 유지된다.
        let chipPoint = chip.frame
        let cookPoint = cook.frame
        func tap(_ rect: CGRect) {
            app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: rect.midX, dy: rect.midY))
                .tap()
        }

        // 발주 → 곧바로 칩 탭. 두 탭 사이에 어떤 대기도 넣지 않는다(창을 좁히는 게 목적).
        let firedAt = Date()
        tap(cookPoint)
        tap(chipPoint)
        let tapLag = Date().timeIntervalSince(firedAt)

        // 창을 놓쳤으면(이미 커버가 닫혀 조리 화면으로 갔으면) 이 실행은 무효다.
        let toBuy = app.staticTexts["To buy"]
        guard tapLag < dismissDelay, toBuy.waitForExistence(timeout: 6) else {
            throw XCTSkip("칩 탭이 발주 후 \(String(format: "%.2f", tapLag))초에 도달해 \(Int(dismissDelay))초 창을 놓쳤다 — 경쟁 상태 미관측")
        }

        // 지연 닫기가 도는 시점(발주 + dismissDelay)을 확실히 넘겨서 관찰한다.
        let observeUntil = firedAt.addingTimeInterval(dismissDelay + 1.5)
        _ = XCTWaiter().wait(for: [expectation(description: "지연 닫기 창 통과 대기")],
                             timeout: max(0.1, observeUntil.timeIntervalSinceNow))

        XCTAssertTrue(toBuy.exists,
                      "발주 \(String(format: "%.2f", tapLag))초 뒤 연 To buy가 지연 닫기(\(Int(dismissDelay))초)에 함께 걷혔다 — "
                      + "부모 커버를 닫기 전에 중첩 커버를 확인해야 한다")
        XCTAssertTrue(app.staticTexts["Added by you"].exists,
                      "담긴 항목도 그대로 보여야 한다")

        // 닫으면 발주의 원래 목적지(조리 화면)로 이어진다 — 미룬 닫기가 유실되지 않는다는 확인.
        app.buttons["Close"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["ORDER · FIRED"].waitForExistence(timeout: 15),
                      "To buy를 닫으면 미뤄 뒀던 발주 전환이 이어져 조리 화면으로 가야 한다")
    }

    // MARK: - ⑥ 단계 텍스트 없음 · 영상 CTA

    /// 티켓은 "무엇을 만들지"의 단서까지만 준다 — 조리법(단계)은 어느 티켓에도 없고,
    /// 조리 화면의 영상 CTA가 조리법의 1차 경로다(2026-08 owner decision, §13.6 4-1).
    func testCookTicket_NoStepText_AndVideoCTAIsThePrimaryPath() {
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-skipAuth", "-uiTestSampleFridge", "-cookTicket"]
        app.launch()

        XCTAssertTrue(app.staticTexts["ORDER · FIRED"].waitForExistence(timeout: 30),
                      "-cookTicket으로 조리 화면이 열려야 한다")

        // 영상이 조리법의 1차 경로 — 아이콘 단독이 아니라 라벨 있는 와이드 CTA다.
        XCTAssertTrue(app.buttons["Open recipe videos"].waitForExistence(timeout: 10),
                      "조리 화면엔 영상 CTA가 있어야 한다")
        XCTAssertTrue(app.staticTexts["Cook it your way. The video has the details."].exists,
                      "단계가 사라진 자리를 설명하는 기대치 한 줄이 있어야 한다")

        // 단계 섹션·체크리스트는 완전히 제거됐다(위약 UI 금지).
        XCTAssertFalse(app.staticTexts["STEPS"].exists, "조리 화면에 단계 섹션이 남아 있으면 안 된다")
        XCTAssertFalse(app.staticTexts["PREP"].exists, "조리 화면에 PREP 섹션이 남아 있으면 안 된다")
    }
}
