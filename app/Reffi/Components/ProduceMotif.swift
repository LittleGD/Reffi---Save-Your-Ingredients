import SwiftUI

/// 볼드 기하 식재료 모티프 (무드보드: 미드센추리 포크, 단순 도형으로 만든 과일/채소).
/// 카테고리별 자체 비비드 색을 가져 신선도색 카드 위에 다채색을 얹는다.
struct ProduceMotif: View {
    let category: IngredientCategory

    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            func disc(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat, _ c: Color) {
                let r = CGRect(x: (cx - rx) * w, y: (cy - ry) * h, width: 2 * rx * w, height: 2 * ry * h)
                ctx.fill(Path(ellipseIn: r), with: .color(c))
            }
            func line(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat, _ c: Color, _ lw: CGFloat) {
                var p = Path(); p.move(to: CGPoint(x: x1 * w, y: y1 * h)); p.addLine(to: CGPoint(x: x2 * w, y: y2 * h))
                ctx.stroke(p, with: .color(c), style: StrokeStyle(lineWidth: lw * w, lineCap: .round))
            }
            func tri(_ pts: [(CGFloat, CGFloat)], _ c: Color) {
                var p = Path(); p.move(to: CGPoint(x: pts[0].0 * w, y: pts[0].1 * h))
                for q in pts.dropFirst() { p.addLine(to: CGPoint(x: q.0 * w, y: q.1 * h)) }
                p.closeSubpath(); ctx.fill(p, with: .color(c))
            }
            func roundRect(_ x: CGFloat, _ y: CGFloat, _ rw: CGFloat, _ rh: CGFloat, _ rad: CGFloat, _ c: Color) {
                let rect = CGRect(x: x * w, y: y * h, width: rw * w, height: rh * h)
                ctx.fill(Path(roundedRect: rect, cornerRadius: rad * w), with: .color(c))
            }

            switch category {
            case .fruit: // 체리 — 줄기/잎 + 빨간 알 두 개
                line(0.34, 0.66, 0.58, 0.24, C.leaf, 0.05)
                line(0.66, 0.68, 0.6, 0.24, C.leaf, 0.05)
                disc(0.74, 0.2, 0.13, 0.07, C.leaf)
                disc(0.34, 0.7, 0.17, 0.17, C.red)
                disc(0.66, 0.72, 0.17, 0.17, C.redDark)
            case .vegetables: // 새싹 — 줄기 + 잎 + 봉오리
                line(0.5, 0.92, 0.5, 0.5, C.greenDark, 0.05)
                disc(0.36, 0.52, 0.13, 0.09, C.green)
                disc(0.64, 0.52, 0.13, 0.09, C.green)
                disc(0.5, 0.36, 0.15, 0.15, C.greenBright)
            case .meat: // 스테이크 — 분홍 덩어리 + 뼈
                roundRect(0.16, 0.32, 0.6, 0.42, 0.1, C.meat)
                disc(0.74, 0.36, 0.11, 0.11, C.bone)
            case .seafood: // 생선 — 몸통 + 꼬리 + 눈
                tri([(0.66, 0.5), (0.92, 0.32), (0.92, 0.68)], C.fishDark)
                disc(0.44, 0.5, 0.28, 0.2, C.fish)
                disc(0.3, 0.45, 0.035, 0.035, C.ink)
            case .dairy: // 우유 + 계란 — 카톤(왼쪽) + 달걀(오른쪽)
                // 우유 카톤
                roundRect(0.08, 0.44, 0.32, 0.44, 0.04, C.milkBody)   // 몸통
                tri([(0.08, 0.44), (0.40, 0.44), (0.24, 0.24)], C.milkRoof) // 게이블 지붕
                roundRect(0.12, 0.60, 0.24, 0.08, 0.02, C.milkRoof)  // 블루 라벨 띠
                // 달걀
                disc(0.72, 0.62, 0.17, 0.21, C.eggWhite)
                disc(0.72, 0.66, 0.085, 0.085, C.yolk)
            case .grains: // 밀이삭 — 줄기 + 낱알
                line(0.5, 0.92, 0.5, 0.34, C.wheatDark, 0.045)
                for y in [0.36, 0.5, 0.64] as [CGFloat] {
                    disc(0.37, y, 0.11, 0.07, C.wheat)
                    disc(0.63, y, 0.11, 0.07, C.wheat)
                }
                disc(0.5, 0.27, 0.09, 0.11, C.wheat)
            case .other: // 꽃 — 꽃잎 + 가운데
                for i in 0..<6 {
                    let a = CGFloat(i) / 6 * 2 * .pi
                    disc(0.5 + 0.22 * cos(a), 0.5 + 0.22 * sin(a), 0.14, 0.14, C.flower)
                }
                disc(0.5, 0.5, 0.15, 0.15, C.flowerMid)
            }
        }
        .accessibilityHidden(true)
    }

    /// 모티프 비비드 팔레트(무드보드 톤).
    private enum C {
        static let red        = Color(hex: "#E8463C")
        static let redDark    = Color(hex: "#C9342B")
        static let leaf       = Color(hex: "#4FA64A")
        static let green      = Color(hex: "#5FB85A")
        static let greenBright = Color(hex: "#7BC74C")
        static let greenDark  = Color(hex: "#3E8E3A")
        static let meat       = Color(hex: "#EE9385")
        static let bone       = Color(hex: "#FBEFE6")
        static let fish       = Color(hex: "#3E9DB0")
        static let fishDark   = Color(hex: "#2E7E8F")
        static let eggWhite   = Color(hex: "#FBF6EC")
        static let yolk       = Color(hex: "#F4B53F")
        static let milkBody   = Color(hex: "#EAF2F8")
        static let milkRoof   = Color(hex: "#5FA8CB")
        static let wheat      = Color(hex: "#E0A94E")
        static let wheatDark  = Color(hex: "#C98E36")
        static let flower     = Color(hex: "#EF7FA8")
        static let flowerMid  = Color(hex: "#F4B53F")
        static let ink        = Color(hex: "#25211B")
    }
}

/// 카테고리 모티프 마크 — 스캘럽 도장 없이 볼드 모티프만(무드보드 기하 과일).
struct CategoryStamp: View {
    let category: IngredientCategory
    var size: CGFloat = 46

    var body: some View {
        ProduceMotif(category: category)
            .frame(width: size, height: size)
    }
}
