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

    /// 변 휨 상한은 **짧은 변**에도 걸린다 — 폭은 넓고 높이는 낮은 면(재료 뱃지 ≈150×40)의 긴 변이
    /// 상한 4pt를 그대로 받으면 높이의 10%가 출렁이고, 위아래가 반대로 휘면 실루엣이 20%까지 일그러진다.
    ///
    /// seed 0의 윗변은 `edgeBow` 계수 0.7로 안쪽으로 휜다. 40pt 높이면 상한이 `40 × 0.05 = 2.0pt`,
    /// 실제 편차는 `2.0 × 0.7 = 1.4pt`다 — 2.0pt 지점은 셰이프 **안**이어야 한다(그보다 더 휘면 과하다).
    /// 짧은 변 상한이 없던 시절엔 편차가 `4 × 0.7 = 2.8pt`라 이 단언이 깨진다.
    /// 손맛 자체는 남아야 하므로 1.0pt 지점은 여전히 밖이다.
    func testEdgeBowIsCappedByTheShortSideOnWideThinSurfaces() {
        let badge = CGRect(x: 0, y: 0, width: 150, height: 40)
        let path = PaperRect(cornerRadius: ReffiRadius.md, seed: 0).path(in: badge)
        XCTAssertFalse(path.contains(CGPoint(x: badge.midX, y: 1.0)), "손맛이 사라졌다 — 윗변이 1pt도 안 휜다")
        XCTAssertTrue(path.contains(CGPoint(x: badge.midX, y: 2.0)),
                      "얇은 면의 변이 2pt 넘게 휘어 실루엣이 일그러진다")
    }

    /// 큰 면은 그대로다 — 상한을 짧은 변에 건 것이 넓은 카드의 손맛까지 깎으면 안 된다.
    /// 짧은 변 200pt면 상한이 4pt로 유지되므로 실제 편차는 `4 × 0.7 = 2.8pt`, 2.4pt 지점은 밖이다.
    func testEdgeBowStaysFullOnLargeSurfaces() {
        let card = CGRect(x: 0, y: 0, width: 340, height: 200)
        let path = PaperRect(cornerRadius: ReffiRadius.lg, seed: 0).path(in: card)
        XCTAssertFalse(path.contains(CGPoint(x: card.midX, y: 2.4)), "큰 카드의 변 휨이 깎였다")
    }

    /// 같은 시드는 항상 같은 그림 — 레이아웃·애니메이션 안정(§13.1).
    func testSeedIsDeterministic() {
        let rect = CGRect(x: 0, y: 0, width: 120, height: 60)
        let a = PaperRect(cornerRadius: ReffiRadius.md, seed: 3).path(in: rect)
        let b = PaperRect(cornerRadius: ReffiRadius.md, seed: 3).path(in: rect)
        XCTAssertEqual(a.description, b.description)
    }
}

/// `PaperRingArc`(History 히어로의 종이 고리) — 각도 규약과 이음매를 셰이프 수준에서 고정한다.
/// 렌더 결과는 스크린샷이 보지만, "12시에서 시계방향"과 "꽉 찬 고리에 홈이 없다"는 회귀는 여기서 막는다.
final class PaperRingArcTests: XCTestCase {

    private let rect = CGRect(x: 0, y: 0, width: 156, height: 156)

    private func points(_ path: Path) -> [CGPoint] {
        var result: [CGPoint] = []
        path.forEach { element in
            switch element {
            case .move(let p):  result.append(p)
            case .line(let p):  result.append(p)
            default:            break
            }
        }
        return result
    }

    /// 0%는 종이 조각을 만들지 않는다 — 폭 0의 도형을 그리면 잉크 한 점이 12시에 찍힌다.
    func testZeroFractionDrawsNothing() {
        XCTAssertTrue(PaperRingArc(start: 0, end: 0, thickness: 18).path(in: rect).isEmpty)
        XCTAssertTrue(PaperRingArc(start: 0.4, end: 0.2, thickness: 18).path(in: rect).isEmpty)
    }

    /// 0 = 12시, 진행은 시계방향. 25%면 오른쪽 위 사분면만 채운다.
    func testArcStartsAtTwelveAndRunsClockwise() {
        let path = PaperRingArc(start: 0, end: 0.25, thickness: 18, seed: 4).path(in: rect)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let midBand = min(rect.width, rect.height) / 2 - 9      // 띠 한가운데 반지름

        func onBand(_ turn: Double) -> CGPoint {
            let a = (turn - 0.25) * 2 * .pi
            return CGPoint(x: center.x + midBand * CGFloat(cos(a)),
                           y: center.y + midBand * CGFloat(sin(a)))
        }
        XCTAssertTrue(path.contains(onBand(0.125)), "1시 30분 방향(첫 사분면 한가운데)은 채워져 있어야 한다")
        XCTAssertFalse(path.contains(onBand(0.375)), "4시 30분 방향은 25% 구간 밖이다")
        XCTAssertFalse(path.contains(onBand(0.875)), "10시 30분 방향은 25% 구간 밖이다")
        XCTAssertFalse(path.contains(center), "가운데는 뚫려 있어야 한다(고리지 원판이 아니다)")
    }

