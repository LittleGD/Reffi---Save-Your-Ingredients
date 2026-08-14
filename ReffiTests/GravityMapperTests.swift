import Testing
import Foundation
import CoreGraphics
@testable import Reffi

/// 기울임 중력 매핑 — 포트레이트 축 대응, 데드밴드, 수평 클램프, 폴백, 깨우기 임계.
/// 씬 없이 순수 계산만 검증한다(시뮬레이터에 자이로가 없어도 회귀가 잡힌다).
struct GravityMapperTests {

    /// 단위 중력 벡터 — 각도는 "아래(0, -1)" 기준 반시계.
    private func tilt(degrees: Double, magnitude: Double = 1) -> (x: Double, y: Double) {
        let r = degrees * .pi / 180
        return (x: magnitude * sin(r) * -1, y: magnitude * cos(r) * -1)
    }

    private func close(_ a: CGFloat, _ b: CGFloat, _ tol: CGFloat = 0.001) -> Bool { abs(a - b) < tol }

    @Test func uprightPortraitMatchesLegacyConstant() {
        // 세로로 똑바로 들면 기존 상수 중력과 픽셀 단위로 동일해야 한다(회귀 가드).
        let g = GravityMapper.mapped(x: 0, y: -1)
        #expect(close(g.dx, 0))
        #expect(close(g.dy, -42))
        #expect(GravityMapper.fallback == CGVector(dx: 0, dy: -42))
    }

    @Test func deviceAxesMapDirectlyToSceneAxes() {
        // 포트레이트 고정이라 부호 보정이 없다 — 기기 x가 +면 씬 중력도 +x(오른쪽).
        let right = GravityMapper.mapped(x: 0.5, y: -0.866)
        #expect(right.dx > 0)
        #expect(right.dy < 0)
        #expect(close(hypot(right.dx, right.dy), 42, 0.01))   // 1G → 기준 크기

        let left = GravityMapper.mapped(x: -0.5, y: -0.866)
        #expect(left.dx < 0)
        #expect(close(left.dx, -right.dx))

        // 기기를 뒤집으면(화면 아래가 위) 중력도 위로 — 칩이 천장 쪽으로 흐른다.
        let flipped = GravityMapper.mapped(x: 0, y: 1)
        #expect(flipped.dy > 0)
        #expect(close(flipped.dy, 42))
    }

    @Test func nearFlatClampsToGentleGravity() {
        // 완전 수평(화면이 위를 봄) → 평면 성분 0. 방향 미정의라 아래로 접고, 크기는 하한.
        let flat = GravityMapper.mapped(x: 0, y: 0)
        #expect(close(flat.dx, 0))
        #expect(close(flat.dy, -42 * 0.35))
        #expect(flat.dy < 0)   // 0이 아니어야 칩이 결국 안착한다

        // 살짝만 기운 경우도 하한까지 끌어올린다 — 방향은 유지.
        let barely = GravityMapper.mapped(x: 0.1, y: 0)
        #expect(close(hypot(barely.dx, barely.dy), 42 * 0.35, 0.01))
        #expect(barely.dx > 0)

        // 1G를 넘는 흔들림(가속)은 상한으로 잘린다.
        let shaken = GravityMapper.mapped(x: 0, y: -2.4)
        #expect(close(hypot(shaken.dx, shaken.dy), 42, 0.01))
    }

    @Test func deadbandSuppressesMicroJitter() {
        let base = GravityMapper.mapped(x: 0, y: -1)
        let jitter = GravityMapper.mapped(x: tilt(degrees: 1).x, y: tilt(degrees: 1).y)
        #expect(!GravityMapper.shouldApply(jitter, lastApplied: base))   // 1° < 2° 데드밴드

        let turned = GravityMapper.mapped(x: tilt(degrees: 4).x, y: tilt(degrees: 4).y)
        #expect(GravityMapper.shouldApply(turned, lastApplied: base))

        // 방향은 같고 크기만 변한 경우 — 3%는 무시, 20%는 반영.
        #expect(!GravityMapper.shouldApply(CGVector(dx: 0, dy: -42 * 0.97), lastApplied: base))
        #expect(GravityMapper.shouldApply(CGVector(dx: 0, dy: -42 * 0.8), lastApplied: base))
    }

    @Test func wakeOnlyOnClearTilt() {
        let base = GravityMapper.mapped(x: 0, y: -1)
        let tremor = GravityMapper.mapped(x: tilt(degrees: 4).x, y: tilt(degrees: 4).y)
        #expect(!GravityMapper.shouldWake(tremor, lastApplied: base))   // 손떨림으론 안 깨운다
        #expect(GravityMapper.shouldApply(tremor, lastApplied: base))   // 데드밴드보단 크다

        let real = GravityMapper.mapped(x: tilt(degrees: 12).x, y: tilt(degrees: 12).y)
        #expect(GravityMapper.shouldWake(real, lastApplied: base))
        // 반대 방향도 대칭.
        let other = GravityMapper.mapped(x: tilt(degrees: -12).x, y: tilt(degrees: -12).y)
        #expect(GravityMapper.shouldWake(other, lastApplied: base))
    }

