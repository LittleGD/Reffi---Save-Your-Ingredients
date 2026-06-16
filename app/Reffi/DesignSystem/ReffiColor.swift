import SwiftUI

/// Reffi 디자인 시스템 색 토큰 (§2 통합 토큰).
/// 정본은 OKLCH이며 여기 값은 문서의 hex 근삿값(sRGB)이다.
///
/// 운용 규칙(§2.4 60:30:5:5, §2.6 대비):
/// - 신선도 파스텔(fresh/soon/urgent) 면 위 글자 = `ink`
/// - Blue 면 위 글자 = `.white`
/// - 캔버스 위에 색을 글자·세선으로 쓸 땐 그 색의 `*Dark` 변형
enum ReffiColor {
    // MARK: Brand · Fresh / Soon / Urgent (파스텔) + Blue
    static let fresh       = Color(hex: "#ADE393") // 신선 · 여유 (D-4+)
    static let freshDark   = Color(hex: "#387332")
    static let freshLight  = Color(hex: "#E5F5D9")

    static let soon        = Color(hex: "#F4C767") // 곧 · 임박 (D-3~1)
    static let soonDark    = Color(hex: "#996000")
    static let soonLight   = Color(hex: "#FDEDCD")

    static let urgent      = Color(hex: "#F68D70") // 오늘 · 지남 (D-0-)
    static let urgentDark  = Color(hex: "#AE3F2C")
    static let urgentLight = Color(hex: "#FFDDD3")

    static let blue        = Color(hex: "#176AB0") // 브랜드 · 레시피/AI · 기본 액션
    static let blueDark    = Color(hex: "#004985")
    static let blueLight   = Color(hex: "#D2EBFF")

    // MARK: Neutral (5단계) · 크림 램프
    static let neutral900  = Color(hex: "#25211B") // ink · 본문/제목
    static let neutral700  = Color(hex: "#544F47") // 보조 텍스트 · 캡션
    static let neutral500  = Color(hex: "#78746C") // 약한 텍스트 · placeholder
    static let neutral200  = Color(hex: "#ECE9E4") // 서브 면 · 스켈레톤
    static let neutral50   = Color(hex: "#F8F5EC") // Canvas · 페이지 배경(크림)

    // MARK: Semantic aliases
    static let primary  = blue
    static let action   = blue
    static let recipe   = blue
    static let canvas   = neutral50
    static let ink      = neutral900
    static let ink2     = neutral700
    static let muted    = neutral500
}
