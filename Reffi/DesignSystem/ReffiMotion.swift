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

    /// 진입 커브(ease-out)를 **길이만 바깥에서** 받는 형태. 던진 속도가 이탈 시간을 정하는
    /// 자리(캐러셀 플릭)처럼 듀레이션이 데이터에서 나오는 곳에만 쓴다 — 커브는 여전히 토큰이라
    /// 콜사이트에 SwiftUI 기본 `.easeOut`(0,0,0.58,1)이 섞여 들어가지 않는다(§7.1과 다른 커브다).
    static func easeOut(duration: Double) -> Animation {
        .timingCurve(0.23, 1, 0.32, 1, duration: duration)
    }

    // MARK: - §7.1 밖 예외

    /// 배경 색면 전환(0.5s) — §7.1 듀레이션 밖 **유일한 예외**다.
    /// 홈 배경의 어컨트·긴급 시노처럼 화면 전체를 덮은 색면은 dur3(0.24s)로 갈아타면 "깜빡"으로
    /// 읽힌다. 눈이 쫓지 않아야 하는 주변광이라 느리게 밀어야 배경으로 남는다.
    /// **여기 말고는 쓰지 않는다** — 전경 요소가 이 길이를 쓰면 UI가 굼떠진다.
    static let durAmbient: Double = 0.5
    /// 배경 색면 전환 — ease-in-out(들고 나는 양쪽이 다 배경이라 진입/이탈을 가르지 않는다).
    static var ambient: Animation { .easeInOut(duration: durAmbient) }

    // MARK: - 통통 튀는 스프링(§7.5) — 종이컷 표면의 활기. transform·opacity만.

    /// 뱃지 등장/pop-in — 살짝 오버슈트.
    static var pop: Animation { .spring(response: 0.34, dampingFraction: 0.56) }
    /// 행 reflow — 토글·추가로 뱃지 줄이 다시 흐를 때, 부드럽게.
    static var settle: Animation { .spring(response: 0.50, dampingFraction: 0.74) }
    /// 통통 프레스 — 버튼 누름(0.96→1 오버슈트).
    static var bouncyPress: Animation { .spring(response: 0.25, dampingFraction: 0.55) }
    /// 종이컷 도장 슬램 — 큰 상태에서 쾅 내려앉는 깊은 오버슈트(온보딩 Start 도장·히어로 stamp).
    /// `pop`보다 짧고 덜 감쇠해 "튀어 오른다"가 아니라 "찍힌다"로 읽힌다. 도장 전용이다.
    static var slam: Animation { .spring(response: 0.26, dampingFraction: 0.5) }

    /// reduced-motion 존중 헬퍼(§7.4) — 줄이면 애니메이션 제거.
    static func gated(_ a: Animation, reduce: Bool) -> Animation? { reduce ? nil : a }
}

/// 종이컷 통통 프레스 — pressed = scale(0.96) + bouncy 스프링(§7.2/7.5). 종이 버튼·뱃지에.
/// 모션 축소(§7.4)에서는 스케일 값은 남기고 **전환만** 지운다 — pressed 상태 자체는 §7.2의 계약이다.
struct PaperPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(ReffiMotion.gated(ReffiMotion.bouncyPress, reduce: reduceMotion),
                       value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PaperPressStyle {
    static var paperPress: PaperPressStyle { PaperPressStyle() }
}

/// pressed 상태 = scale(0.97) (§7.2). 모든 인터랙티브 요소에.
struct ReffiPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(ReffiMotion.gated(ReffiMotion.press, reduce: reduceMotion),
                       value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == ReffiPressStyle {
    static var reffiPress: ReffiPressStyle { ReffiPressStyle() }
}
