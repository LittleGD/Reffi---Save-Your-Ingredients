import SwiftUI

/// 타이포그래피 (§3) — 영문 앱, iPhone(모바일) 스케일.
/// Display = Story Script(브랜드 모먼트, 단일 weight 400, 자간 0).
/// 그 외 = Google Sans Flex. 데이터성 숫자(D-N 등)는 `.num()`(tabular).
enum ReffiType {
    static let displayFamily = "Story Script"
    // Google ships GSF weights under split family names — must match exactly.
    static let gsfRegular = "Google Sans Flex"          // 400 + Bold(700)
    static let gsfMedium = "Google Sans Flex Medium"    // 500
    static let gsfSemiBold = "Google Sans Flex SemiBold" // 600

    struct Style {
        let size: CGFloat
        let weight: Font.Weight
        let lineHeightMultiple: CGFloat // line-height ÷ size
        let tracking: CGFloat           // letter-spacing(em) → pt = em × size
        var isDisplay: Bool = false
    }

    // 모바일 스케일 (§3.2). Display는 Story Script라 weight 400·자간 0.
    static let display = Style(size: 34, weight: .regular,  lineHeightMultiple: 1.2, tracking: 0,     isDisplay: true)
    static let heading = Style(size: 24, weight: .bold,     lineHeightMultiple: 1.2, tracking: -0.01)
    static let subhead = Style(size: 18, weight: .semibold, lineHeightMultiple: 1.2, tracking: -0.01)
    static let body    = Style(size: 16, weight: .regular,  lineHeightMultiple: 1.4, tracking: -0.01)
    static let caption = Style(size: 14, weight: .medium,   lineHeightMultiple: 1.4, tracking: 0.01)

    static func font(_ style: Style) -> Font {
        if style.isDisplay {
            // Story Script는 단일 weight(연결 글자) — weight 미적용.
            return .custom(displayFamily, fixedSize: style.size)
        }
        // 각 weight를 정확한 GSF 패밀리로 매핑(없는 weight를 .weight()로 합성하면 SF로 폴백됨).
        switch style.weight {
        case .bold:     return .custom(gsfRegular, fixedSize: style.size).weight(.bold) // 700: 같은 패밀리의 Bold 페이스
        case .semibold: return .custom(gsfSemiBold, fixedSize: style.size)              // 600
        case .medium:   return .custom(gsfMedium, fixedSize: style.size)                // 500
        default:        return .custom(gsfRegular, fixedSize: style.size)               // 400
        }
    }
}

extension View {
    /// Reffi 타이포 스타일 적용: 폰트 + 자간(tracking) + 행간(line-height).
    func reffiText(_ style: ReffiType.Style) -> some View {
        let lineSpacing = style.size * (style.lineHeightMultiple - 1)
        return self
            .font(ReffiType.font(style))
            .tracking(style.tracking * style.size)
            .lineSpacing(lineSpacing)
    }

    /// 데이터성 숫자: 고정폭(tabular).
    func num() -> some View {
        self.monospacedDigit()
    }
}
