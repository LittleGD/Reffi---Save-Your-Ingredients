import SwiftUI
import CoreGraphics

/// 글래스 한 정의 — **곧은 둥근 직사각형**(레퍼런스의 텀블러 글래스). 휘는 윗변·뾰족한 바닥 없음.
/// 재료는 이 안에 가둬져(옆으로 안 넘침) 쌓이고, 윗부분이 윗변 위로 솟는다. 물리 벽 = 같은 사각.
enum BowlGeometry {
    static let rimY: CGFloat      = 0.30   // 글래스 윗변(여기 위로 재료가 솟음)
    static let botY: CGFloat      = 0.98   // 바닥
    static let sideInset: CGFloat = 0.05   // 좌우 여백
    static let corner: CGFloat    = 26     // 모서리 곡률(pt)

    static func rect(in r: CGRect) -> CGRect {
        CGRect(x: r.minX + r.width * sideInset, y: r.minY + r.height * rimY,
               width: r.width * (1 - 2 * sideInset), height: r.height * (botY - rimY))
    }

    /// SwiftUI 실루엣 — 둥근 직사각형(뒤 면·앞 글래스 공용).
    static func silhouette(in r: CGRect) -> Path {
        Path(roundedRect: rect(in: r), cornerRadius: corner, style: .continuous)
    }

    /// 재료가 떨어지는 가로 범위.
    static func dropSpan(_ w: CGFloat) -> CGFloat { w * (1 - 2 * sideInset) * 0.78 }

    /// SpriteKit 물리 벽 — 곧은 좌우 벽 + 바닥, 위 열림(윗변 위로 솟음). 벽은 프레임 위까지 연장(안 넘침). y-up.
    static func physicsPath(size s: CGSize, inset: CGFloat) -> CGPath {
        let H = s.height
        let leftX = s.width * sideInset + inset
        let rightX = s.width * (1 - sideInset) - inset
        let botYd = H * botY - inset
        func f(_ x: CGFloat, _ yd: CGFloat) -> CGPoint { CGPoint(x: x, y: H - yd) } // y flip
        let p = CGMutablePath()
        p.move(to: f(leftX, 0))            // 좌 벽 상단(프레임 위 — 솟아도 안 넘침)
        p.addLine(to: f(leftX, botYd))     // 좌 벽
        p.addLine(to: f(rightX, botYd))    // 바닥(곧음)
        p.addLine(to: f(rightX, 0))        // 우 벽
        return p
    }
}
