import Testing
import Foundation
@testable import Reffi

/// 구름/미끄러짐 **지속** 촉감 — HD Rumble의 구슬 시그니처를 iPhone으로 옮긴 계열.
/// 촉감의 자연스러움 자체는 실기기에서만 판정되지만, **켜지고 꺼지는 규칙**은 여기서 못박을 수 있다:
/// 정지한 더미에서 절대 켜지지 않을 것 · 날고 있을 땐 꺼질 것 · 경계에서 지직거리며 여닫히지 않을 것.
struct ClatterTextureTests {
    private let rule = RollTextureRule()
    private let plain = ClatterMaterial(sharpness: 0.5, scale: 1.0)

    // MARK: - 출하값 고정

    /// 씬은 `RollTextureRule()` 기본값을 그대로 쓴다. 이게 없으면 튜닝값을 되돌려도 전부 초록이다.
    @Test func shippingDefaults() {
        #expect(rule.minSpin == 0.85)
        #expect(rule.spinCeiling == 8.5)
        #expect(rule.minSpeed == 14)
        #expect(rule.speedCeiling == 240)
        #expect(rule.flightSpeed == 360)
        #expect(rule.maxIntensity == 0.32)
    }

    // MARK: - 관문 ① 정지한 더미는 절대 울리지 않는다

    /// 이 기능 전체가 처음 고치려던 실패 모드 — 가만히 있는 더미에서 웅웅대면 즉시 싸구려가 된다.
    /// 솔버 잔차 대역(속도·각속도 모두 미세)은 신호가 **정확히 0**이어야 한다.
    @Test func restingPileMakesNoTexture() {
        #expect(rule.level(speed: 0, spin: 0) == 0)
        #expect(rule.level(speed: 3, spin: 0.2) == 0)
        #expect(rule.level(speed: 13.9, spin: 5) == 0)      // 병진이 문턱 아래 = 결이 지나가지 않는다
        #expect(rule.level(speed: 200, spin: 0.84) == 0)    // 회전이 문턱 아래 = 구름이 아니다
    }

    /// 회전과 병진은 **둘 다** 있어야 한다 — 제자리 회전도, 미끄러짐 없는 이동도 구름이 아니다.
    @Test func rollNeedsBothAxes() {
        #expect(rule.level(speed: 120, spin: 0) == 0)
        #expect(rule.level(speed: 0, spin: 6) == 0)
        #expect(rule.level(speed: 120, spin: 6) > 0)
    }

    // MARK: - 관문 ② 날고 있으면 끈다

    /// 접촉을 직접 묻지 않는 대신 속도로 가른다 — 허공에서 텍스처가 깔리면 물리가 거짓말이 된다.
    /// 중력 42(=6300pt/s²)에서 자유낙하는 순식간에 이 대역을 넘는다.
    @Test func flyingChipsGetNoTexture() {
        #expect(rule.level(speed: 359, spin: 6) > 0)
        #expect(rule.level(speed: 360, spin: 6) == 0)
        #expect(rule.level(speed: 1200, spin: 8) == 0)      // 던진 칩
    }

    // MARK: - 속도 → 세기 (연속 변조)

    /// 빠르게 구를수록 결이 세게 지나간다. 단조여야 손이 "속도"를 읽는다.
    @Test func levelRisesWithSpeed() {
        var last: Float = -1
        for v in stride(from: CGFloat(15), through: 240, by: 5) {
            let l = rule.level(speed: v, spin: 6)
            #expect(l > last)
            last = l
        }
        #expect(last > 0.8)
    }

    /// 각속도도 같은 방향으로 작동한다(더 빨리 돌면 결이 촘촘하다).
    @Test func levelRisesWithSpin() {
        var last: Float = -1
        for w in stride(from: CGFloat(1.0), through: 8.5, by: 0.25) {
            let l = rule.level(speed: 150, spin: w)
            #expect(l > last)
            last = l
        }
    }

