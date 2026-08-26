#if DEBUG
import Testing
import Foundation
@testable import Reffi

/// 밀기 어포던스 힌트(28차)의 **순수 로직** — 언제 뜨는가(`shouldPeek`)와 QA 인자 해석
/// (`swipeHintConfig(from:)`). 둘 다 뷰 상태에서 떼어 낸 함수라 시뮬레이터 없이 갈래를 전부 고정한다
/// (`FridgeTab.initial(from:)`·`MainView.fireDismissDelay(from:)` 선례).
///
/// 이 힌트는 **설치당 한 번**이라 실사용에서 재현 기회가 사실상 없다 — 조건 하나가 어긋나면 그 설치의
/// 유일한 재생이 조용히 사라지고 아무도 알아채지 못한다. 그래서 판정을 여기서 잠근다.
struct ToBuySwipeHintTests {

    // MARK: shouldPeek — 다섯 게이트

    /// 기본형: 행이 있고, 아직 안 봤고, 모션 축소가 아니고, 손이 안 닿았고, 시트도 없다.
    @Test func peeksOnFirstOpenWithRows() {
        #expect(ShoppingListContent.shouldPeek(rowCount: 1, seen: false, reduceMotion: false,
                                               userSwiped: false, sheetUp: false, forced: false))
        #expect(ShoppingListContent.shouldPeek(rowCount: 9, seen: false, reduceMotion: false,
                                               userSwiped: false, sheetUp: false, forced: false))
    }

    /// 빈 목록엔 밀 행이 없다 — 강제 인자로도 뜨지 않는다(움직일 대상 자체가 없다).
    @Test func neverPeeksOnEmptyList() {
        #expect(!ShoppingListContent.shouldPeek(rowCount: 0, seen: false, reduceMotion: false,
                                                userSwiped: false, sheetUp: false, forced: false))
        #expect(!ShoppingListContent.shouldPeek(rowCount: 0, seen: false, reduceMotion: false,
                                                userSwiped: false, sheetUp: false, forced: true))
    }

    /// 한 번 본 뒤에는 다시 뜨지 않는다(설치당 한 번).
    @Test func doesNotRepeatOnceSeen() {
        #expect(!ShoppingListContent.shouldPeek(rowCount: 3, seen: true, reduceMotion: false,
                                                userSwiped: false, sheetUp: false, forced: false))
    }

    /// **모션 축소면 재생하지 않는다**(§7.4). 그리고 이 함수가 거짓을 돌려주면 호출부는 기록도 하지
    /// 않으므로, 나중에 축소를 끄면 힌트가 그때 처음 뜬다 — 아무것도 못 본 채 기회가 사라지지 않게.
    /// `seen: false`로 확인하는 것이 요점이다: 축소가 플래그보다 **먼저** 걸린다는 뜻이다.
    @Test func skipsUnderReduceMotionWithoutConsumingTheFlag() {
        #expect(!ShoppingListContent.shouldPeek(rowCount: 2, seen: false, reduceMotion: true,
                                                userSwiped: false, sheetUp: false, forced: false))
        // 강제 인자도 모션 축소를 이기지 못한다 — QA 편의가 접근성 설정을 덮으면 안 된다.
        #expect(!ShoppingListContent.shouldPeek(rowCount: 2, seen: false, reduceMotion: true,
                                                userSwiped: false, sheetUp: false, forced: true))
    }

    /// 이 등장에서 사용자가 이미 행을 밀었으면(또는 뺐으면) 뜨지 않는다 — 아는 동작을 다시 가르치지 않는다.
    @Test func skipsAfterUserAlreadySwiped() {
        #expect(!ShoppingListContent.shouldPeek(rowCount: 4, seen: false, reduceMotion: false,
                                                userSwiped: true, sheetUp: false, forced: false))
        #expect(!ShoppingListContent.shouldPeek(rowCount: 4, seen: false, reduceMotion: false,
                                                userSwiped: true, sheetUp: false, forced: true))
    }

    /// 검색 시트가 올라와 있으면 재생이 통째로 가려진다 — 덮인 채 돌면 플래그만 소진된다.
    @Test func skipsWhileSearchSheetCoversTheList() {
        #expect(!ShoppingListContent.shouldPeek(rowCount: 4, seen: false, reduceMotion: false,
                                                userSwiped: false, sheetUp: true, forced: false))
    }

    /// 강제(QA)는 **플래그만** 무시한다 — 위 네 게이트(빈 목록·모션 축소·이미 밀었음·시트)는 그대로다.
    @Test func forcedIgnoresSeenFlagOnly() {
        #expect(ShoppingListContent.shouldPeek(rowCount: 1, seen: true, reduceMotion: false,
                                               userSwiped: false, sheetUp: false, forced: true))
        #expect(!ShoppingListContent.shouldPeek(rowCount: 1, seen: true, reduceMotion: false,
                                                userSwiped: false, sheetUp: false, forced: false))
    }

    // MARK: swipeHintConfig — `-toBuy.swipeHint [초]`

    /// 인자가 없으면 강제하지 않고 유지 시간도 기본값이다.
    @Test func configDefaultsWithoutArgument() {
        let c = ShoppingListContent.swipeHintConfig(from: [])
        #expect(c.forced == false)
        #expect(c.hold == ShoppingListContent.defaultPeekHold)

        let d = ShoppingListContent.swipeHintConfig(from: ["-skipAuth", "-toBuy", "-loadSample"])
        #expect(d.forced == false)
        #expect(d.hold == ShoppingListContent.defaultPeekHold)
    }

    /// 값 없이 주면 강제만 켜고 유지 시간은 기본값 — 손으로 스크린샷을 찍는 흔한 경로다.
    @Test func configForcesWithDefaultHoldWhenValueOmitted() {
        let c = ShoppingListContent.swipeHintConfig(from: ["-toBuy.swipeHint"])
        #expect(c.forced)
        #expect(c.hold == ShoppingListContent.defaultPeekHold)
    }

    /// 양수를 붙이면 유지 시간이 그 값으로 넓어진다 — XCUITest가 "지금 밀려 있다"를 잡을 창이다.
    @Test func configWidensHoldWhenPositiveValueGiven() {
        let c = ShoppingListContent.swipeHintConfig(from: ["-toBuy.swipeHint", "6"])
        #expect(c.forced)
        #expect(c.hold == 6)

        let d = ShoppingListContent.swipeHintConfig(from: ["-toBuy.swipeHint", "2.5", "-toBuy"])
        #expect(d.forced)
        #expect(d.hold == 2.5)
    }

    /// 망가진 값(숫자 아님·0·음수·뒤에 아무것도 없음)은 **다음 토큰을 소비하지 않고** 기본값으로 둔다.
    /// 0이나 음수를 그대로 받으면 밀린 채로 머무는 시간이 사라져(또는 뒤집혀) 힌트가 깜빡임이 된다.
    @Test func configFallsBackOnBrokenValues() {
        for args in [["-toBuy.swipeHint", "soon"], ["-toBuy.swipeHint", "0"],
                     ["-toBuy.swipeHint", "-1"], ["-toBuy.swipeHint"],
                     ["-toBuy.swipeHint", "-fridgeTab"]] {
            let c = ShoppingListContent.swipeHintConfig(from: args)
            #expect(c.forced, "인자 자체는 있으므로 강제는 유지된다: \(args)")
            #expect(c.hold == ShoppingListContent.defaultPeekHold, "망가진 값은 기본값: \(args)")
        }
    }

    /// **플래그 주입 인자와 이름이 겹치지 않는다.** `-toBuy.swipeHintSeen YES`는 UserDefaults로
    /// `@AppStorage("toBuy.swipeHintSeen")`을 덮는 인자이고, 이 파서가 접두어 매칭을 하면 그 인자만
    /// 줘도 힌트가 강제로 켜져 "플래그가 서 있으면 안 뜬다"를 재현할 수 없게 된다.
    @Test func configDoesNotMatchTheSeenFlagArgument() {
        let c = ShoppingListContent.swipeHintConfig(from: ["-toBuy.swipeHintSeen", "YES"])
        #expect(c.forced == false)
        #expect(c.hold == ShoppingListContent.defaultPeekHold)
    }

    // MARK: 모션 값

    /// 기본 유지 시간은 **0보다 크고 1초보다 짧다** — 0이면 밀렸다는 사실이 프레임 사이로 사라져
    /// 깜빡임이 되고, 1초를 넘으면 열린 행이 응답을 멈춘 것처럼 읽힌다(장식 모션이 흐름을 잡는다).
    /// 위 `configFallsBackOnBrokenValues`가 이 값을 폴백으로 쓰므로 범위도 함께 잠근다.
    @Test func defaultHoldStaysInsideTheDeliberateBand() {
        #expect(ShoppingListContent.defaultPeekHold > 0)
        #expect(ShoppingListContent.defaultPeekHold < 1)
    }
}
#endif
