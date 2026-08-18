import Testing
import Foundation
@testable import Reffi

/// 담기 3단 팝업(§13.5 ⑨ · §14.7)의 **순수한 부분**을 뷰 없이 고정한다.
///
/// ① 선택 매핑 — 체크된 것만, 원본 순서로. 이 함수가 어긋나면 사용자가 체크를 푼 재료가 그대로
///    장보기 메모에 실린다(팝업이 있으나 마나가 된다).
/// ② 발주 후 덱 닫기 유예의 QA 훅 파싱 — UI 테스트가 "그 창 안에서 팝업을 띄운다"를 재현하는
///    유일한 수단이라, 파싱이 조용히 깨지면 레이스 회귀가 통과로 위장된다.
@MainActor
struct ToBuyPickFlowTests {

    // MARK: ① 선택 매핑

    /// 기본 상태(전부 체크) — 부족하다고 이미 판정된 목록이라 기본값이 '전부'다.
    @Test func allCheckedSelectsEverythingInOrder() {
        let items = ["beef", "garlic", "sesame oil"]
        let picked = PaperChecklistDialog.selected(items, checked: Set(items.indices))
        #expect(picked == items)
    }

    /// 하나를 풀면 **그 하나만** 빠진다 — 나머지 순서는 그대로다(목록의 읽는 순서 = 담기는 순서).
    @Test func uncheckedItemIsExcludedAndOrderSurvives() {
        let items = ["beef", "garlic", "sesame oil"]
        #expect(PaperChecklistDialog.selected(items, checked: [0, 2]) == ["beef", "sesame oil"])
        #expect(PaperChecklistDialog.selected(items, checked: [2, 0]) == ["beef", "sesame oil"])
    }

    /// 하나도 체크되지 않은 상태 — **빈 배열**이다. 화면에서는 CTA가 `disabled`라 도달하지 않지만,
    /// 도달하더라도 "아무것도 담지 않는다"가 유일하게 옳은 결과다(전부 담기로 폴백하지 않는다).
    @Test func noneCheckedSelectsNothing() {
        #expect(PaperChecklistDialog.selected(["beef", "garlic"], checked: []).isEmpty)
    }

    /// 범위 밖 인덱스는 무시한다 — 목록이 줄어든 뒤 남은 체크가 크래시를 만들면 안 된다.
    @Test func staleIndicesAreIgnored() {
        #expect(PaperChecklistDialog.selected(["beef"], checked: [0, 7, -1]) == ["beef"])
        #expect(PaperChecklistDialog.selected([String](), checked: [0, 1]).isEmpty)
    }

    /// 표기가 같은 두 줄도 **각자의 체크를 갖는다** — 선택 집합이 인덱스인 이유가 이것이다
    /// (캐논 키로 묶으면 한쪽 체크가 다른 쪽을 함께 켜고 끈다).
    @Test func duplicateNamesKeepIndependentChecks() {
        let items = ["water", "water"]
        #expect(PaperChecklistDialog.selected(items, checked: [1]) == ["water"])
        #expect(PaperChecklistDialog.selected(items, checked: [0, 1]).count == 2)
    }

    // MARK: ② `-fireDismissDelay` 파싱

    #if DEBUG
    /// 인자가 없으면 기본 1.25초 — 프로덕션 감각(슬램 도장을 보는 시간)이 그대로다.
    @Test func defaultFireDismissDelay() {
        #expect(MainView.fireDismissDelay(from: []) == MainView.defaultFireDismissDelay)
        #expect(MainView.fireDismissDelay(from: ["-skipAuth", "-cookCarousel"]) == 1.25)
    }

    /// 값이 붙으면 그 값으로 넓힌다 — UI 테스트가 6초 창을 여는 경로다.
    @Test func explicitFireDismissDelay() {
        #expect(MainView.fireDismissDelay(from: ["-fireDismissDelay", "6"]) == 6)
        #expect(MainView.fireDismissDelay(from: ["-x", "-fireDismissDelay", "2.5", "-y"]) == 2.5)
    }

    /// 망가진 인자는 **조용히 기본값**으로 — 값이 빠졌거나 숫자가 아니거나 0 이하면 무시한다.
    /// 0을 허용하면 발주 즉시 덱이 닫혀 슬램 도장을 못 보고, 음수는 의미가 없다.
    @Test func malformedFireDismissDelayFallsBack() {
        let d = MainView.defaultFireDismissDelay
        #expect(MainView.fireDismissDelay(from: ["-fireDismissDelay"]) == d)
        #expect(MainView.fireDismissDelay(from: ["-fireDismissDelay", "soon"]) == d)
        #expect(MainView.fireDismissDelay(from: ["-fireDismissDelay", "0"]) == d)
        #expect(MainView.fireDismissDelay(from: ["-fireDismissDelay", "-3"]) == d)
    }
    #endif