    /// 부호는 무관하다 — 반대로 굴러도 같은 촉감이다(음의 각속도로 신호가 죽으면 절반이 무음이 된다).
    @Test func spinDirectionDoesNotMatter() {
        #expect(rule.level(speed: 150, spin: -6) == rule.level(speed: 150, spin: 6))
    }

    /// 포화 위는 평평하다 — 클램프가 없으면 세기가 1을 넘어 CoreHaptics가 거부한다.
    @Test func levelSaturates() {
        #expect(rule.level(speed: 240, spin: 8.5) == 1)
        #expect(rule.level(speed: 350, spin: 40) == 1)
    }

    // MARK: - 텍스처 값

    /// 텍스처는 **충돌 촉감을 덮으면 안 된다** — 부딪힘이 주인공이고 구름은 바닥이다.
    /// 최대 신호·최대 배율에서도 0.32를 넘지 않는다.
    @Test func textureStaysUnderTheImpactChannel() {
        let t = rule.texture(level: 1, material: ClatterMaterial(sharpness: 0.95, scale: 1.0))
        #expect(t.intensity <= 0.32)
        let weakestImpact = ClatterFeelRule().feel(impulse: 20, material: plain, sequence: 0)
        // 가장 약한 충돌보다는 세도 된다(구름은 들려야 한다) — 다만 가장 센 충돌의 절반 아래.
        let hardestImpact = ClatterFeelRule().feel(impulse: 90, material: plain, sequence: 0)
        #expect(t.intensity > weakestImpact.intensity)
        #expect(t.intensity < hardestImpact.intensity * 0.5)
    }

    /// 재료 배율이 그대로 곱해진다 — 잎사귀(0.42)는 굴러도 거의 무음이고 캔(1.0)은 확실히 들린다.
    @Test func materialScaleReachesTheTexture() {
        let leaf = rule.texture(level: 1, material: ClatterMaterial(sharpness: 0.55, scale: 0.42))
        let can = rule.texture(level: 1, material: ClatterMaterial(sharpness: 0.95, scale: 1.0))
        #expect(leaf.intensity < can.intensity * 0.5)
    }

    /// 구름은 부딪힘보다 **뭉툭하다** — 같은 재료의 충돌 날카로움보다 낮게 깔려야
    /// 사건(부딪힘)과 상태(구름)가 손에서 갈린다.
    @Test func textureIsDullerThanTheImpact() {
        let mat = ClatterMaterial(sharpness: 0.68, scale: 0.85)
        let slow = rule.texture(level: 0.2, material: mat)
        #expect(slow.sharpness < mat.sharpness)
        // 다만 빨라지면 조금 밝아진다(속도가 촉감에 실리는 둘째 축).
        let fast = rule.texture(level: 1, material: mat)
        #expect(fast.sharpness > slow.sharpness)
    }

    /// 어떤 입력에서도 0...1을 벗어나지 않는다 — 새면 하드웨어가 이벤트를 거부한다.
    @Test func textureStaysInRange() {
        for s in stride(from: Float(0), through: 1, by: 0.1) {
            for sc in stride(from: Float(0), through: 1, by: 0.25) {
                for l in stride(from: Float(-1), through: 2, by: 0.25) {
                    let t = rule.texture(level: l, material: ClatterMaterial(sharpness: s, scale: sc))
                    #expect(t.intensity >= 0 && t.intensity <= 1)
                    #expect(t.sharpness >= 0 && t.sharpness <= 1)
                }
            }
        }
    }
}

/// 지속 촉감의 **개폐 히스테리시스** — 문턱이 하나뿐이거나 유예가 없으면 경계에서 지직거리며
/// 여닫힌다(스폰 하늘 개폐에서 이미 한 번 겪은 실패 모드와 같은 구조).
struct TextureGateTests {
    @Test func shippingDefaults() {
        let g = TextureGate()
        #expect(g.onLevel == 0.20)
        #expect(g.offLevel == 0.09)
        #expect(g.holdOff == 0.14)
        #expect(g.isOn == false)
        // 켜는 문턱이 끄는 문턱보다 **높아야** 히스테리시스다 — 뒤집히면 존재 이유가 없다.
        #expect(g.onLevel > g.offLevel)
    }

