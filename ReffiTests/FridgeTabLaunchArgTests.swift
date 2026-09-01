#if DEBUG
import Testing
import Foundation
@testable import Reffi

/// 냉장고 진입 탭 파서(`FridgeTab.initial(from:)`) — 옛 `-toBuy`/`-toBuy.search`/`-showHistory`는
/// 풀스크린 커버를 여는 인자였고, 세 탭 구조에서는 **같은 목적지의 탭**으로 착지해야 한다.
/// QA·스크린샷 자동화가 이 매핑 하나에 매여 있으므로(RUN.md QA 절) 뷰를 띄우지 않고 여기서 고정한다.
struct FridgeTabLaunchArgTests {

    /// 인자가 없으면 기본은 재고 목록 — 냉장고를 열었을 때 먼저 보여야 하는 화면이다.
    @Test func defaultsToStock() {
        #expect(FridgeTab.initial(from: []) == .stock)
        #expect(FridgeTab.initial(from: ["/path/to/Reffi", "-skipAuth", "-loadSample"]) == .stock)
    }

    /// `-toBuy` — 옛 To buy 커버 직행 인자가 To buy 탭으로 착지한다.
    @Test func toBuyArgLandsOnToBuyTab() {
        #expect(FridgeTab.initial(from: ["-toBuy"]) == .toBuy)
    }

    /// `-toBuy.search` **단독** — 검색 시트를 여는 인자라도 먼저 To buy 탭에 닿아야 한다
    /// (시트를 실제로 여는 건 `ShoppingListContent`의 몫이고, 착지는 이 함수의 몫이다).
    @Test func toBuySearchArgAloneLandsOnToBuyTab() {
        #expect(FridgeTab.initial(from: ["-toBuy.search"]) == .toBuy)
    }

    /// `-toBuy.swipeHint` **단독** — 밀기 어포던스 힌트를 강제하는 인자도 To buy 패인에 닿아야
    /// QA·스크린샷이 한 줄로 끝난다(재생은 `ShoppingListContent`, 착지는 이 함수).
    @Test func swipeHintArgAloneLandsOnToBuyTab() {
        #expect(FridgeTab.initial(from: ["-toBuy.swipeHint"]) == .toBuy)
        #expect(FridgeTab.initial(from: ["-toBuy.swipeHint", "6"]) == .toBuy)
    }

    /// QA 인자(`-toBuy.swipeHintSeen`)는 **착지를 바꾸지 않는다** — 그건 밀기 힌트를 이미 본 상태로
    /// 세우는 값이지(52차부터 프로세스 스코프 플래그를 시드한다, `ShoppingListContent` 참고) 목적지
    /// 지시가 아니다. 우연히 문자열 포함 매칭을 했다면 여기서 To buy로 새어 나간다.
    @Test func seenFlagArgDoesNotChangeLanding() {
        #expect(FridgeTab.initial(from: ["-toBuy.swipeHintSeen"]) == .stock)
    }

    /// `-showHistory` — 옛 History 커버 직행 인자가 History 탭으로 착지한다.
    @Test func showHistoryArgLandsOnHistoryTab() {
        #expect(FridgeTab.initial(from: ["-showHistory"]) == .history)
    }

    /// 둘 다 주어지면 To buy가 이긴다 — 검색 시트까지 여는 쪽이 더 구체적인 지시다.
    /// 우선순위가 없으면 인자 순서에 따라 결과가 흔들려 스크린샷 자동화가 비결정적이 된다.
    @Test func toBuyWinsOverHistoryWhenBothGiven() {
        #expect(FridgeTab.initial(from: ["-showHistory", "-toBuy"]) == .toBuy)
        #expect(FridgeTab.initial(from: ["-toBuy", "-showHistory"]) == .toBuy)
    }

    /// 비슷하게 생긴 다른 인자에 걸리지 않는다 — `-fridgeTab`은 루트 탭 인자지 냉장고 안쪽 탭이 아니다.
    @Test func ignoresUnrelatedArguments() {
        #expect(FridgeTab.initial(from: ["-fridgeTab", "-fridgeExpand", "-fridge.sortOpen"]) == .stock)
    }

    /// rawValue는 영속·식별용 안정 키다 — 순서를 바꿔도 값이 따라 움직이면 안 된다.
    @Test func rawValuesAreStable() {
        #expect(FridgeTab.stock.rawValue == "stock")
        #expect(FridgeTab.toBuy.rawValue == "toBuy")
        #expect(FridgeTab.history.rawValue == "history")
        #expect(FridgeTab.allCases == [.stock, .toBuy, .history])
    }
}
#endif
