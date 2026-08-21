import Testing
import Foundation
@testable import Reffi

/// 달그락 **촉감 변조** — 실기기 3차 피드백 "햅틱이 딱딱하고 인위적·고정된 느낌"에 대한 수정의
/// 검증면이다. 촉감의 자연스러움 자체는 실기기에서만 판정되지만, **규칙**은 여기서 못박을 수 있다:
/// 다이내믹 레인지·임펄스에 따른 날카로움 변조·미세 변주의 결정성과 폭·꼬리 임계.
struct ClatterFeelTests {
    private let rule = ClatterFeelRule()
    /// 배율 1.0짜리 중립 재료 — 세기 곡선 자체를 보려면 재료 배율이 곱해지지 않아야 한다.
    private let plain = ClatterMaterial(sharpness: 0.5, scale: 1.0)

    // MARK: - 출하값 고정

    /// 씬은 `ClatterFeelRule()` 기본값을 그대로 쓴다. 이게 없으면 튜닝값을 되돌려도 전부 초록이다.
    @Test func shippingDefaults() {
        #expect(rule.minImpulse == 20)
        #expect(rule.ceilingImpulse == 90)
        #expect(rule.intensityFloor == 0.10)
        #expect(rule.sharpnessSwing == 0.12)
        #expect(rule.variation == 0.08)
        #expect(rule.tailOnset == 0.67)
        #expect(rule.tailShortest == 0.040)
        #expect(rule.tailLongest == 0.070)
        #expect(rule.decaySwing == 0.35)
        #expect(rule.tailLead == 0.012)
        #expect(rule.tailSweep == 0.45)
    }

    /// 재료를 안 주면 예전 촉감 그대로여야 한다 — `decay` 기본값 0.5는 **중립**이라는 계약이다.
    /// 이게 깨지면 표에 없는 글리프(= `.standard`)의 촉감이 소리 없이 달라진다.
    @Test func neutralDecayLeavesDurationUnchanged() {
        #expect(abs(rule.decayFactor(0.5) - 1) < 1e-9)
        #expect(ClatterMaterial(sharpness: 0.5, scale: 1).decay == 0.5)
    }

    /// 세기 곡선의 시작점은 스로틀의 임펄스 관문과 **같은 값이어야** 한다. 어긋나면 관문을 갓 넘은
    /// 충돌이 이미 세기 0이 아닌 곳에서 시작하거나(점프), 관문 아래 구간이 곡선에 낭비된다.
    @Test func floorMatchesThrottleGate() {
        #expect(rule.minImpulse == ClatterThrottle().minImpulse)
    }

    // MARK: - 다이내믹 레인지

    /// 플로어를 0.18 → 0.10으로 낮춘 이유가 이것 — 약한 충돌과 센 충돌의 **비**가 손에 도착해야 한다.
    /// 옛 곡선(0.18~1.0)은 최대/최소가 5.6배라 손이 "세기 차이"보다 "같은 진동의 반복"을 먼저 읽었다.
    /// 새 곡선은 9배 이상 — 톡 스치는 것과 쿵 부딪히는 것이 다른 사건으로 도착한다.
    @Test func dynamicRangeSpansAtLeastNineFold() {
        let soft = rule.feel(impulse: 20, material: plain, sequence: 0).intensity
        let hard = rule.feel(impulse: 90, material: plain, sequence: 0).intensity
        #expect(soft < 0.12)                     // 변주 ±8%를 얹어도 0.108을 넘지 않는다
        #expect(hard > 0.9)
        #expect(hard / soft >= 9)
    }

    /// 임펄스가 오르면 세기도 오른다(단조). 변주가 있어도 뒤집히면 안 된다 —
    /// 순번을 고정하면 변주 계수가 상수라 순수 곡선의 단조성이 그대로 보인다.
    /// (상한 근처는 클램프로 평평해지므로 포화 전 구간에서 본다 — 포화는 아래 테스트가 따로 본다.)
    @Test func intensityIsMonotonicInImpulse() {
        var last: Float = -1
        for impulse in stride(from: CGFloat(20), through: 80, by: 5) {
            let v = rule.feel(impulse: impulse, material: plain, sequence: 3).intensity
            #expect(v > last)
            last = v
        }
    }

