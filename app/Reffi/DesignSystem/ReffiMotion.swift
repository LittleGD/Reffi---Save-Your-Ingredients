import SwiftUI

/// 모션 토큰 (§7.1) — DS의 cubic-bezier 곡선·지속시간을 SwiftUI Animation으로.
/// 진입은 ease-out, 이탈은 더 빠른 ease-in, 상태 전환은 ease-std.
enum ReffiMotion {
    static let durMicro: TimeInterval = 0.12   // dur-1: 포커스·press
    static let durStd: TimeInterval = 0.18     // dur-2: hover·색 전환
    static let durSurface: TimeInterval = 0.24 // dur-3: 면 전환·카드

    static let easeOut = Animation.timingCurve(0.23, 1, 0.32, 1, duration: durSurface) // 진입
    static let easeIn  = Animation.timingCurve(0.32, 0, 0.67, 0, duration: durStd)      // 이탈(더 빠르게)
    static let easeStd = Animation.timingCurve(0.40, 0, 0.20, 1, duration: durMicro)    // 상태 전환·press
}

/// 눌림 상태 = transform scale(0.97) (§7.2). 모션 축소 시 스케일·애니메이션 생략(§7.4).
struct ReffiPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PressBody(configuration: configuration)
    }

    private struct PressBody: View {
        let configuration: Configuration
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            configuration.label
                .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
                .animation(reduceMotion ? nil : ReffiMotion.easeStd, value: configuration.isPressed)
        }
    }
}
