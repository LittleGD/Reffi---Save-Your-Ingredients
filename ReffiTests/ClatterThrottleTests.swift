import Testing
import Foundation
@testable import Reffi

/// 달그락 햅틱 스로틀 — 이 기능의 품질은 사실상 전부 필터링에서 갈린다(정지한 더미에서 웅웅대면 실패).
/// 씬 없이 돌릴 수 있는 순수 로직이라 여기서 세 관문을 전부 고정한다.
struct ClatterThrottleTests {
    /// 관문 하나하나를 딱 떨어지는 경계로 보려고 값을 덮어쓴 **테스트 전용** 스로틀.
    /// 지터는 0으로 끈다 — 여기서 보려는 건 게이트의 존재이지 리듬의 비양자화가 아니고,
    /// 지터가 켜져 있으면 "45ms에 통과" 같은 단언이 시퀀스에 따라 흔들린다.
    /// 비양자화 자체는 아래 `rhythm…` 테스트가 출하값으로 따로 본다.
    private func make() -> ClatterThrottle {
        var t = ClatterThrottle()
        t.minImpulse = 6
        t.minInterval = 0.045
        t.intervalJitter = 0
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

    /// 격렬한 흔들기 시나리오 — 발화는 되지만 전역 간격 상한을 넘지 않는다.
    /// (여기서 쓰는 make()의 45ms = ≈22Hz는 **테스트 전용 값**이다. 출하값 90ms = 11Hz는
    ///  아래 shippingDefaults… 테스트가 따로 고정한다.)
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

    /// **출하 경로 고정** — 씬은 `ClatterThrottle()` 기본값을 그대로 쓴다(IngredientDropScene).
    /// 위 테스트들은 전부 make()로 값을 덮어써서, 이게 없으면 출하값(20 / 0.09±0.02 / 0.26)을
    /// 되돌리거나 오타로 바꿔도 전부 초록이었다. 전역 간격은 이제 **구간**이라 경계로 단언한다.
    @Test func shippingDefaultsGateAtTwentyAndSeventyToOneTenMilliseconds() {
        var t = ClatterThrottle()                    // 덮어쓰기 없음 — 출하값 그대로
        #expect(t.minImpulse == 20)
        #expect(t.minInterval == 0.09)
        #expect(t.intervalJitter == 0.02)
        #expect(t.pairCooldown == 0.26)
        // 관문 ① — 임펄스 19는 막히고 20은 통과한다(구르는 중의 잔접촉 vs 또렷한 노크).
        #expect(t.allow(impulse: 19, pair: ClatterPair(1, 2), now: 0) == false)
        #expect(t.allow(impulse: 20, pair: ClatterPair(1, 2), now: 0) == true)
        // 관문 ② — 전역 간격은 70~110ms 구간. 69ms는 **어떤 시퀀스에서도** 막히고
        // 111ms는 **어떤 시퀀스에서도** 통과한다(구간 밖 경계라 지터와 무관하게 결정적이다).
        #expect(t.allow(impulse: 50, pair: ClatterPair(3, 4), now: 0.069) == false)
        #expect(t.allow(impulse: 50, pair: ClatterPair(3, 4), now: 0.111) == true)
        // 관문 ③ — 같은 쌍 260ms. 전역 간격은 넘겼지만 쌍 쿨다운에 걸린다.
        #expect(t.allow(impulse: 50, pair: ClatterPair(3, 4), now: 0.30) == false)
        #expect(t.allow(impulse: 50, pair: ClatterPair(3, 4), now: 0.38) == true)
    }

    /// 지터 구간 고정 — 어떤 발화 순번에서도 게이트는 70~110ms 안이다.
    /// (하한이 새면 액추에이터가 못 따라가 뭉개지고, 상한이 새면 격렬히 흔들 때 촉감이 듬성해진다.)
    @Test func gateIntervalStaysInsideSeventyToOneTenMilliseconds() {
        for n in UInt64(0)..<2000 {
            let g = ClatterThrottle.gateInterval(center: 0.09, jitter: 0.02, sequence: n)
            #expect(g >= 0.07 && g <= 0.11)
        }
    }

    /// 지터를 0으로 끄면 게이트는 정확히 중심값이다 — make()가 기대는 성질.
    @Test func zeroJitterKeepsGateExact() {
        #expect(ClatterThrottle.gateInterval(center: 0.045, jitter: 0, sequence: 7) == 0.045)
    }

    /// **비양자화** — 실기기 3차 "햅틱이 고정된 느낌"의 절반이 11Hz 격자였다.
    /// 매 ms마다 강한 충돌이 쏟아지는 극한에서, 발화 간격이 한 값에 붙지 않고 흩어져야 한다.
    @Test func rhythmIsNotQuantizedToASingleInterval() {
        var t = ClatterThrottle()
        var fires: [TimeInterval] = []
        for step in 0..<6000 {                       // 6초치, 1ms 스텝
            let now = TimeInterval(step) / 1000
            if t.allow(impulse: 80, pair: ClatterPair(step, step + 100_000), now: now) { fires.append(now) }
        }
        let gapsMs = zip(fires.dropFirst(), fires).map { Int((($0 - $1) * 1000).rounded()) }
        #expect(gapsMs.count > 40)
        #expect(Set(gapsMs).count >= 5)              // 한 값에 고착돼 있지 않다
        #expect(gapsMs.allSatisfy { (70...111).contains($0) })
    }

    /// 지터는 난수가 아니라 **발화 순번 해시**다 — 같은 충돌 시퀀스는 실행마다 같은 리듬이어야
    /// 튜닝을 비교하고 계측 QA를 신뢰할 수 있다.
    @Test func rhythmIsReproducibleAcrossRuns() {
        func run() -> [TimeInterval] {
            var t = ClatterThrottle()
            var fires: [TimeInterval] = []
            for step in 0..<2000 {
                let now = TimeInterval(step) / 1000
                if t.allow(impulse: 80, pair: ClatterPair(step, step + 100_000), now: now) { fires.append(now) }
            }
            return fires
        }
        #expect(run() == run())
    }

    /// 발화 순번은 촉감 변주의 시드이기도 하다 — 통과할 때만 오르고, 막힌 충돌엔 오르지 않는다.
    @Test func fireCountAdvancesOnlyOnFire() {
        var t = ClatterThrottle()
        #expect(t.fireCount == 0)
        #expect(t.allow(impulse: 5, pair: ClatterPair(1, 2), now: 0) == false)
        #expect(t.fireCount == 0)
        #expect(t.allow(impulse: 50, pair: ClatterPair(1, 2), now: 0) == true)
        #expect(t.fireCount == 1)
        // reset은 쿨다운만 버리고 순번은 이어 간다 — 0으로 되돌리면 탭을 오갈 때마다
        // 같은 지터·변주 패턴이 처음부터 반복돼 규칙성이 되살아난다.
        t.reset()
        #expect(t.fireCount == 1)
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