    /// 켜는 문턱 아래에서는 아무리 오래 있어도 안 켜진다.
    @Test func staysClosedBelowOnLevel() {
        var g = TextureGate()
        for i in 0..<60 {
            #expect(g.update(level: 0.19, now: TimeInterval(i) / 60) == false)
        }
    }

    @Test func opensAtOnLevel() {
        var g = TextureGate()
        #expect(g.update(level: 0.20, now: 0) == true)
        #expect(g.isOn)
    }

    /// **히스테리시스** — 켜진 뒤에는 켜는 문턱 아래로 내려가도 유지된다(끄는 문턱까지는 살아 있다).
    /// 이게 없으면 문턱 근처에서 구르는 칩이 프레임마다 여닫힌다.
    @Test func holdsBetweenTheTwoThresholds() {
        var g = TextureGate()
        _ = g.update(level: 0.5, now: 0)
        for i in 1..<60 {
            #expect(g.update(level: 0.12, now: TimeInterval(i) / 60) == true)   // 0.09 ≤ 0.12 < 0.20
        }
    }

    /// 끄는 문턱 아래로 내려가도 **유예**를 다 채워야 꺼진다 — 한 프레임짜리 dip으로 끊기면
    /// 구름이 아니라 스위치 소리가 된다.
    @Test func closesOnlyAfterTheHoldOff() {
        var g = TextureGate()
        _ = g.update(level: 0.5, now: 0)
        #expect(g.update(level: 0, now: 1.0) == true)     // 유예 시작
        #expect(g.update(level: 0, now: 1.10) == true)    // 0.10s — 아직
        // 경계는 정확히 0.14가 아니라 **넘긴** 시각으로 본다 — 1.14는 Double로 1.1399…라
        // 유예를 한 틱 못 채운다(경계 자체를 재는 테스트가 아니라 닫힘을 재는 테스트다).
        #expect(g.update(level: 0, now: 1.16) == false)
        #expect(g.isOn == false)
    }

    /// 유예 중에 신호가 돌아오면 타이머가 **리셋**된다 — 안 그러면 계속 구르는 중에도 꺼진다.
    @Test func recoveringSignalCancelsTheHoldOff() {
        var g = TextureGate()
        _ = g.update(level: 0.5, now: 0)
        #expect(g.update(level: 0, now: 1.0) == true)
        #expect(g.update(level: 0.5, now: 1.05) == true)  // 신호 복귀 → 타이머 취소
        #expect(g.update(level: 0, now: 1.10) == true)    // 여기서 유예가 다시 시작한다
        #expect(g.update(level: 0, now: 1.20) == true)    // 복귀 기준 0.10s — 아직 살아 있어야 한다
        #expect(g.update(level: 0, now: 1.25) == false)
    }

    /// 60fps로 신호가 문턱 근처에서 오르내려도 **한 번도 안 꺼진다**(채터링 방지의 수치화).
    @Test func doesNotChatterAroundTheThreshold() {
        var g = TextureGate()
        _ = g.update(level: 0.5, now: 0)
        var flips = 0
        var prev = true
        for i in 1...600 {
            let level: Float = i % 2 == 0 ? 0.21 : 0.10   // 켬 문턱 위/끔 문턱 위를 오간다
            let on = g.update(level: level, now: TimeInterval(i) / 60)
            if on != prev { flips += 1; prev = on }
        }
        #expect(flips == 0)
    }

    /// 리셋은 **유예 없이** 즉시 닫는다 — 씬이 멈추거나 손을 뗄 때 한 박자 더 울리면 거짓말이 된다.
    @Test func resetClosesImmediately() {
        var g = TextureGate()
        _ = g.update(level: 1, now: 0)
        g.reset()
        #expect(g.isOn == false)
        // 리셋 뒤 첫 프레임은 다시 **켜는 문턱**을 넘어야 열린다(끄는 문턱으로 새지 않는다).
        #expect(g.update(level: 0.12, now: 0.1) == false)
        #expect(g.update(level: 0.25, now: 0.2) == true)
    }
}
