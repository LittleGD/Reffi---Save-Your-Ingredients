import SwiftUI

/// 점선 룰 — 오더 티켓의 절취선 느낌.
///
/// 공유 킷(`PaperDropdown`)까지 쓰는 크로스피처 프리미티브라 피처가 아니라 여기 산다.
struct DashedRule: View {
    var body: some View {
        GeometryReader { g in
            Path { p in
                p.move(to: CGPoint(x: 0, y: 0.5))
                p.addLine(to: CGPoint(x: g.size.width, y: 0.5))
            }
            .stroke(ReffiColor.ink.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }
        .frame(height: 1)
    }
}