    // MARK: ③ 결과 알림 수 — "이미 있었다"는 줄 수가 아니라 **목록 키 수**로 센다

    /// 두 항목이 같은 장보기 표제어로 풀리면(커스텀 레시피의 "다진 마늘"+"마늘 한 쪽") 목록엔 한
    /// 줄만 생긴다 — `picked.count - added`로 세면 나머지 하나가 "이미 있었다"로 둔갑해 결과
    /// 알림("The rest were already on your list.")이 거짓말을 한다.
    @Test func alreadyCountCollapsesSameCanonPicks() {
        let garlicTwice = [Recipe.Item(ref: nil, en: "minced garlic", ko: nil),
                           Recipe.Item(ref: nil, en: "fresh garlic", ko: nil)]
        // 사전 실측 고정 — 두 표기 모두 머리말 일치로 garlic 하나에 붙는다(전제가 무너지면 여기서 깨진다).
        #expect(Set(garlicTwice.map { RecipeRecommender.toBuyEntry(for: $0).canonicalID }) == ["garlic"])
        // 목록이 비어 있었다면 한 줄이 새로 생긴다(added 1) — "이미 있었다"는 0이어야 한다.
        #expect(RecipeMemoCarousel.alreadyOnListCount(picked: garlicTwice, added: 1) == 0)
        // 이미 garlic이 있었다면(added 0) "이미 있었다"도 키 기준 1이다 — 2가 아니라.
        #expect(RecipeMemoCarousel.alreadyOnListCount(picked: garlicTwice, added: 0) == 1)
    }

    /// 서로 다른 키로 풀리는 평범한 선택 — 키 수 = 줄 수라 기존 셈과 같은 값이다(회귀 없음).
    @Test func alreadyCountMatchesLineCountForDistinctPicks() {
        let items = [Recipe.Item(ref: "beef", en: "beef", ko: nil),
                     Recipe.Item(ref: "carrot", en: "carrot", ko: nil),
                     Recipe.Item(ref: "onion", en: "onion", ko: nil)]
        #expect(RecipeMemoCarousel.alreadyOnListCount(picked: items, added: 3) == 0)
        #expect(RecipeMemoCarousel.alreadyOnListCount(picked: items, added: 1) == 2)
        #expect(RecipeMemoCarousel.alreadyOnListCount(picked: items, added: 0) == 3)
    }

    // MARK: ④ 직접 입력 담기 — 해석은 정확 일치까지, 포함 매칭 금지

    /// 자유 입력("Fish sauce brand X")이 포함 매칭으로 남의 캐논에 붙으면, 그 캐논이 이미 목록에
    /// 있을 때 **담기가 조용한 no-op**이 된다(43ecb3a가 레시피 표기에서 막은 기전의 자유 입력판).
    /// `addTyped`와 같은 식(정확 일치 + `canonicalIsFinal`)으로 store를 태워 자유 항목이 자유
    /// 항목으로 남는 것을 고정한다.
    @Test func typedAddKeepsFreeTextFreeEvenWhenItContainsALexiconWord() {
        let store = FridgeStore(ingredients: [], recipes: [], history: [])
        // 목록에 이미 fish(사전 표제어)가 있다.
        #expect(store.addToBuy(name: "fish", canonicalID: "fish"))
        // 포함 매칭이라면 "fish"에 붙어 중복 no-op이 됐을 자유 입력 — 정확 일치+종결이라 새 줄이 생긴다.
        let typed = "Fish sauce brand X"
        let canon = IngredientLexicon.shared.exactCanonicalID(for: typed)
        #expect(canon == nil)
        #expect(store.addToBuy(name: typed, canonicalID: canon, canonicalIsFinal: true),
                "자유 입력이 남의 캐논에 흡수돼 담기지 않으면 안 된다")
        #expect(store.manualToBuy.map(\.name).contains(typed))
        // 정확 일치 입력은 여전히 캐논으로 묶인다 — 사전 표기를 친 사람은 표제어 줄을 받는다.
        #expect(IngredientLexicon.shared.exactCanonicalID(for: "우유") == "milk")
    }
}
