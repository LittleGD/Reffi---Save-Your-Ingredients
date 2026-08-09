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

    @Test func angleIsSymmetricAndUnsigned() {
        let a = CGVector(dx: 0, dy: -42)
        let b = CGVector(dx: 42, dy: 0)
        #expect(close(GravityMapper.angle(a, b), .pi / 2, 0.0001))
        #expect(close(GravityMapper.angle(b, a), .pi / 2, 0.0001))
        #expect(close(GravityMapper.angle(a, a), 0, 0.0001))
    }
}