    /// 상한 위는 포화 — 200이든 2000이든 같은 세기(클램프가 없으면 1을 넘겨 CoreHaptics가 거부한다).
    @Test func intensitySaturatesAboveCeiling() {
        let a = rule.feel(impulse: 200, material: plain, sequence: 11)
        let b = rule.feel(impulse: 2000, material: plain, sequence: 11)
        #expect(a == b)
        #expect(a.intensity <= 1)
    }

    /// 관문 아래는 0으로 떨어지지 않고 플로어에 머문다(스로틀이 먼저 막으므로 도달하지 않지만,
    /// 순수 함수는 전역에서 정의돼야 한다 — 음수 t가 세기를 음수로 만들면 안 된다).
    @Test func belowGateClampsToFloor() {
        let v = rule.feel(impulse: 0, material: plain, sequence: 0).intensity
        #expect(v > 0.08 && v < 0.12)
    }

    /// 재료 배율은 곱으로 들어간다 — 여린 잎(0.42)이 캔(1.0)보다 확실히 약하게 친다.
    @Test func materialScaleMultipliesIntensity() {
        let leaf = rule.feel(impulse: 60, material: ClatterMaterial(sharpness: 0.55, scale: 0.42), sequence: 5)
        let can = rule.feel(impulse: 60, material: ClatterMaterial(sharpness: 0.95, scale: 1.0), sequence: 5)
        #expect(leaf.intensity < can.intensity * 0.5)
    }

    // MARK: - 날카로움 변조

    /// **세게 부딪히면 살짝 더 쨍하다.** 고정 상수였던 날카로움에 임펄스 변조를 얹은 것이
    /// "모든 충돌이 같은 파형"을 깨는 핵심이다. 클램프에 걸리지 않는 중간 재료로 본다.
    @Test func harderHitsAreSharper() {
        let mat = ClatterMaterial(sharpness: 0.68, scale: 0.85)     // rolling(계란·토마토)
        let weak = rule.feel(impulse: 20, material: mat, sequence: 9).sharpness
        let strong = rule.feel(impulse: 90, material: mat, sequence: 9).sharpness
        #expect(strong > weak + 0.15)                               // 변조 폭 ±0.12 = 총 0.24
    }

    /// 변조는 재료 성격을 **뒤집지 않는다** — 아무리 세게 쳐도 두부가 캔보다 쨍해지면 안 된다.
    @Test func materialCharacterSurvivesModulation() {
        let tofu = ClatterMaterial(sharpness: 0.10, scale: 0.50)
        let can = ClatterMaterial(sharpness: 0.95, scale: 1.0)
        let loudTofu = rule.feel(impulse: 90, material: tofu, sequence: 2).sharpness
        let quietCan = rule.feel(impulse: 20, material: can, sequence: 2).sharpness
        #expect(loudTofu < quietCan)
    }

    /// 날카로움은 항상 0...1 — 두부(0.10)를 약하게, 캔(0.95)을 세게 쳐도 새지 않는다.
    @Test func sharpnessStaysInRange() {
        for s in stride(from: Float(0), through: 1, by: 0.05) {
            for impulse in stride(from: CGFloat(0), through: 200, by: 10) {
                let v = rule.feel(impulse: impulse,
                                  material: ClatterMaterial(sharpness: s, scale: 1),
                                  sequence: UInt64(impulse)).sharpness
                #expect(v >= 0 && v <= 1)
            }
        }
    }

    // MARK: - 미세 변주 (결정성 · 폭)

