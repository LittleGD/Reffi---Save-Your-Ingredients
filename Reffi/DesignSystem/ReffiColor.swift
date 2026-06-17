import SwiftUI
import Foundation

/// Reffi 색 토큰.
///
/// 정본은 OKLCH(`design_system.md` §12). hex는 "참고용 근삿값"이라 코드에 넣지 않고,
/// OKLCH 값을 런타임에 sRGB로 변환한다(Björn Ottosson). 검증 결과 MD의 참고 hex와
/// 1:1 일치(Blue만 반올림 ±1). 색은 장식이 아니라 신선도 정보다(§1).
enum ReffiColor {

    // MARK: - Brand · Freshness (파스텔) + Blue (§2.2)

    static let fresh       = oklch(0.86,  0.12,  136)   // 신선 · 여유 (D-4+)
    static let freshDark   = oklch(0.50,  0.115, 142)
    static let freshLight  = oklch(0.95,  0.040, 132)

    static let soon        = oklch(0.85,  0.125, 84)    // 곧 · 임박 (D-3~1)
    static let soonDark    = oklch(0.54,  0.120, 71)
    static let soonLight   = oklch(0.95,  0.045, 84)

    static let urgent      = oklch(0.75,  0.135, 36)    // 오늘 · 지남 (D-0-)
    static let urgentDark  = oklch(0.52,  0.150, 32)
    static let urgentLight = oklch(0.93,  0.050, 33)

    static let blue        = oklch(0.514, 0.134, 249.8) // 브랜드 · 레시피/AI · 기본 액션
    static let blueDark    = oklch(0.40,  0.12,  250)
    static let blueLight   = oklch(0.93,  0.045, 250)

    // MARK: - Neutral · Reffi 크림 램프 (§2.3)

    static let ink    = oklch(0.25,  0.012, 80)   // neutral-900 · 본문/제목
    static let ink2   = oklch(0.43,  0.014, 80)   // neutral-700 · 보조/캡션
    static let muted  = oklch(0.56,  0.013, 80)   // neutral-500 · 약한/placeholder
    static let sub    = oklch(0.935, 0.008, 85)   // neutral-200 · 서브 면
    static let canvas = oklch(0.97,  0.012, 90)   // neutral-50  · 캔버스(크림)

    // MARK: - Semantic aliases (§12)

    static let primary = blue
    static let action  = blue
    static let recipe  = blue

    // MARK: - OKLCH → sRGB

    /// `oklch(L C H / a)` → SwiftUI sRGB `Color`. L·a 0~1, H 도(degree).
    static func oklch(_ L: Double, _ C: Double, _ H: Double, _ alpha: Double = 1) -> Color {
        let hr = H * .pi / 180
        let a = C * cos(hr)
        let b = C * sin(hr)

        // OKLab → LMS' (cube)
        let l_ = L + 0.3963377774 * a + 0.2158037573 * b
        let m_ = L - 0.1055613458 * a - 0.0638541728 * b
        let s_ = L - 0.0894841775 * a - 1.2914855480 * b
        let l = l_ * l_ * l_
        let m = m_ * m_ * m_
        let s = s_ * s_ * s_

        // LMS → linear sRGB
        let r =  4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
        let g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
        let bl = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s

        return Color(.sRGB,
                     red:     gammaEncode(r),
                     green:   gammaEncode(g),
                     blue:    gammaEncode(bl),
                     opacity: alpha)
    }

    private static func gammaEncode(_ x: Double) -> Double {
        let v = min(max(x, 0), 1)
        return v >= 0.0031308 ? 1.055 * pow(v, 1 / 2.4) - 0.055 : 12.92 * v
    }
}
