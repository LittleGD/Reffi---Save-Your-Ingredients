import SwiftUI

/// 리퀴드글래스 배경(§13) — 크림 캔버스 위 부드러운 컬러 블롭 + 글래스 프로스트.
/// Main·Fridge가 공유해 한 몸으로 보이게 한다. `accent`는 가장 임박한 재료의 신선도색.
struct LiquidGlassBackground: View {
    var accent: Color = ReffiColor.fresh

    var body: some View {
        ZStack {
            ReffiColor.canvas
            Circle().fill(accent.opacity(0.5)).frame(width: 300, height: 300).blur(radius: 80)
                .offset(x: -130, y: -180)
            Circle().fill(ReffiColor.blue.opacity(0.28)).frame(width: 260, height: 260).blur(radius: 90)
                .offset(x: 140, y: 60)
            Circle().fill(accent.opacity(0.16)).frame(width: 220, height: 220).blur(radius: 80)
                .offset(x: 70, y: 320)
            glassFrost
            LinearGradient(colors: [.white.opacity(0.2), .clear, .white.opacity(0.06)],
                           startPoint: .top, endPoint: .bottom)
        }
        .ignoresSafeArea()
    }

    @ViewBuilder private var glassFrost: some View {
        if #available(iOS 26.0, *) {
            Rectangle().fill(.clear).glassEffect(.regular, in: Rectangle())
        } else {
            Rectangle().fill(.ultraThinMaterial)
        }
    }
}
