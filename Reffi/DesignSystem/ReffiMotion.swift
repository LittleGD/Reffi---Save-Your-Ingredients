import SwiftUI

/// 모션 토큰(§7). 짧고 절제되게, transform·opacity만. 진입은 ease-out, 이탈은 더 빠르게.
/// `prefers-reduced-motion`은 `@Environment(\.accessibilityReduceMotion)`로 존중(§7.4).
enum ReffiMotion {
    static let dur1: Double = 0.12   // 마이크로: 포커스·press
    static let dur2: Double = 0.18   // 표준 UI: hover·색 전환
    static let dur3: Double = 0.24   // 면 전환: 시트·카드 확장

    /// 진입 — ease-out, dur3.
    static var enter: Animation { .timingCurve(0.23, 1, 0.32, 1, duration: dur3) }
    /// 이탈 — 더 빠르게, dur1.
    static var exit: Animation { .timingCurve(0.32, 0, 0.67, 0, duration: dur1) }
    /// 상태 전환 — standard, dur2.
    static var standard: Animation { .timingCurve(0.40, 0, 0.20, 1, duration: dur2) }
    /// press — standard, dur1.
    static var press: Animation { .timingCurve(0.40, 0, 0.20, 1, duration: dur1) }
}

/// pressed 상태 = scale(0.97) (§7.2). 모든 인터랙티브 요소에.
struct ReffiPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(ReffiMotion.press, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == ReffiPressStyle {
    static var reffiPress: ReffiPressStyle { ReffiPressStyle() }
}