    // MARK: 무방향 대역(기기를 눕힘) — 노이즈가 데드밴드·깨우기를 뚫지 못해야 한다

    @Test func flatNoiseCollapsesToASingleDirectionlessGravity() {
        // 책상에 눕힌 기기: 평면 성분 ≈0.009 + 센서 노이즈로 방향이 매 프레임 난수다.
        // 정규화하면 각도가 크게 흔들리지만, 무방향 판정이 먼저라 결과 벡터는 항상 동일해야 한다.
        var directionless = false
        var applied = GravityMapper.fallback
        var applications = 0
        var wakes = 0

        // 진짜 노이즈처럼 부호·크기가 제각각인 표본(전부 flatEnter 0.06 미만).
        let noise: [(Double, Double)] = [
            (0.009, -0.004), (-0.006, 0.011), (0.002, 0.013), (-0.014, -0.003),
            (0.011, 0.007), (-0.001, -0.012), (0.013, 0.002), (-0.008, 0.009),
        ]
        for (x, y) in noise {
            let s = GravityMapper.sample(x: x, y: y, wasDirectionless: directionless)
            directionless = s.directionless
            #expect(s.directionless)
            #expect(s.gravity == GravityMapper.flatGravity)   // 노이즈와 무관하게 같은 벡터
            if GravityMapper.shouldWake(s, lastApplied: applied) { wakes += 1 }
            if GravityMapper.shouldApply(s.gravity, lastApplied: applied) {
                applications += 1
                applied = s.gravity
            }
        }
        #expect(applications == 1)   // 상수 중력 → 무방향으로 한 번만 갈아끼운다
        #expect(wakes == 0)          // 눕혀 둔 기기의 노이즈로는 잠든 씬을 절대 깨우지 않는다
    }

    @Test func directionlessBandHasHysteresis() {
        // 밖 → 안: flatEnter(0.06) 아래로 내려가야 들어간다.
        #expect(!GravityMapper.isDirectionless(rawMagnitude: 0.08, wasDirectionless: false))
        #expect(GravityMapper.isDirectionless(rawMagnitude: 0.05, wasDirectionless: false))
        // 안 → 밖: flatExit(0.10)을 넘어야 나온다 — 밴드 안(0.08)에선 그대로 무방향.
        #expect(GravityMapper.isDirectionless(rawMagnitude: 0.08, wasDirectionless: true))
        #expect(!GravityMapper.isDirectionless(rawMagnitude: 0.12, wasDirectionless: true))

        // 밴드를 오가는 표본 — 경계에서 상태가 깜빡이지 않는다(진입 후 0.08은 계속 무방향).
        var directionless = false
        for m in [0.30, 0.08, 0.04, 0.08, 0.09, 0.14, 0.08] as [Double] {
            let s = GravityMapper.sample(x: m, y: 0, wasDirectionless: directionless)
            directionless = s.directionless
        }
        #expect(!directionless)   // 마지막은 0.14로 이미 빠져나온 뒤라 0.08도 방향이 있다

        // 무방향을 벗어나면 다시 정상 매핑 — 방향이 살아나고 크기는 하한.
        let out = GravityMapper.sample(x: 0.2, y: 0, wasDirectionless: true)
        #expect(!out.directionless)
        #expect(out.gravity.dx > 0)
        #expect(close(hypot(out.gravity.dx, out.gravity.dy), 42 * 0.35, 0.01))
    }

    @Test func directionlessGravityMatchesFlatMapping() {
        // 무방향 벡터 = 완전 수평 매핑과 동일(아래로, 크기 하한) — 두 경로가 다른 감각을 주지 않는다.
        #expect(GravityMapper.flatGravity == GravityMapper.mapped(x: 0, y: 0))
        #expect(close(GravityMapper.flatGravity.dy, -42 * 0.35))
        // 확실한 기울임은 무방향으로 접히지 않는다(회귀 가드).
        let upright = GravityMapper.sample(x: 0, y: -1, wasDirectionless: true)
        #expect(!upright.directionless)
        #expect(upright.gravity == GravityMapper.fallback)
    }

    @Test func angleIsSymmetricAndUnsigned() {
        let a = CGVector(dx: 0, dy: -42)
        let b = CGVector(dx: 42, dy: 0)
        #expect(close(GravityMapper.angle(a, b), .pi / 2, 0.0001))
        #expect(close(GravityMapper.angle(b, a), .pi / 2, 0.0001))
        #expect(close(GravityMapper.angle(a, a), 0, 0.0001))
    }
}

/// 셰이크 킥 판정(`IngredientDropScene.shakeKick`) — 순수 계산이라 씬 상태 없이 고정한다.
/// v1.0 (2) 실기기 검증의 회귀 가드: 평면(x·y)만 재던 판정은 화면을 보며 흔드는
/// 자연스러운 동작(주 가속 = z축)을 통째로 놓쳤다.
@MainActor
struct ShakeKickTests {

    private let upright = CGVector(dx: 0, dy: -42)

