import SwiftUI

/// 영수증 구분선 — 점선/대시 룰. 도형으로 그려 에셋 추가가 없다.
/// 쓰는 쪽에서 `.stroke(style:)`로 점선 패턴을 지정한다.
struct ReceiptRule: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}