    /// 같은 (임펄스, 재료, 순번)이면 **정확히 같은 촉감**. 난수였다면 여기서 깨진다 —
    /// 결정적이어야 같은 충돌 시퀀스를 두 번 돌려 튜닝을 비교할 수 있다.
    @Test func variationIsDeterministic() {
        for n in UInt64(0)..<64 {
            #expect(rule.feel(impulse: 55, material: plain, sequence: n)
                    == rule.feel(impulse: 55, material: plain, sequence: n))
        }
    }

    /// 그런데 **순번이 다르면 달라야** 한다 — 같은 세기의 연타가 완전히 동일하면 기계로 들린다.
    @Test func variationActuallyVariesAcrossSequence() {
        let values = Set((UInt64(0)..<64).map { rule.feel(impulse: 55, material: plain, sequence: $0).intensity })
        #expect(values.count >= 40)
    }

    /// 변주 폭은 ±8%를 넘지 않는다. 넘으면 재료·임펄스가 만든 의미를 변주가 덮어쓴다
    /// (같은 충돌이 두 배로 세게 느껴지면 그건 변주가 아니라 버그다).
    @Test func variationStaysWithinEightPercent() {
        var noVariation = rule
        noVariation.variation = 0
        let base = noVariation.feel(impulse: 55, material: plain, sequence: 0)
        for n in UInt64(0)..<512 {
            let v = rule.feel(impulse: 55, material: plain, sequence: n)
            #expect(abs(v.intensity - base.intensity) <= base.intensity * 0.08 + 1e-6)
            #expect(abs(v.sharpness - base.sharpness) <= base.sharpness * 0.08 + 1e-6)
        }
    }

    /// 세기와 날카로움의 변주는 **독립**이다 — 같은 시드를 공유하면 두 축이 나란히 움직여
    /// 결국 "한 파형을 크기만 바꿔 재생"으로 되돌아간다.
    @Test func intensityAndSharpnessVaryIndependently() {
        var noVariation = rule
        noVariation.variation = 0
        let base = noVariation.feel(impulse: 55, material: plain, sequence: 0)
        var opposed = 0
        for n in UInt64(0)..<256 {
            let v = rule.feel(impulse: 55, material: plain, sequence: n)
            if (v.intensity - base.intensity) * (v.sharpness - base.sharpness) < 0 { opposed += 1 }
        }
        #expect(opposed > 80)                       // 독립이면 대략 절반이 반대 부호
    }

    // MARK: - 감쇠 꼬리

    /// 꼬리는 **상위 1/3에만** 붙는다. 전부에 붙이면 잔향이 겹쳐 이 기능이 처음 고치려던 '웅웅'으로
    /// 되돌아가고, 아예 없으면 큰 충돌이 여전히 '딱' 하고 잘린다.
    @Test func tailOnlyOnHardestHits() {
        let onsetImpulse = rule.minImpulse + (rule.ceilingImpulse - rule.minImpulse) * CGFloat(rule.tailOnset)
        #expect(rule.feel(impulse: onsetImpulse - 1, material: plain, sequence: 0).tail == nil)
        #expect(rule.feel(impulse: onsetImpulse + 1, material: plain, sequence: 0).tail != nil)
        #expect(rule.feel(impulse: 20, material: plain, sequence: 0).tail == nil)
        #expect(rule.feel(impulse: 90, material: plain, sequence: 0).tail != nil)
    }

    /// 관문~상한을 고르게 훑으면 꼬리가 붙는 비율은 대략 1/3이다(남용 금지의 수치화).
    @Test func tailShareIsAboutOneThird() {
        let samples = Array(stride(from: CGFloat(20), through: 90, by: 1))
        let withTail = samples.filter { rule.feel(impulse: $0, material: plain, sequence: 0).tail != nil }.count
        let share = Double(withTail) / Double(samples.count)
        #expect(share > 0.25 && share < 0.40)
    }

    /// 꼬리 길이는 40~70ms 구간 안이고, 세게 칠수록 길다.
    @Test func tailDurationSpansFortyToSeventyMilliseconds() {
        let onsetImpulse = rule.minImpulse + (rule.ceilingImpulse - rule.minImpulse) * CGFloat(rule.tailOnset)
        var last: TimeInterval = 0
        var seen = 0
        for impulse in stride(from: onsetImpulse + 0.5, through: 90, by: 1) {
            guard let tail = rule.feel(impulse: impulse, material: plain, sequence: 0).tail else {
                Issue.record("상위 1/3인데 꼬리가 없다: \(impulse)")
                continue
            }
            #expect(tail.duration >= 0.040 && tail.duration <= 0.0700001)
            #expect(tail.duration >= last)
            last = tail.duration
            seen += 1
        }
        #expect(seen > 20)
        #expect(last > 0.065)
        // 최대 충돌(상한 임펄스)은 정확히 상한 길이 — 위 스트라이드는 90에 딱 떨어지지 않으므로 따로 본다.
        let peak = rule.feel(impulse: 90, material: plain, sequence: 0).tail?.duration ?? 0
        #expect(abs(peak - 0.070) < 1e-9)
    }

    /// 꼬리는 본 타격보다 **약하고 뭉툭하다** — 같은 세기면 두 번 친 것으로 들리고,
    /// 같은 날카로움이면 잔향이 아니라 두 번째 '클링'이 된다.
    @Test func tailIsQuieterAndDullerThanTheHit() {
        let feel = rule.feel(impulse: 90, material: ClatterMaterial(sharpness: 0.95, scale: 1), sequence: 4)
        guard let tail = feel.tail else {
            Issue.record("최대 임펄스인데 꼬리가 없다")
            return
        }
        #expect(tail.intensity < feel.intensity * 0.5)
        #expect(tail.sharpness < feel.sharpness)
        #expect(tail.intensity >= 0 && tail.sharpness >= 0)
    }

    // MARK: - 재질 공명 (감쇠 곡선)

    /// **같은 세기라도 재질이 다르면 다르게 죽는다** — HD Rumble의 "재질이 감쇠를 정한다".
    /// 단단한 캔(감쇠 0.85)은 딱 끊기고, 물먹은 두부(0.10)는 길게 끌린다.
    @Test func harderMaterialsRingShorter() {
        let can = ClatterMaterial(sharpness: 0.95, scale: 1.0, decay: 0.85)
        let tofu = ClatterMaterial(sharpness: 0.10, scale: 0.50, decay: 0.10)
        let canTail = rule.feel(impulse: 90, material: can, sequence: 7).tail
        let tofuTail = rule.feel(impulse: 90, material: tofu, sequence: 7).tail
        #expect(canTail != nil && tofuTail != nil)
        #expect((canTail?.duration ?? 0) < (tofuTail?.duration ?? 0))
        // 폭은 ±35%가 상한 — 이보다 벌어지면 재질이 세기 곡선을 덮는다.
        #expect((tofuTail?.duration ?? 0) / (canTail?.duration ?? 1) < 2.1)
    }

    /// 감쇠 배율은 단조 감소하고 중립(0.5)에서 정확히 1이다 — 클래스 값을 조정할 때 방향이 뒤집히지 않게.
    @Test func decayFactorIsMonotonicAroundNeutral() {
        var last = TimeInterval.greatestFiniteMagnitude
        for d in stride(from: Float(0), through: 1, by: 0.05) {
            let f = rule.decayFactor(d)
            #expect(f < last)
            last = f
        }
        #expect(rule.decayFactor(0) > rule.decayFactor(1))
        // 범위 밖 입력도 안전(클램프) — 물성 표에 0..1 밖 값이 들어와도 길이가 음수가 되면 안 된다.
        #expect(rule.decayFactor(-3) == rule.decayFactor(0))
        #expect(rule.decayFactor(9) == rule.decayFactor(1))
    }

    // MARK: - 저/고역 동시 구동 (겹침 · 주파수 하강 스윕)

    /// HD Rumble 근사의 핵심 — **강한 충돌일수록 꼬리가 어택 쪽으로 당겨져 겹친다.**
    /// 겹치는 순간 저역 연속과 고역 transient가 하나의 파형으로 합성돼 "무게 있는 한 방"이 된다.
    /// 약한 충돌은 그대로 12ms 뒤에 붙어 '툭 → 잔향'으로 읽힌다.
    @Test func strongerHitsOverlapTheAttack() {
        let onset = rule.minImpulse + (rule.ceilingImpulse - rule.minImpulse) * CGFloat(rule.tailOnset)
        let weak = rule.feel(impulse: onset + 0.2, material: plain, sequence: 0).tail
        let peak = rule.feel(impulse: 90, material: plain, sequence: 0).tail
        #expect((weak?.lead ?? 0) > 0.010)          // 갓 임계 = 거의 그대로 뒤에 붙는다
        #expect(abs(peak?.lead ?? 1) < 1e-9)        // 최대 충돌 = 정확히 동시(겹침)
        // 그 사이는 단조 감소여야 한다 — 튀면 같은 세기 대역에서 감각이 갈린다.
        var last = TimeInterval.greatestFiniteMagnitude
        for impulse in stride(from: onset + 0.5, through: 90, by: 1) {
            guard let t = rule.feel(impulse: impulse, material: plain, sequence: 0).tail else { continue }
            #expect(t.lead <= last + 1e-12)
            last = t.lead
        }
    }

    /// **주파수 하강 스윕** — 실제 충돌은 고주파가 먼저 죽는다. 세게 칠수록 더 깊이 떨어지되
    /// 시프트 범위(−1...1)를 넘지 않아야 한다(넘으면 CoreHaptics가 커브를 거부한다).
    @Test func sweepDeepensWithImpact() {
        let onset = rule.minImpulse + (rule.ceilingImpulse - rule.minImpulse) * CGFloat(rule.tailOnset)
        let weak = rule.feel(impulse: onset + 0.2, material: plain, sequence: 0).tail
        let peak = rule.feel(impulse: 90, material: plain, sequence: 0).tail
        #expect((weak?.sweep ?? 0) > 0)
        #expect((peak?.sweep ?? 0) > (weak?.sweep ?? 0))
        #expect((peak?.sweep ?? 0) <= 1)
        #expect(abs((peak?.sweep ?? 0) - rule.tailSweep) < 1e-6)   // 최대 충돌 = 규칙이 정한 최대 폭
    }

    /// 스윕은 꼬리를 **음의 시프트**로 밀어내므로, 시작 날카로움에서 뺀 값이 음수여도 상관없다
    /// (하드웨어가 0에서 클램프한다). 다만 규칙이 내놓는 값 자체는 항상 유한하고 0 이상이어야 한다.
    @Test func tailValuesStayFinite() {
        for s in stride(from: Float(0), through: 1, by: 0.1) {
            for d in stride(from: Float(0), through: 1, by: 0.25) {
                for impulse in stride(from: CGFloat(20), through: 200, by: 20) {
                    let mat = ClatterMaterial(sharpness: s, scale: 1, decay: d)
                    guard let t = rule.feel(impulse: impulse, material: mat, sequence: 3).tail else { continue }
                    #expect(t.duration > 0 && t.duration < 0.2)
                    #expect(t.lead >= 0 && t.lead <= rule.tailLead)
                    #expect(t.sweep >= 0 && t.sweep <= 1)
                    #expect(t.intensity >= 0 && t.intensity <= 1)
                    #expect(t.sharpness >= 0 && t.sharpness <= 1)
                }
            }
        }
    }

    // MARK: - 제스처 액센트

    /// 잡기·캡처 스냅은 물리에서 파생되지 않는 상수라, **의도한 위계**만 못박는다:
    /// 캡처(판정 자리에 붙음)가 잡기보다 확실히 세고, 캡처만 저역 꼬리를 어택과 동시에 얹는다.
    @Test func captureSnapOutweighsPick() {
        #expect(ClatterAccent.captureSnap.intensity > ClatterAccent.pick.intensity)
        #expect(ClatterAccent.pick.tail == nil)
        #expect(ClatterAccent.captureSnap.tail?.lead == 0)
        // 두 액센트 모두 충돌 최대치를 넘지 않는다 — 제스처가 물리보다 세면 위계가 뒤집힌다.
        let hardest = rule.feel(impulse: 90, material: ClatterMaterial(sharpness: 0.95, scale: 1), sequence: 0)
        #expect(ClatterAccent.captureSnap.intensity < hardest.intensity)
    }
}