    /// z축 단독 흔들기가 감지되고, 방향은 중력 반대(위)로 나온다.
    @Test func zOnlyShakeFiresAntiGravity() {
        let kick = IngredientDropScene.shakeKick(x: 0, y: 0, z: 0.8, gravity: upright, threshold: 0.35)
        #expect(kick != nil)
        #expect(abs((kick?.angle ?? 0) - .pi * 0.5) < 0.0001)   // (0,-42)의 반대 = 위
        #expect(abs((kick?.excess ?? 0) - 0.45) < 0.0001)
    }

    /// 평면 성분이 충분하면 그 방향을 따른다 — z가 섞여 있어도.
    @Test func planarComponentStefersDirection() {
        let kick = IngredientDropScene.shakeKick(x: 0.5, y: 0, z: 0.4, gravity: upright, threshold: 0.35)
        #expect(kick != nil)
        #expect(abs(kick?.angle ?? 1) < 0.0001)   // +x 방향
    }

    /// 세 축 합산 크기로 임계를 판정한다 — 평면만으론 미달이어도 z가 채우면 발화.
    @Test func magnitudeCombinesAllThreeAxes() {
        #expect(IngredientDropScene.shakeKick(x: 0.2, y: 0, z: 0.32, gravity: upright, threshold: 0.35) != nil)
        #expect(IngredientDropScene.shakeKick(x: 0.2, y: 0, z: 0, gravity: upright, threshold: 0.35) == nil)
    }

    /// 손떨림·걷기 대역은 무시한다.
    @Test func belowThresholdIsIgnored() {
        #expect(IngredientDropScene.shakeKick(x: 0.1, y: 0.1, z: 0.15, gravity: upright, threshold: 0.35) == nil)
    }

    /// 운영 임계에서의 초과분 산식 고정 — v1.0 (3) "흔들어도 아무 반응 없음" 회귀 가드.
    /// **씬의 상수를 심볼로 읽는다** — 리터럴을 다시 적으면 씬 값을 되돌려도 초록이 뜬다.
    /// 0.5G 흔들기의 초과분은 0.25, 이득 480을 곱하면 120pt/s로 **눈에 보이는** 킥이 된다
    /// (옛 임계 0.35·이득 150에선 22pt/s라 사실상 정지처럼 보였다).
    @Test func excessAtShippingThreshold() {
        let threshold = IngredientDropScene.shakeThreshold
        let gain = IngredientDropScene.shakeGain
        // 상수 자체를 고정 — 이 셋이 흔들리면 아래 산식 기대값의 근거가 사라진다.
        #expect(threshold == 0.25)
        #expect(gain == 480)
        #expect(IngredientDropScene.shakeMaxDeltaV == 210)
        let half = IngredientDropScene.shakeKick(x: 0, y: 0, z: 0.5, gravity: upright, threshold: threshold)
        #expect(abs((half?.excess ?? 0) - 0.25) < 0.0001)
        #expect(abs((half?.excess ?? 0) * gain - 120) < 0.0001)
        // 손떨림 대역은 새 임계에서도 여전히 막힌다.
        #expect(IngredientDropScene.shakeKick(x: 0, y: 0, z: 0.2, gravity: upright, threshold: threshold) == nil)
    }

    /// **터널링 상한 불변식** — 칩이 킥 한 번에 받는 Δv는 흩뿌림을 곱한 뒤에도 상한을 못 넘는다.
    /// v1.0 (4)까지는 클램프가 흩뿌림 **앞**에 있어 실최대가 210 × 1.35 = 283.5pt/s(프레임당 4.7pt)로
    /// 새어 나갔다 — 문서와 주석이 선언한 불변식이 기본 동작에서 거짓이었다.
    @Test func scatterNeverExceedsTunnelingCap() {
        let cap = IngredientDropScene.shakeMaxDeltaV
        // 이득 포화 구간(0.7G 이상)의 공칭 Δv로 흩뿌림 전 구간을 훑는다.
        for step in 0...20 {
            let j = CGFloat(step) / 20
            #expect(IngredientDropScene.scatteredDeltaV(cap, jitter: j) <= cap)
            #expect(IngredientDropScene.scatteredDeltaV(cap * 4, jitter: j) <= cap)
        }
        // 상한 아래에선 흩뿌림이 그대로 살아 있다(전부 같은 세기면 부딪히지 않아 달그락이 없다).
        let nominal: CGFloat = 120                                   // 0.5G 흔들기
        #expect(abs(IngredientDropScene.scatteredDeltaV(nominal, jitter: 0) - 78) < 0.0001)
        #expect(abs(IngredientDropScene.scatteredDeltaV(nominal, jitter: 1) - 162) < 0.0001)
    }

    /// 기울인 채 z-흔들기 — 방향은 그 시점 중력의 반대를 따라간다.
    @Test func antiGravityFollowsTiltedGravity() {
        let tilted = CGVector(dx: 29.7, dy: -29.7)   // 45° 기울임
        let kick = IngredientDropScene.shakeKick(x: 0, y: 0, z: 0.6, gravity: tilted, threshold: 0.35)
        #expect(kick != nil)
        let expected = atan2(29.7, -29.7)   // 중력 반대 방향
        #expect(abs((kick?.angle ?? 0) - expected) < 0.0001)
    }
}
