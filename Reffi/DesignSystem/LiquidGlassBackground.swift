import SwiftUI

/// 리퀴드글래스 배경(§13) — 크림 캔버스 위 부드러운 컬러 블롭 + 글래스 프로스트.
/// Main·Fridge·History·쇼핑이 공유해 한 몸으로 보이게 한다. `accent`는 가장 임박한 재료의
/// 신선도색, `accentDeep`은 세 번째 블롭(기본은 accent 저강도).
/// 다크에선 블롭 불투명도를 내린다 — 어두운 캔버스 위에선 같은 값이 네온처럼 타올라
/// 종이 표면의 대비를 잡아먹는다(은은한 발광까지만).
struct LiquidGlassBackground: View {
    var accent: Color = ReffiColor.fresh
    var accentDeep: Color? = nil

    @Environment(\.colorScheme) private var scheme
    private var isDark: Bool { scheme == .dark }

    var body: some View {
        ZStack {
            ReffiColor.canvas
            Circle().fill(accent.opacity(isDark ? 0.35 : 0.55)).frame(width: 300, height: 300).blur(radius: 80)
                .offset(x: -130, y: -180)
            Circle().fill(ReffiColor.blue.opacity(isDark ? 0.20 : 0.30)).frame(width: 260, height: 260).blur(radius: 90)
                .offset(x: 140, y: 60)
            Circle().fill((accentDeep ?? accent).opacity(isDark ? 0.10 : 0.16)).frame(width: 220, height: 220).blur(radius: 80)
                .offset(x: 70, y: 300)
            // 글래스 프로스트(.ultraThinMaterial·glassEffect)는 시스템이 스킴에 맞춰 자동 적응한다.
            glassFrost
            LinearGradient(colors: [ReffiColor.bgSheen, .clear, .white.opacity(isDark ? 0.02 : 0.06)],
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
