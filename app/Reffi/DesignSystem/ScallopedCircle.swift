import SwiftUI

/// 각진 패싯 다각형 — 오렌지 윤곽처럼 직선 변으로 이뤄진 9각형(살짝 불규칙).
/// 정점의 반지름·각도를 미세하게 흩뜨려 손으로 그린 듯 자연스럽게. 고정값이라 항상 같은 모양.
struct ScallopedCircle: Shape {
    /// 변(정점) 개수.
    var sides: Int = 9

    // 정점별 반지름 배율(≈1.0)과 각도 흔들림(라디안) — 약간의 불규칙으로 비대칭.
    private let radiusFactors: [CGFloat] = [1.00, 0.96, 1.00, 0.94, 0.99, 0.96, 1.00, 0.95, 0.98]
    private let angleJitter: [CGFloat]   = [0.00, 0.07, -0.05, 0.06, -0.04, 0.05, -0.06, 0.04, -0.03]

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let baseR = min(rect.width, rect.height) / 2
        let n = max(3, sides)
        // 위쪽 정점에서 시작하도록 -90° 오프셋.
        let start = -CGFloat.pi / 2

        var path = Path()
        for i in 0..<n {
            let rf = radiusFactors[i % radiusFactors.count]
            let jit = angleJitter[i % angleJitter.count]
            let angle = start + (CGFloat(i) / CGFloat(n)) * 2 * .pi + jit
            let r = baseR * rf
            let pt = CGPoint(x: center.x + r * cos(angle),
                             y: center.y + r * sin(angle))
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }
}
