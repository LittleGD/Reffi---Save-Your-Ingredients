import Testing
@testable import Reffi

/// Data 영수증의 "Load the sample fridge" 행 노출 규칙(`ProfileView.showsSampleLoad(isGuest:)`,
/// 2026-08 36차) — 게스트에게만 보이고, 로그인 계정에는 Reset 행만 남아야 한다.
/// `FridgeTab.initial(from:)` 선례와 같은 문법: 뷰를 띄우지 않고 순수 규칙만 여기서 고정한다.
struct ProfileDataVisibilityTests {
    @Test func guestSeesSampleLoad() {
        #expect(ProfileView.showsSampleLoad(isGuest: true))
    }

    @Test func signedInAccountHidesSampleLoad() {
        #expect(!ProfileView.showsSampleLoad(isGuest: false))
    }
}
