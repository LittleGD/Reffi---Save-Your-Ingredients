import Testing
@testable import Reffi

/// `DataOwner.shouldWipe(previous:newID:)`(2026-08, 37차) — 게스트→계정 전환에서 로컬 데이터가
/// 언제 지워지는가(그리고 언제 지워지지 않아야 하는가)를 뷰 없이 고정한다.
/// `RootGateView.reconcileDataOwner`의 문서 주석이 적은 세 경로를 그대로 검증한다:
///   ① 같은 계정 재로그인 = previous == newID → 와이프 없음
///   ② 익명→가입 승계·최초 기록 = previous == nil → 와이프 없음(게스트로 쌓은 데이터가 살아남는다)
///   ③ 다른 계정으로 전환 = previous != nil && previous != newID → 와이프
struct DataOwnerTests {
    @Test func sameAccountRelogin_NoWipe() {
        #expect(!DataOwner.shouldWipe(previous: "user-a", newID: "user-a"))
    }

    @Test func anonymousUpgradeOrFirstRecord_NoWipe() {
        // previous == nil은 "이 기기가 아직 어떤 정식 계정도 기록한 적 없다"는 뜻이다 — 익명 게스트로
        // 쌓은 로컬 데이터가 가입 순간 지워지면 안 되는 바로 그 경로다.
        #expect(!DataOwner.shouldWipe(previous: nil, newID: "user-a"))
    }

    @Test func differentAccountLogin_Wipes() {
        #expect(DataOwner.shouldWipe(previous: "user-a", newID: "user-b"))
    }
}
