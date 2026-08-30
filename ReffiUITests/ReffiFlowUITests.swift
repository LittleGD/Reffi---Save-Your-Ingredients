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

    /// 사라짐을 **기다린다** — 목록 전환은 스프링 애니메이션이라 `exists`를 즉시 읽으면 아직 트리에 남은
    /// 잔상에 걸린다. 등장은 `waitForExistence`가 있지만 소멸은 술어로 기다려야 한다.
    private func waitForDisappearance(_ element: XCUIElement, timeout: TimeInterval = 5,
                                      _ message: String) {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"),
                                             object: element)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: timeout), .completed, message)
    }

    /// 재고 영수증 카드 — 카드가 **버튼**이 되면서 재료 이름은 그 버튼 라벨의 한 조각이 됐다
    /// (버튼은 라벨의 글자들을 하나의 접근성 원소로 합친다). 이름만 보는 staticText 셀렉터는
    /// 그래서 더 이상 성립하지 않는다 — 이름을 품은 버튼으로 집는다.
    private func stockCard(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
    }

    /// History 히어로의 **값 덩이** — 이번 주 먹은 비율을 분자·분모와 함께 한 문장으로 읽는 요소.
    /// 접근성 라벨이 이 표면의 계약이라, 화면 구조가 바뀌어도 테스트는 같은 문장을 본다.
    private func heroRateHeadline(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Eaten this week:")).firstMatch
    }

    /// 히어로의 **추세 화살표**(지난 주 대비, 33차부터 문장이 아니라 화살표다). 방향은 화면 문구가
    /// 아니라 값 덩이에 붙은 UI 테스트 식별자로 잡는다(`HistoryContent.trendArrow` 선례,
    /// `history.hero.trendArrow.up`/`.down`) — 비슷한 주(`.same`)는 식별자 자체가 없다.
    private func heroTrendArrowExists(_ app: XCUIApplication, direction: String) -> Bool {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@", "history.hero.trendArrow.\(direction)"))
            .firstMatch.exists
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

    // MARK: 신 플로우 — 인트로(스와이프 전용) → "Let's start" → 셋업 시트(Next…Maybe later) → 도장 → 메인

    /// 인트로 마지막 장까지 스와이프 → "Let's start" → 셋업 각 단계를 "Next"로 진행 →
    /// 알림 프라이밍 페이지에서 "Maybe later"로 스킵 → 도장 연출 뒤 로그인 게이트 없이 곧장
    /// 메인(RootTabView, 게스트)에 도달하는지 검증(게스트 우선 플로우).
    func testOnboarding_CompleteSetup_ReachesGuestMain() {
        let app = launchFreshOnboarding()

        // 인트로 진입 확인 — 스플래시("Reffi" 워드마크뿐)와 모호하지 않은 온보딩 전용 요소(Skip)로.
        XCTAssertTrue(app.buttons["Skip"].waitForExistence(timeout: 8), "온보딩 인트로가 떠야 한다")
        XCTAssertTrue(app.descendants(matching: .any)["Intro 1 of 3"].exists, "인트로 1장 인디케이터")
        let letsStart = app.buttons["Let's start"]
        XCTAssertFalse(letsStart.exists, "인트로 첫 장엔 Let's start가 없어야 한다(스와이프 전용)")

        // 인트로는 하단 버튼 없이 스와이프 전용 — 페이지 인디케이터 라벨로 이동을 확인.
        app.swipeLeft()
        XCTAssertTrue(app.descendants(matching: .any)["Intro 2 of 3"].waitForExistence(timeout: 4),
                      "스와이프 → 인트로 2장")
        app.swipeLeft()
        XCTAssertTrue(app.descendants(matching: .any)["Intro 3 of 3"].waitForExistence(timeout: 4),
                      "스와이프 → 인트로 3장(마지막)")
        XCTAssertTrue(letsStart.waitForExistence(timeout: 4), "인트로 마지막 장에서 Let's start 등장")
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
        XCTAssertTrue(stockCard(app, "Beef").waitForExistence(timeout: 4), "재고 영수증 카드")
        XCTAssertTrue(app.buttons["Sort: Expiring first"].exists, "재고 패인의 정렬 칩")
        // 패인 헤드라인은 **자기 패인에만** 선다 — In stock의 첫 블록은 컨트롤 한 줄이고,
        // 이름 붙일 종이가 따로 없어 헤드라인을 두지 않는다.
        XCTAssertFalse(app.staticTexts["Grocery memo"].exists, "To buy 헤드라인이 재고 패인에 새면 안 된다")
        XCTAssertFalse(app.staticTexts["Kitchen ledger"].exists, "History 헤드라인이 재고 패인에 새면 안 된다")
        attach(app, named: "fridge-tab-in-stock")

        // To buy 탭 — 카드 밖 헤드라인이 패인의 이름표고, 하단 도킹 "Add item"은 커버 때 그대로다.
        toBuyTab.tap()
        XCTAssertTrue(app.staticTexts["Grocery memo"].waitForExistence(timeout: 4),
                      "To buy 패인의 헤드라인(영수증 카드 밖)")
        XCTAssertTrue(app.buttons["Add item"].waitForExistence(timeout: 4), "To buy 패인의 직접 담기 CTA")
        XCTAssertFalse(app.buttons["Sort: Expiring first"].exists, "재고 패인 크롬은 함께 사라져야 한다")
        XCTAssertTrue(toBuyTab.isSelected, "탭하면 선택 상태가 옮겨간다")
        XCTAssertFalse(stockTab.isSelected, "직전 탭의 선택은 풀린다")
        attach(app, named: "fridge-tab-to-buy")

        // History 탭 — 맨 위는 패인 헤드라인("Kitchen ledger"), 그 아래가 이번 주 히어로(숫자 헤드라인 +
        // 추세 화살표 + 종이 칩 일곱)고, 30일 정산서는 다시 그 아래다. 헤드라인 이름이 탭 라벨
        // ("History")과 **다른 것이 요점**이다 — 같은 말이면 한 화면에 같은 이름이 두 번 선다.
        historyTab.tap()
        let ledgerHeadline = app.staticTexts["Kitchen ledger"]
        XCTAssertTrue(ledgerHeadline.waitForExistence(timeout: 4),
                      "History 패인의 첫 블록은 헤드라인이다")
        XCTAssertFalse(app.staticTexts["Grocery memo"].exists, "To buy 헤드라인은 함께 사라져야 한다")
        // 값 덩이는 두 상태 중 정확히 하나로 읽힌다 — 이번 주 처리 건이 있으면 비율, 없으면 빈 창 안내.
        // (샘플 이력의 날짜는 상대값이라, 실행일이 주의 어디냐에 따라 둘 다 정상이다.)
        let rateHeadline = heroRateHeadline(app)
        let emptyHeadline = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Nothing cleared out this week yet.")).firstMatch
        XCTAssertTrue(rateHeadline.waitForExistence(timeout: 4) || emptyHeadline.exists,
                      "헤드라인은 비율이나 빈 창 안내 중 하나를 읽어 준다(NaN·빈 라벨 금지)")
        // **히어로의 랜드마크는 값 덩이다 — 칩 캡션이 아니다.** 캡션("A chip a day…")은 31차부터
        // 닫을 수 있고 닫힘이 **설치에 영구 기록**되므로(`history.chipHintDismissed`), 캡션을
        // 랜드마크로 쓰면 `testHistory_ChipHint_DismissesPermanently`가 한 번 돈 시뮬레이터에서
        // 이 테스트가 **영원히** 실패한다. 한 번의 실행 안에서는 알파벳 순서가 F < H라 가려져,
        // 전체 실행은 초록불인데 같은 기기에 두 번째로 돌리면 깨진다(실측으로 확인).
        // 값 덩이는 닫히지 않으므로 같은 함정이 없다.
        let heroValue = rateHeadline.exists ? rateHeadline : emptyHeadline
        XCTAssertTrue(heroValue.exists, "히어로는 헤드라인 바로 아래에 선다")
        XCTAssertTrue(ledgerHeadline.frame.maxY <= heroValue.frame.minY,
                      "헤드라인이 히어로보다 위에 있어야 한다")
        // 추세 화살표 — 샘플 이력은 **어느 요일에 돌려도 두 창이 모두 비지 않는다**:
        // 이번 주에는 오늘(daysAgo 0) 로그가 있고, 지난 주 창(daysAgo offset+1…offset+7)에는
        // daysAgo 2·3·4·5·7·9·11·13 중 최소 셋이 언제나 들어온다. 그래서 추세는 **반드시 뭔가로
        // 정해진다** — 다만 33차부터 "비슷한 주"(.same)는 화살표 자체가 없어, "화살표가 선다"를
        // 무조건 기대할 수 없다. 대신 **접근성 라벨이 말하는 방향과 화살표 식별자가 일치하는가**를
        // 본다(라벨은 화면엔 없는 세부까지 그대로 읽어 준다, §13.10 — 세 변형 다 받는 것과 같은 이유).
        let trendLabel = rateHeadline.label
        if trendLabel.contains("Up from") {
            XCTAssertTrue(heroTrendArrowExists(app, direction: "up"), "라벨이 상승을 말하면 위 화살표가 있어야 한다")
            XCTAssertFalse(heroTrendArrowExists(app, direction: "down"), "상승 라벨에 아래 화살표가 함께 있으면 안 된다")
        } else if trendLabel.contains("Down from") {
            XCTAssertTrue(heroTrendArrowExists(app, direction: "down"), "라벨이 하락을 말하면 아래 화살표가 있어야 한다")
            XCTAssertFalse(heroTrendArrowExists(app, direction: "up"), "하락 라벨에 위 화살표가 함께 있으면 안 된다")
        } else if trendLabel.contains("About the same") {
            XCTAssertFalse(heroTrendArrowExists(app, direction: "up"), "비슷한 주엔 화살표가 없어야 한다")
            XCTAssertFalse(heroTrendArrowExists(app, direction: "down"), "비슷한 주엔 화살표가 없어야 한다")
        } else {
            XCTFail("헤드라인 라벨이 추세 세 변형 중 어느 것도 말하지 않는다: \(trendLabel)")
        }
        // 칩 행 — 오늘 칸은 언제 돌려도 정확히 하나이고, 일곱 칸이 모두 한 문장으로 읽힌다.
        let todayCell = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Today, ")).firstMatch
        XCTAssertTrue(todayCell.waitForExistence(timeout: 4), "칩 행에 오늘 칸이 선다")
        // 앞으로 올 날은 "still to come", 아무 일도 없던 날은 "nothing"이다 — 어느 쪽도 "0 eaten"이
        // 아니어야 한다(0은 없는 판정이다). 실행일이 주의 끝이면 미래 칸이 없으므로 둘 중 하나만 본다.
        let futureCell = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label ENDSWITH %@", ", still to come")).firstMatch
        let quietCell = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label ENDSWITH %@", ", nothing")).firstMatch
        XCTAssertTrue(futureCell.exists || quietCell.exists,
                      "조용한 칸은 'still to come'이거나 'nothing'이다")
        XCTAssertFalse(app.descendants(matching: .any)
            .matching(NSPredicate(format: "label ENDSWITH %@", ", 0 eaten")).firstMatch.exists,
                       "0은 판정이 아니다 — 빈 칸을 '0 eaten'으로 읽으면 안 된다")
        // 정산서 — 발주 소비 행이 Ate·Tossed와 같은 문법으로 함께 선다.
        // 정산 행은 `children: .combine`이라 라벨에 건수가 붙는다 — 이름으로만 찾는다.
        XCTAssertTrue(app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Cooked")).firstMatch.exists,
                      "정산서에 요리 소비 행이 있어야 한다")
        XCTAssertFalse(app.buttons["Add item"].exists, "To buy 패인의 CTA는 함께 사라져야 한다")
        XCTAssertTrue(historyTab.isSelected, "History가 선택된다")
        attach(app, named: "fridge-tab-history")

        // 한 패인 스크롤: 헤드라인·히어로는 걷히고 정산서가 올라오지만 **탭 행은 그 자리에** 남는다.
        XCTAssertTrue(app.staticTexts["Tally · past 30 days"].exists,
                      "30일 정산서는 히어로 아래에 그대로 있다")
        // 스와이프 폭은 기기·모션 설정에 따라 다르다 — 횟수를 못 박지 않고 조건으로 민다.
        for _ in 0..<4 where heroValue.isHittable { app.swipeUp() }
        XCTAssertTrue(app.staticTexts["Tally · past 30 days"].waitForExistence(timeout: 4),
                      "스크롤하면 정산서가 화면으로 올라온다")
        XCTAssertFalse(heroValue.isHittable, "히어로는 스크롤과 함께 걷힌다")
        XCTAssertFalse(ledgerHeadline.isHittable, "헤드라인도 스크롤 콘텐츠라 함께 걷힌다")
        XCTAssertTrue(historyTab.isHittable, "탭 행은 스크롤 밖 고정 크롬이라 남아 있어야 한다")
        attach(app, named: "fridge-tab-history-scrolled")

        // 다시 In stock — 패인 왕복 뒤에도 목록 조작 크롬이 그대로 돌아온다.
        stockTab.tap()
        XCTAssertTrue(stockTab.isSelected, "In stock으로 복귀")
        XCTAssertTrue(stockCard(app, "Beef").waitForExistence(timeout: 4), "재고 영수증 카드 복귀")

        // 카테고리 필터 — 가로 스크롤 칩 행이 컨트롤 한 줄의 드롭다운 하나로 접혔다.
        let categoryPill = app.buttons["Filter: All"]
        XCTAssertTrue(categoryPill.waitForExistence(timeout: 4), "카테고리 필터 트리거(기본 All)")
        categoryPill.tap()
        // 펼친 목록은 칩이 보여 주던 개수를 그대로 싣는다("Veg 6").
        let vegRow = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Veg ")).firstMatch
        XCTAssertTrue(vegRow.waitForExistence(timeout: 4), "카테고리 행은 이름 + 개수를 함께 읽는다")
        vegRow.tap()
        XCTAssertTrue(app.buttons["Filter: Veg"].waitForExistence(timeout: 4), "선택이 트리거 라벨에 반영")
        waitForDisappearance(stockCard(app, "Beef"), "Veg로 좁히면 고기 카드는 목록에서 빠진다")
        attach(app, named: "fridge-in-stock-filtered")

        // All로 원복 — 드롭다운에서 해제 경로는 목록 맨 위 "All"이다(칩 재탭이 아니다).
        app.buttons["Filter: Veg"].tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "All ")).firstMatch.tap()
        XCTAssertTrue(app.buttons["Filter: All"].waitForExistence(timeout: 4), "All로 복귀")
        XCTAssertTrue(stockCard(app, "Beef").waitForExistence(timeout: 4), "필터를 풀면 전체 목록 복귀")

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
        XCTAssertTrue(stockCard(app, "Beef").waitForExistence(timeout: 4), "스택 카드 복귀")
        app.buttons["Sort: Recently added"].tap()
        app.buttons["Expiring first"].tap()
        XCTAssertTrue(app.buttons["Sort: Expiring first"].waitForExistence(timeout: 4), "기본 정렬 복귀")
    }

    // MARK: History 히어로 — 오늘의 판정이 곧 값 덩이와 오늘 칩의 값

    /// 히어로는 장식이 아니라 **이번 주 장부**다. 오늘 재료 하나를 버리면 그 즉시
    /// "처리했지만 안 먹은 것"이 한 건 생기므로, 비율은 반드시 100% 아래로 내려오고
    /// **오늘 칩에는 버림이 함께 실린다**(칩은 먹음과 버림을 다른 채널로 동시에 말한다).
    ///
    /// 이 단언이 날짜와 무관하게 성립하는 이유: 버림이 오늘 찍히면 이번 주 창에 **반드시** 들어가고
    /// (창은 이번 주 시작 자정부터 오늘을 포함한다), 분자(먹은 수)는 그대로인 채 분모만 늘어난다.
    /// 실행일이 주의 어디든, 심지어 이번 주 첫 기록이든 결과는 같다 — 100%는 나올 수 없다.
    /// 유닛 테스트가 못 덮는 배선(판정 → store → 히어로 재계산)을 여기서 고정한다.
    func testFridge_HistoryHero_HeadlineAndTodaysChipFollowTodaysJudgement() {
        let app = XCUIApplication()
        // -fridgeExpand: 첫 재료의 펼친 상세로 바로 착지(Ate/Tossed 버튼 QA용 기존 인자).
        app.launchArguments = ["-skipAuth", "-onboarding.done", "YES",
                               "-fridgeTab", "-uiTestSampleFridge", "-fridgeExpand"]
        app.launch()

        let toss = app.buttons["Tossed"]
        XCTAssertTrue(toss.waitForExistence(timeout: 8), "펼친 상세의 Tossed 버튼")
        toss.tap()

        let historyTab = app.buttons["History"]
        XCTAssertTrue(historyTab.waitForExistence(timeout: 4), "판정 후 탭 행으로 돌아온다")
        historyTab.tap()

        let headline = heroRateHeadline(app)
        XCTAssertTrue(headline.waitForExistence(timeout: 4),
                      "오늘 판정이 있으면 창이 비지 않으므로 헤드라인은 비율을 읽는다")
        XCTAssertFalse(app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "100 percent")).firstMatch.exists,
                       "오늘 하나를 버렸는데 비율이 100%면 버림이 분모에 들어가지 않은 것이다")
        // 오늘 칩 — 버림이 화면의 다른 채널(모서리 조각)로도 남아야 한다. 라벨이 그 채널의 계약이다.
        let todayCell = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Today, ")).firstMatch
        XCTAssertTrue(todayCell.waitForExistence(timeout: 4), "칩 행에 오늘 칸이 선다")
        XCTAssertTrue(todayCell.label.contains("tossed"),
                      "오늘 버린 게 있는데 오늘 칩이 그것을 말하지 않는다: \(todayCell.label)")
        attach(app, named: "history-hero-after-toss")
    }

    // MARK: History — 다른 패인에서 한 판정이 같은 실행 안에서 반영되는가

    /// 사용자 제보(22차): "In stock에서 먹음/버림을 처리해도 History의 숫자가 안 바뀐다".
    ///
    /// **20차 테스트와 결정적으로 다른 점**: 그쪽은 판정을 먼저 하고 History를 *처음* 열었다
    /// (= 뷰가 그때 처음 만들어지므로 어차피 새 값을 읽는다). 사용자의 실제 순서는 반대다 —
    /// **History를 먼저 보고**, 다른 패인에서 판정한 뒤, 돌아온다. 재실행 없이 한 번의 실행 안에서
    /// 그 왕복을 그대로 태워야 스테일을 잡을 수 있다.
    func testFridge_History_ReflectsJudgementMadeInAnotherPane() {
        let app = XCUIApplication()
        app.launchArguments = ["-skipAuth", "-onboarding.done", "YES",
                               "-fridgeTab", "-uiTestSampleFridge"]
        app.launch()

        let historyTab = app.buttons["History"]
        let stockTab = app.buttons["In stock"]
        XCTAssertTrue(historyTab.waitForExistence(timeout: 8), "History 탭")

        // ① History를 **먼저** 본다 — 이 방문이 뷰를 만들고, 그 상태가 스테일의 후보다.
        historyTab.tap()
        let headline = heroRateHeadline(app)
        XCTAssertTrue(headline.waitForExistence(timeout: 4), "값 덩이가 비율을 읽는다")
        let before = headline.label
        attach(app, named: "history-before-judgement")

        // ② In stock에서 판정 한 번(먹음).
        stockTab.tap()
        let card = stockCard(app, "Beef")
        XCTAssertTrue(card.waitForExistence(timeout: 4), "재고 카드")
        card.tap()
        let ate = app.buttons["Ate"]
        XCTAssertTrue(ate.waitForExistence(timeout: 4), "펼친 상세의 Ate 버튼")
        ate.tap()

        // ③ 같은 실행에서 History로 돌아온다 — 여기서 값이 그대로면 그것이 제보된 버그다.
        historyTab.tap()
        XCTAssertTrue(headline.waitForExistence(timeout: 4), "값 덩이가 여전히 비율을 읽는다")
        attach(app, named: "history-after-judgement")
        XCTAssertNotEqual(headline.label, before,
                          "다른 패인의 판정이 History에 반영돼야 한다(분모가 최소 1 늘어난다)")
    }

    // MARK: To buy — 사전 밖 이름 직접 입력 담기

    /// 검색 시트의 **직접 입력 담기**: 사전에 없는 이름을 친 그대로 메모에 담는다.
    /// 사전 픽커가 원천적으로 닿지 못하는 칸(브랜드·규격명)을 사용자가 채우는 경로라, 유닛 테스트가
    /// 닿지 못하는 배선(시트 → store → 메모 목록)을 여기서 고정한다.
    func testToBuy_DirectAdd_TypedNameLandsInGroceryMemo() {
        let app = XCUIApplication()
        app.launchArguments = ["-skipAuth", "-onboarding.done", "YES",
                               "-fridgeTab", "-uiTestSampleFridge", "-toBuy"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Grocery memo"].waitForExistence(timeout: 8), "To buy 패인")
        app.buttons["Add item"].tap()

        let field = app.textFields["Search ingredients"]
        XCTAssertTrue(field.waitForExistence(timeout: 4), "검색 필드")
        field.tap()
        // 사전에 없을 것이 확실한 고유 문자열 — 매칭이 생기면 이 테스트의 전제가 깨지므로 일부러 길게.
        let typed = "Fish sauce brand X"
        field.typeText(typed)

        // 결과 유무와 무관하게 **결과 위에** 직접 담기 행이 선다.
        let addRow = app.buttons["Add \(typed)"]
        XCTAssertTrue(addRow.waitForExistence(timeout: 4), "직접 입력 담기 행")
        attach(app, named: "to-buy-direct-add-row")
        addRow.tap()

        // 중복 상태 — 같은 행이 그 자리에서 '담김'으로 뒤집힌다(타일과 같은 도장 문법).
        // 시트는 닫히지 않고 검색어도 그대로라, 방금 한 일이 눈에 보인다.
        let addedRow = app.buttons["Added \(typed)"]
        XCTAssertTrue(addedRow.waitForExistence(timeout: 4),
                      "담긴 뒤에는 같은 행이 '담김' 상태로 바뀌어야 한다")
        XCTAssertTrue(addedRow.isSelected, "담김 상태엔 .isSelected 트레잇이 붙는다")
        XCTAssertTrue(field.exists, "연속 추가 UX — 시트는 닫히지 않는다")

        // 실제로 메모에 들어갔는가.
        app.buttons["Close"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts[typed].waitForExistence(timeout: 4),
                      "친 그대로의 이름이 Grocery memo 목록에 선다")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "to-buy-direct-add-result"
        shot.lifetime = .keepAlways
        add(shot)

        // 행에 남는 컨트롤은 **하나**다(21차) — 파란 "Bought". 빼기는 밀어야 나온다.
        XCTAssertTrue(app.buttons["Bought \(typed)"].exists,
                      "메모 행의 1차 액션은 'Bought <이름>'이다")
        let deleteButton = app.buttons["Remove \(typed) from the list"]
        XCTAssertFalse(deleteButton.exists,
                       "밀기 전에는 빼기 컨트롤이 보조기술에도 없어야 한다(화면 밖 버튼에 포커스 금지)")

        // ① 드러내기 경로 — 끝에서 **멈춰서** 손을 떼면(hold) 예측 종점 ≈ 실제 이동이라
        // 커밋 임계(200pt)를 넘지 않고 빨간 조각만 드러난다.
        revealDelete(app, rowLabeled: typed)
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 4),
                      "밀면 빨간 조각이 드러나고 그때서야 보조기술에도 보인다")
        attach(app, named: "to-buy-row-mid-swipe")
        deleteButton.tap()
        waitForDisappearance(app.staticTexts[typed], "빼기 확정 — 행이 목록에서 사라진다")
        attach(app, named: "to-buy-after-delete")

        // 되돌리기 창 — 밀기는 버튼보다 오발이 잦아 토스트를 짝지었다(21차).
        let undo = app.buttons["Undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 4), "빼기 직후 되돌리기 토스트가 뜬다")
        undo.tap()
        XCTAssertTrue(app.staticTexts[typed].waitForExistence(timeout: 4),
                      "되돌리면 그 줄이 목록으로 돌아온다")

        // ② 끝까지 밀기 경로 — 관성이 붙은 플릭은 **탭 없이** 바로 확정된다. 같은 드래그가
        // ①과 다른 결과를 내는 것이 임계 설계의 요지라, 두 경로를 같은 테스트에서 못 박는다.
        // (이 경로가 상태 원복도 겸한다 — 담은 항목이 목록에서 사라진 채 끝난다.)
        flickRowAway(app, rowLabeled: typed)
        waitForDisappearance(app.staticTexts[typed], "끝까지 밀면 탭 없이 바로 빠진다")
        XCTAssertTrue(app.buttons["Undo"].waitForExistence(timeout: 4),
                      "끝까지 밀기도 같은 되돌리기 창을 연다")
    }

    /// 행을 왼쪽으로 밀어 **드러내기에서 멈춘다**.
    ///
    /// 끝점에서 `thenHoldForDuration`으로 손가락을 세워 두는 것이 핵심이다 — 속도가 0으로 죽어
    /// `predictedEndTranslation ≈ translation`이 되고, 그래야 커밋 임계(200pt) 아래로 남는다.
    /// 이 hold가 없으면 XCUITest 기본 500pt/s가 예측 종점을 임계 너머로 밀어 **드러내기 없이 바로
    /// 삭제된다**(첫 시도의 실패가 정확히 이것이었고, 그 실패 자체가 끝까지 밀기 경로의 증거였다).
    ///
    /// 시작점은 **행의 y · 화면 가로 중앙** — 이름 열과 Bought 알약 사이의 빈 면이라 버튼을 누르지
    /// 않으면서 행 얼굴의 제스처만 잡는다(이름 텍스트에서 끌면 종점이 화면 밖으로 나간다).
    private func revealDelete(_ app: XCUIApplication, rowLabeled label: String) {
        let midY = app.staticTexts[label].frame.midY
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(CGVector(dx: app.frame.midX, dy: midY))
        let end = origin.withOffset(CGVector(dx: app.frame.midX - 120, dy: midY))
        start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.5)
    }

    // MARK: To buy — 밀기 어포던스 힌트(28차)

    /// **첫 등장의 힌트**: 목록에 줄이 있는 채로 패인이 서면 맨 윗줄이 왼쪽으로 한 번 밀렸다 돌아온다.
    /// 그리고 **플래그가 서 있으면 뜨지 않는다** — 설치당 한 번이라는 규약이 실제로 잠기는지 본다.
    ///
    /// 두 번 런치하는 이유: 이 힌트의 게이트 중 하나가 `@AppStorage`라 **프로세스 경계를 넘어야**
    /// 관측된다. 첫 런치는 `-toBuy.swipeHint <초>`로 강제하고(유지 시간을 넓혀 프레임 조회가 닿게 한다),
    /// 둘째 런치는 `-toBuy.swipeHintSeen YES`로 플래그만 주입한 뒤 **아무 일도 없음**을 단언한다.
    func testToBuy_SwipeHint_PeeksWhenForcedAndStaysPutOnceSeen() {
        // ① 강제 — `-toBuy.sampleMemo`가 **두 줄**을 시드한다. 두 줄인 것이 요점이다: 움직이는 줄과
        //    움직이지 않는 줄을 같은 실행에서 대조해야 "맨 윗줄만"이라는 규약이 잠기고, 행 사이
        //    절취선도 그때 화면에 선다. 담기는 시트를 세 단계 몰지 않고 인자로 끝낸다 — 상태를 만드는
        //    조작 사슬이 길수록 검증하려는 것과 무관한 이유로 흔들린다(시트 프레젠테이션·타이핑 포커스).
        let top = Self.memoTop, second = Self.memoSecond
        let app = XCUIApplication()
        app.launchArguments = ["-skipAuth", "-onboarding.done", "YES", "-fridgeTab",
                               "-uiTestSampleFridge", "-toBuy.sampleMemo",
                               "-toBuy.swipeHint", String(Self.forcedHold)]
        app.launch()
        XCTAssertTrue(app.staticTexts["Grocery memo"].waitForExistence(timeout: 10), "To buy 패인")

        // 첫 등장에서도 줄이 이미 서 있지만, 힌트를 **관측 가능한 창에서** 잡으려면 등장 시점을
        // 테스트가 쥐어야 한다 — 탭을 오가면 패인이 뷰째 새로 서고 그 등장에서 재생이 시작된다.
        reenterToBuyPane(app)
        let topRow = app.staticTexts[top], secondRow = app.staticTexts[second]
        XCTAssertTrue(topRow.waitForExistence(timeout: 10), "시드된 첫 줄")
        XCTAssertTrue(secondRow.exists, "시드된 둘째 줄(행 사이 절취선이 생기는 조건)")
        // **이 시점이 재생 중이다**(유예 0.5초 + 넓힌 유지 시간 안쪽) — 밀린 첫 행이 여기 찍힌다.
        attach(app, named: "to-buy-swipe-hint-peek")

        // 유지 시간 + 진입·복귀 모션 + 조회 지연까지 넉넉히 덮는 창에서 두 행의 가로 위치를 함께 훑는다.
        let samples = sampleMinX([topRow, secondRow], seconds: Self.forcedHold + 4)
        guard let peeked = samples[0].min(), let rest = samples[0].max(), let last = samples[0].last,
              let stillLo = samples[1].min(), let stillHi = samples[1].max() else {
            return XCTFail("표본이 하나도 없다 — 행이 조회되지 않았다")
        }
        // 창이 끝난 뒤 = 제자리 — 두 행이 다시 나란해진 목록과 그 사이 절취선이 여기 찍힌다.
        attach(app, named: "to-buy-rows-at-rest-with-dashed-rule")
        XCTAssertGreaterThan(rest - peeked, 12,
                             "힌트는 맨 윗줄을 왼쪽으로 눈에 보이게 민다(설계값 20pt)")
        XCTAssertLessThan(rest - peeked, 40,
                          "드러내기(84pt)나 열림 판정(42pt)까지 가면 '열려다 만 행'으로 읽힌다")
        // 되돌아왔는가 — 마지막 표본이 최댓값 근처면 제자리다(`settle`은 감쇠 0.74라 미세 오버슛이 있다).
        XCTAssertLessThan(abs(last - rest), 3, "힌트는 스프링으로 제자리에 돌아온다(밀린 채 굳지 않는다)")
        // **맨 윗줄만** — 둘째 행은 같은 창 내내 붙박이다.
        XCTAssertLessThan(stillHi - stillLo, 3, "힌트는 첫 행에만 얹힌다(둘째 행은 움직이지 않는다)")

        // 힌트가 도는 동안에도 빼기 컨트롤은 보조기술에 없다 — 장식 모션이 트리를 바꾸면 안 된다.
        XCTAssertFalse(app.buttons["Remove \(top) from the list"].exists,
                       "힌트는 보이기만 한다 — 조각이 접근성 트리에 올라오면 안 된다")
        // 21차가 세운 계약도 그대로다.
        XCTAssertTrue(app.buttons["Bought \(top)"].exists, "행의 1차 액션은 그대로 'Bought <이름>'")

        // ② 플래그가 서 있으면 뜨지 않는다 — 강제 인자 없이, 같은 조건(줄 있음·새 등장)을 다시 만든다.
        let seen = XCUIApplication()
        seen.launchArguments = ["-skipAuth", "-onboarding.done", "YES", "-fridgeTab",
                                "-uiTestSampleFridge", "-toBuy.sampleMemo", "-toBuy",
                                "-toBuy.swipeHintSeen", "YES"]
        seen.launch()
        XCTAssertTrue(seen.staticTexts["Grocery memo"].waitForExistence(timeout: 10), "To buy 패인")

        reenterToBuyPane(seen)
        let seenRow = seen.staticTexts[top]
        XCTAssertTrue(seenRow.waitForExistence(timeout: 10), "다시 선 패인에 메모 행이 있다")
        let still = sampleMinX([seenRow], seconds: 4)   // 유예 0.5초 + 재생 전체를 덮는다
        guard let lo = still[0].min(), let hi = still[0].max() else {
            return XCTFail("표본이 하나도 없다 — 행이 조회되지 않았다")
        }
        attach(seen, named: "to-buy-swipe-hint-suppressed")
        XCTAssertLessThan(hi - lo, 3, "이미 본 뒤에는 행이 움직이지 않는다(설치당 한 번)")
    }

    /// 강제 재생의 유지 시간(초). 기본 0.4초는 **런치와 `waitForExistence`만으로 지나가** 프레임
    /// 조회가 닿지 못한다 — `-fireDismissDelay`가 같은 이유로 같은 모양의 인자를 갖는다.
    private static let forcedHold: TimeInterval = 8

    /// `-toBuy.sampleMemo`가 담는 두 줄 — **정본은 `RootTabView.sampleMemoNames`**(RUN.md에도 적혀 있다).
    /// 첫 값이 맨 윗줄이고, 힌트가 얹히는 행이 그 줄이다.
    private static let memoTop = "Fish sauce brand X"
    private static let memoSecond = "Rice vinegar brand Y"

    /// 패인을 **다시 세운다**. 탭 패인은 `switch tab` 분기라 탭을 떠나면 뷰째 해체되고, 돌아오면
    /// `onAppear`가 다시 돈다 — 이 왕복이 곧 "새 등장"이고, 힌트는 그 등장 훅에 걸려 있다.
    private func reenterToBuyPane(_ app: XCUIApplication) {
        let stockTab = app.buttons["In stock"]
        XCTAssertTrue(stockTab.waitForExistence(timeout: 8), "In stock 탭")
        stockTab.tap()
        let toBuyTab = app.buttons["To buy"]
        XCTAssertTrue(toBuyTab.waitForExistence(timeout: 8), "To buy 탭")
        toBuyTab.tap()
    }

    /// 여러 요소의 가로 위치를 주어진 시간 동안 **번갈아** 반복 조회한다. 힌트는 상태가 아니라
    /// **지나가는 모션**이라 단발 조회로는 잡을 수 없다 — 표본의 최소·최대·마지막 값이 "밀렸다"와
    /// "돌아왔다"를 함께 말하고, 같은 창에서 뜬 다른 행의 표본이 "그 행은 안 움직였다"를 말한다.
    private func sampleMinX(_ elements: [XCUIElement], seconds: TimeInterval) -> [[CGFloat]] {
        var out = Array(repeating: [CGFloat](), count: elements.count)
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            for (i, element) in elements.enumerated() { out[i].append(element.frame.minX) }
        }
        return out
    }

    /// 행을 끝까지 밀어 **바로 확정**한다 — 관성이 붙은 기본 속도 드래그.
    private func flickRowAway(_ app: XCUIApplication, rowLabeled label: String) {
        let midY = app.staticTexts[label].frame.midY
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(CGVector(dx: app.frame.midX, dy: midY))
        let end = origin.withOffset(CGVector(dx: app.frame.midX - 150, dy: midY))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    // MARK: History — 칩 캡션 힌트 닫기(31차)

    /// **닫으면 영구히 사라진다**: 힌트의 게이트가 `@AppStorage`라 밀기 힌트 테스트와 같은 이유로
    /// **프로세스 경계를 넘어야** 관측된다(`testToBuy_SwipeHint_...`와 같은 두 런치 패턴). 첫 런치는
    /// `-history.chipHintForce`로 반드시 뜨게 한 뒤 닫고, 둘째 런치는 강제 인자 대신 플래그를
    /// UserDefaults 인자로 직접 주입해 "닫힌 채 재현"을 검증한다(강제 인자를 또 주면 그 자체로
    /// 언제나 다시 뜨므로 "플래그가 실제로 걸렸는가"를 검증할 수 없다).
    func testHistory_ChipHint_DismissesPermanently() {
        let app = XCUIApplication()
        app.launchArguments = ["-skipAuth", "-onboarding.done", "YES", "-uiTestSampleFridge",
                               "-showHistory", "-history.chipHintForce"]
        app.launch()

        let caption = app.staticTexts["A chip a day. Green is what you ate."]
        XCTAssertTrue(caption.waitForExistence(timeout: 10), "새 설치엔 칩 캡션 힌트가 떠야 한다")
        let dismiss = app.buttons["Dismiss hint"]
        XCTAssertTrue(dismiss.exists, "닫기 X가 접근성에 있어야 한다")
        attach(app, named: "history-chip-hint-visible")

        dismiss.tap()
        waitForDisappearance(caption, "닫으면 그 자리에서 사라져야 한다")
        attach(app, named: "history-chip-hint-dismissed")

        // 둘째 런치 — 강제 인자 없이, 플래그만 UserDefaults 인자로 주입한다.
        let second = XCUIApplication()
        second.launchArguments = ["-skipAuth", "-onboarding.done", "YES", "-uiTestSampleFridge",
                                  "-showHistory", "-history.chipHintDismissed", "YES"]
        second.launch()
        XCTAssertTrue(second.staticTexts["Kitchen ledger"].waitForExistence(timeout: 10), "History 패인")
        XCTAssertFalse(second.staticTexts["A chip a day. Green is what you ate."].exists,
                       "닫힌 뒤에는 다음 런치에도 다시 뜨지 않아야 한다")
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

    // MARK: 프로필 Data 영수증 — 게스트 전용 샘플 로드 행(36차)

    /// 기본 테스트 환경(`-skipAuth`)은 게스트다(RUN.md) — 이 경로에서 Data 영수증에 두 행(샘플 로드 +
    /// Reset)이 모두 있어야 한다. 로그인 계정 쪽(Reset만 남는 경로)은 실제 Supabase 세션이 필요해
    /// 이 UI 테스트로는 재현하지 못한다 — 그 경로는 `ProfileDataVisibilityTests`의 순수 규칙
    /// (`ProfileView.showsSampleLoad(isGuest:)`)이 대신 고정한다.
    func testProfile_GuestDataSection_ShowsSampleLoadAndReset() {
        let app = XCUIApplication()
        app.launchArguments = ["-skipAuth", "-onboarding.done", "YES", "-profileTab", "-profileBottom"]
        app.launch()

        XCTAssertTrue(app.buttons["Load the sample fridge"].waitForExistence(timeout: 8),
                      "게스트는 샘플 로드 행을 봐야 한다")
        XCTAssertTrue(app.buttons["Reset all data"].waitForExistence(timeout: 4),
                      "Reset 행은 게스트에서도 항상 있어야 한다")
    }

    // MARK: 게스트→계정 전환 행(37차)

    /// 게스트의 Account 영수증은 이제 정적 안내문 + 별도 "Log in / Sign up" 버튼(중복 진입점, 13차 교훈)
    /// 대신 행 전체가 하나의 탭 타깃인 `SettingsRow`다(라벨 "Guest mode" + 값 문구가 한 Button
    /// 접근성 요소로 병합된다 — Toggle과 같은 병합 규칙). 로그인 계정 쪽(Logged in + Log out 행)은
    /// 실제 Supabase 세션이 있어야 재현돼 이 UI 테스트로는 다루지 못한다 — 그 갈림은
    /// `accountReceipt`의 `if auth.isGuest` 분기 자체(뷰 로직)만으로 보장된다.
    func testProfile_GuestAccountRow_ShowsDeviceOnlyCopyAndOpensAuth() {
        let app = XCUIApplication()
        app.launchArguments = ["-skipAuth", "-onboarding.done", "YES", "-profileTab", "-profileBottom"]
        app.launch()

        let guestRow = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Guest mode")).firstMatch
        XCTAssertTrue(guestRow.waitForExistence(timeout: 8), "게스트는 탭 가능한 단일 Guest mode 행을 봐야 한다")
        XCTAssertTrue(guestRow.label.contains("stays on this device"),
                      "곁 문구는 서버 백업을 약속하지 않고 기기 보관만 정직하게 말해야 한다")

        guestRow.tap()
        XCTAssertTrue(app.buttons["Sign up"].waitForExistence(timeout: 4), "탭하면 로그인/가입 시트가 떠야 한다")
    }

    // MARK: 앱 내 언어 전환(38차)

    /// `.environment(\.locale)`이 실제로 라이브 반영되는지 확인한다 — `SettingsRow.label`·
    /// `QuietButton.title`은 `LocalizedStringKey`라 재실행 없이 곧바로 새 언어로 뜬다는 것이
    /// `AppLanguage.swift`가 문서화한 "정직한 경계"의 절반이다(나머지 절반 — `String(localized:)`로
    /// 굳힌 값의 재실행 필요성 — 은 실행 중 검증이 불가능해 여기서 다루지 않는다). `Erase this device`를(42차 개명 — 실동작이 기기 삭제라)t`를
    /// 증인으로 쓴다 — 방금 만진 행을 다시 조회하는 것보다 독립적이라 더 신뢰할 수 있다.
    /// **정리**: 이 테스트는 실제로 `AppStorage`를 바꾸므로, 본문 끝에서 System default로 되돌리는
    /// UI 조작과 **별도로** `addTeardownBlock`을 맨 먼저 등록한다 — 본문 어디서 실패해 조기 종료돼도
    /// (예: 첫 회귀 당시처럼) `-resetLanguage`로 강제 리셋해 다음 테스트로의 캐스케이드를 막는다.
    func testProfile_LanguagePicker_SwitchesToKoreanLive() {
        addTeardownBlock {
            let reset = XCUIApplication()
            reset.launchArguments = ["-skipAuth", "-onboarding.done", "YES", "-resetLanguage"]
            reset.launch()
            reset.terminate()
        }

        let app = XCUIApplication()
        app.launchArguments = ["-skipAuth", "-onboarding.done", "YES", "-profileTab", "-profileBottom"]
        app.launch()

        let languageRow = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "App language")).firstMatch
        XCTAssertTrue(languageRow.waitForExistence(timeout: 8), "언어 행이 있어야 한다")
        languageRow.tap()

        let koreanOption = app.buttons["한국어"]
        XCTAssertTrue(koreanOption.waitForExistence(timeout: 4), "드롭다운에 한국어 옵션이 떠야 한다")
        koreanOption.tap()

        XCTAssertTrue(app.buttons["이 기기에서 지우기"].waitForExistence(timeout: 4),
                      "LocalizedStringKey 라벨은 재실행 없이 즉시 새 언어로 바뀌어야 한다")

        // 되돌리기 — 행의 값이 이제 "한국어"이므로 그 문자열로 다시 찾아 System default를 고른다.
        let languageRowAfter = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "한국어")).firstMatch
        XCTAssertTrue(languageRowAfter.waitForExistence(timeout: 4))
        languageRowAfter.tap()
        let systemOption = app.buttons["시스템 기본값"]
        XCTAssertTrue(systemOption.waitForExistence(timeout: 4))
        systemOption.tap()
        XCTAssertTrue(app.buttons["Erase this device"].waitForExistence(timeout: 4),
                      "System default로 되돌리면 영어 라벨도 즉시 돌아와야 한다")
    }
}
