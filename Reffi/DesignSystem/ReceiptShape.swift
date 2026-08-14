import SwiftUI

/// 영수증/티켓 셰이프 — 상·하 톱니(절취) 엣지. 좌우는 곧다.
///
/// 앱의 시그니처 종이 어휘라 피처가 아니라 디자인 시스템에 산다(`PaperShape` 옆).
struct ReceiptShape: Shape {
    var tooth: CGFloat = 9

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let t = max(4, tooth)
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + t))
        // 상단 톱니 (좌→우)
        var x = rect.minX
        var up = true
        while x < rect.maxX {
            let nx = min(x + t, rect.maxX)
            p.addLine(to: CGPoint(x: nx, y: rect.minY + (up ? 0 : t)))
            x = nx; up.toggle()
        }
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - t))
        // 하단 톱니 (우→좌)
        up = true
        x = rect.maxX
        while x > rect.minX {
            let nx = max(x - t, rect.minX)
            p.addLine(to: CGPoint(x: nx, y: rect.maxY - (up ? 0 : t)))
            x = nx; up.toggle()
        }
        p.closeSubpath()
        return p
    }
}

/// 가로 점선/구분선용 1px 라인.
struct HLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}
