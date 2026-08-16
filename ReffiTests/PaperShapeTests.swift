import XCTest
import SwiftUI
@testable import Reffi

/// `PaperRect`의 손맛 규율(§13.1 "완벽한 원·사각·캡슐 금지")을 셰이프 수준에서 고정한다.
/// 육안 검증은 스크린샷이 하지만, 회귀는 여기서 막는다 — 값 튜닝이 다시 지각 불가 구간으로
/// 내려가거나 pill 반지름이 캡슐로 되돌아가면 실패한다.
final class PaperShapeTests: XCTestCase {

    /// 곡선(코너·변) 개수 — 8각형으로 라우팅되면 0이다.
    private func quadCount(_ path: Path) -> Int {
        var n = 0
        path.forEach { if case .quadCurve = $0 { n += 1 } }
        return n
    }

    /// pill 반지름은 좌우가 정확한 반원인 캡슐로 퇴화하므로 모서리 잘린 8각으로 라우팅된다.
    func testPillRadiusRoutesToChamferedOctagon() {
        let rect = CGRect(x: 0, y: 0, width: 92, height: 44)
        XCTAssertTrue(PaperRect.degeneratesToCapsule(cornerRadius: ReffiRadius.pill, in: rect, seed: 1))

        let routed = PaperRect(cornerRadius: ReffiRadius.pill, seed: 1).path(in: rect)
        let octagon = PaperCutRect(seed: 1).path(in: rect)
        XCTAssertEqual(quadCount(routed), 0, "캡슐 퇴화 구간은 곡선 없는 8각이어야 한다")
        XCTAssertEqual(routed.description, octagon.description)
    }

    /// 일부 코너만 클램프되는 크기는 라우팅하지 않는다 — 비대칭 손맛을 그대로 둔다.
    func testModerateRadiusStaysRoundedPaperRect() {
        let rect = CGRect(x: 0, y: 0, width: 200, height: 45)
        XCTAssertFalse(PaperRect.degeneratesToCapsule(cornerRadius: ReffiRadius.md, in: rect, seed: 0))
        XCTAssertEqual(quadCount(PaperRect(cornerRadius: ReffiRadius.md, seed: 0).path(in: rect)), 8)
    }

    /// 45pt 컨트롤에서도 변 휨이 지각되는 폭(≥1.5pt)이되 지저분해지는 폭(>4pt)은 넘지 않는다.
    /// seed 0의 윗변은 안쪽으로 휘므로, 위 가장자리 1.5pt 지점은 셰이프 **밖**이고 4.5pt 지점은 안이다.
    func testEdgeBowIsPerceptibleAtControlHeight() {
        let rect = CGRect(x: 0, y: 0, width: 200, height: 45)
        let path = PaperRect(cornerRadius: ReffiRadius.md, seed: 0).path(in: rect)
        XCTAssertFalse(path.contains(CGPoint(x: rect.midX, y: 1.5)), "윗변이 1.5pt도 휘지 않았다")
        XCTAssertTrue(path.contains(CGPoint(x: rect.midX, y: 4.5)), "윗변이 4pt 넘게 휘어 지저분하다")
    }

    /// 같은 시드는 항상 같은 그림 — 레이아웃·애니메이션 안정(§13.1).
    func testSeedIsDeterministic() {
        let rect = CGRect(x: 0, y: 0, width: 120, height: 60)
        let a = PaperRect(cornerRadius: ReffiRadius.md, seed: 3).path(in: rect)
        let b = PaperRect(cornerRadius: ReffiRadius.md, seed: 3).path(in: rect)
        XCTAssertEqual(a.description, b.description)
    }
}
