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
}
