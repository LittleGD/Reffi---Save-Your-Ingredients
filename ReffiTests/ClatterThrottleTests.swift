import Testing
import Foundation
@testable import Reffi

/// 달그락 햅틱 스로틀 — 이 기능의 품질은 사실상 전부 필터링에서 갈린다(정지한 더미에서 웅웅대면 실패).
/// 씬 없이 돌릴 수 있는 순수 로직이라 여기서 세 관문을 전부 고정한다.
struct ClatterThrottleTests {
    private func make() -> ClatterThrottle {
        var t = ClatterThrottle()
        t.minImpulse = 6
        t.minInterval = 0.045
        t.pairCooldown = 0.14
        return t
    }

    /// 관문 ① — 임계값 미만(스치는 접촉·안착 중 맞닿음)은 절대 발화하지 않는다.
    @Test func ignoresGrazingContacts() {
        var t = make()
        #expect(t.allow(impulse: 0.5, pair: ClatterPair(1, 2), now: 0) == false)
        #expect(t.allow(impulse: 5.9, pair: ClatterPair(1, 2), now: 1) == false)
    }

    @Test func firesAboveThreshold() {
        var t = make()
        #expect(t.allow(impulse: 6, pair: ClatterPair(1, 2), now: 0) == true)
    }

    /// 관문 ② — 전역 최소 간격. 서로 다른 쌍이라도 너무 촘촘하면 뭉개지므로 막는다.
    @Test func globalIntervalThrottlesDifferentPairs() {
        var t = make()
        #expect(t.allow(impulse: 50, pair: ClatterPair(1, 2), now: 0) == true)
        #expect(t.allow(impulse: 50, pair: ClatterPair(3, 4), now: 0.02) == false)   // 20ms — 너무 빠름
        #expect(t.allow(impulse: 50, pair: ClatterPair(3, 4), now: 0.05) == true)    // 50ms — 통과
    }

    /// 관문 ③ — 같은 쌍은 쿨다운 동안 다시 못 울린다(두 재료가 비빌 때의 연타 방지).
    @Test func samePairCoolsDown() {
        var t = make()
        #expect(t.allow(impulse: 50, pair: ClatterPair(1, 2), now: 0) == true)
        #expect(t.allow(impulse: 50, pair: ClatterPair(1, 2), now: 0.10) == false)   // 쿨다운 중
        #expect(t.allow(impulse: 50, pair: ClatterPair(1, 2), now: 0.15) == true)    // 쿨다운 경과
    }

    /// 쌍은 순서 무관 — (A,B)와 (B,A)는 같은 쌍이라 쿨다운을 공유해야 한다.
    @Test func pairIsOrderIndependent() {
        #expect(ClatterPair(7, 3) == ClatterPair(3, 7))
        var t = make()
        #expect(t.allow(impulse: 50, pair: ClatterPair(7, 3), now: 0) == true)
        #expect(t.allow(impulse: 50, pair: ClatterPair(3, 7), now: 0.06) == false)
    }

    /// 정지한 더미 시나리오 — 미세 접촉이 매 프레임 쏟아져도 발화는 0이어야 한다.
    /// 이게 깨지면 손에 계속 진동이 남는다(사용자가 가장 싫어할 실패 모드).
    @Test func settledPileStaysSilent() {
        var t = make()
        var fired = 0
        for frame in 0..<600 {                       // 10초치
            let now = TimeInterval(frame) / 60
            if t.allow(impulse: 1.5, pair: ClatterPair(frame % 5, frame % 3), now: now) { fired += 1 }
        }
        #expect(fired == 0)
    }

    /// 격렬한 흔들기 시나리오 — 발화는 되지만 전역 간격 상한(≈22Hz)을 넘지 않는다.
    @Test func shakeIsRateLimited() {
        var t = make()
        var fired = 0
        for frame in 0..<600 {                       // 10초치, 매 프레임 강한 충돌
            let now = TimeInterval(frame) / 60
            if t.allow(impulse: 80, pair: ClatterPair(frame, frame + 1000), now: now) { fired += 1 }
        }
        #expect(fired > 0)
        #expect(fired <= Int(10.0 / 0.045) + 1)      // 10초 / 45ms
    }

    /// reset 후엔 쿨다운이 사라져 곧바로 다시 울릴 수 있다.
    @Test func resetClearsCooldowns() {
        var t = make()
        #expect(t.allow(impulse: 50, pair: ClatterPair(1, 2), now: 0) == true)
        #expect(t.allow(impulse: 50, pair: ClatterPair(1, 2), now: 0.05) == false)
        t.reset()
        #expect(t.allow(impulse: 50, pair: ClatterPair(1, 2), now: 0.05) == true)
    }
}
