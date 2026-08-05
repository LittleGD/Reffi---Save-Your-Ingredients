#if DEBUG
import Testing
import Foundation
import SpriteKit
@testable import Reffi

/// 기울기 중력 매핑(§13.4) — 시뮬레이터엔 자이로가 없어 CoreMotion 경로를 태울 수 없으므로,
/// 실기기 없이 축 매핑·눕힘 보정·세기 고정을 검증할 수 있는 유일한 경로다.
/// `debugTilt`(= `-tiltLab` 슬라이더가 쓰는 주입구)에 정규화된 중력 방향을 넣고 씬 중력을 읽는다.
@MainActor
struct TiltGravityTests {
    private func gravity(forTilt dx: CGFloat, _ dy: CGFloat) -> CGVector {
        let scene = IngredientDropScene()
        scene.debugTilt = CGVector(dx: dx, dy: dy)
        return scene.physicsWorld.gravity
    }

    /// 세워 든 자세는 gravity = (0, -1) — 씬 중력도 정확히 아래여야 한다(세로 고정 전제의 축 매핑).
    @Test func uprightPullsDown() {
        let g = gravity(forTilt: 0, -1)
        #expect(abs(g.dx) < 0.001)
        #expect(g.dy < 0)
    }

    /// 오른쪽으로 눕히면 중력도 오른쪽 — 재료가 오른쪽으로 굴러간다.
    @Test func tiltRightPullsRight() {
        let g = gravity(forTilt: 1, 0)
        #expect(g.dx > 0)
        #expect(abs(g.dy) < 0.001)
    }

    @Test func tiltLeftPullsLeft() {
        #expect(gravity(forTilt: -1, 0).dx < 0)
    }

    /// 폰을 테이블에 눕히면 중력이 z축으로 빠져 평면 성분이 0이 된다. 그대로 쓰면 무중력이라
    /// 더미가 흩어지므로 기본 아래 방향으로 접혀야 한다.
    @Test func flatOnTableKeepsDownwardPull() {
        let g = gravity(forTilt: 0, 0)
        #expect(abs(g.dx) < 0.001)
        #expect(g.dy < 0)
    }

    /// 기울기는 **방향만** 바꾸고 세기는 고정 — 자세에 따라 낙하감이 달라지지 않는다.
    @Test func magnitudeIsConstantAcrossTilts() {
        let inputs: [(CGFloat, CGFloat)] = [(0, -1), (1, 0), (-1, 0), (0.6, -0.8), (0, 0), (0.1, -0.1)]
        let magnitudes = inputs.map { input -> CGFloat in
            let g = gravity(forTilt: input.0, input.1)
            return hypot(g.dx, g.dy)
        }
        let reference = magnitudes[0]
        #expect(reference > 0)
        for m in magnitudes { #expect(abs(m - reference) < 0.001) }
    }
}
#endif