    /// 꽉 찬 고리에는 **잘린 단면이 없다** — 윤곽도 그래야 한다. 바깥·안쪽을 한 폴리곤으로 이으면
    /// 12시에 폭 0의 반지름 슬릿이 윤곽에 남고 `paperEdge` 스트로크가 거기에 실선을 그린다
    /// (첫 캡처에서 세로 이음매로 보였다). 그래서 닫힌 서브패스 **둘**이어야 한다.
    func testFullRingIsTwoClosedLoopsWithNoRadialSeam() {
        let path = PaperRingArc(start: 0, end: 1, thickness: 18, seed: 4).path(in: rect)
        var moves = 0, closes = 0
        path.forEach { element in
            switch element {
            case .move:         moves += 1
            case .closeSubpath: closes += 1
            default:            break
            }
        }
        XCTAssertEqual(moves, 2, "바깥·안쪽 두 닫힌 고리여야 한다")
        XCTAssertEqual(closes, 2)
        XCTAssertEqual(points(path).count, 36, "18각 두 바퀴(시작점이 끝점과 겹치지 않는다)")
        // 가운데는 뚫려 있고(원판 아님) 12시 띠 한가운데는 채워져 있다(홈 아님).
        XCTAssertFalse(path.contains(CGPoint(x: rect.midX, y: rect.midY)))
        XCTAssertTrue(path.contains(CGPoint(x: rect.midX, y: rect.midY - (rect.width / 2 - 9))))
    }

    /// 매끈한 원이 아니다 — 곡선 세그먼트가 하나도 없어야 한다(§13.1, 스톡 진행 링 금지).
    func testRingHasNoCurves() {
        var curves = 0
        PaperRingArc(start: 0, end: 0.7, thickness: 18, seed: 4).path(in: rect).forEach { element in
            switch element {
            case .quadCurve, .curve: curves += 1
            default: break
            }
        }
        XCTAssertEqual(curves, 0, "종이 고리는 직선 변으로만 잘린다")
    }

    /// 같은 시드는 항상 같은 윤곽(§13.1) — 값이 바뀌어도 가위 자국은 제자리에 있어야 한다.
    func testSeedIsDeterministic() {
        let a = PaperRingArc(start: 0, end: 0.6, thickness: 18, seed: 4).path(in: rect)
        let b = PaperRingArc(start: 0, end: 0.6, thickness: 18, seed: 4).path(in: rect)
        XCTAssertEqual(a.description, b.description)
    }
}

/// `PaperGlyphPile`의 배치 — 히어로 배경은 **정지된 그림**이라야 한다(§13.10).
/// 매번 다르게 흩뿌려지면 스크롤·탭 왕복마다 배경이 바뀌고, 캐시도 의미를 잃는다.
final class PaperGlyphPileTests: XCTestCase {

    private let band = CGSize(width: 402, height: 306)

    /// 같은 입력이면 항상 같은 그림 — 굽기 캐시가 성립하는 전제다.
    func testPlacementsAreDeterministic() {
        let a = PaperGlyphPile.placements(count: 6, in: band, seed: 24)
        let b = PaperGlyphPile.placements(count: 6, in: band, seed: 24)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, PaperGlyphPile.placements(count: 6, in: band, seed: 25),
                          "시드가 다르면 다른 구성이어야 한다")
    }

    /// 격자 스무 칸을 다 채우고, 글리프는 순환해서 골고루 쓴다(한 종류가 화면을 덮으면 무늬가 된다).
    func testEveryCellIsFilledAndGlyphsCycle() {
        let spots = PaperGlyphPile.placements(count: 3, in: band, seed: 24)
        XCTAssertEqual(spots.count, 20, "5 × 4 격자")
        XCTAssertEqual(Set(spots.map(\.glyphIndex)), [0, 1, 2], "주어진 글리프를 모두 쓴다")
        XCTAssertTrue(spots.allSatisfy { $0.side > 0 }, "폭 0 조각은 그리지 않는다")
    }

    /// 바깥 줄은 밴드 가장자리에 걸친다 — 잘린 조각이 있어야 "더 큰 더미의 일부"로 읽힌다.
    func testOuterRowStraddlesTheEdge() {
        let spots = PaperGlyphPile.placements(count: 4, in: band, seed: 24)
        let jitter = band.width / 4 * 0.55 / 2          // 칸 간격의 ±27.5%
        XCTAssertTrue(spots.contains { $0.center.x < jitter + 0.001 }, "왼쪽 가장자리에 걸친 조각")
        XCTAssertTrue(spots.contains { $0.center.x > band.width - jitter - 0.001 }, "오른쪽 가장자리")
    }

    /// 빈 입력에 도형을 만들지 않는다(호출부가 폴백을 넘기지만 프리미티브도 스스로 막는다).
    func testEmptyInputYieldsNoPlacements() {
        XCTAssertTrue(PaperGlyphPile.placements(count: 0, in: band, seed: 24).isEmpty)
        XCTAssertTrue(PaperGlyphPile.placements(count: 5, in: .zero, seed: 24).isEmpty)
    }
}
