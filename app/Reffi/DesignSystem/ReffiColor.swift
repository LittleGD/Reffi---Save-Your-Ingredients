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

    // MARK: 신선도 연속 램프 — 냉장고 카드 스택 전용(§8).
    // 3단계 고정색(`Freshness.color`)은 칩·배지 등 단일 항목에 그대로 쓰고,
    // 여러 항목이 한 스택에 쌓이는 냉장고에서만 daysLeft로 색을 보간해
    // 임박할수록 진한 테라코타 → 주황 → 옅은 초록의 연속 그라데이션을 만든다.
    // 앵커는 전부 DS 토큰에서 유도(0=urgent×0.7+urgentDark×0.3, 2=urgent,
    // 3=soon, 4=soon↔fresh 중간, 7=fresh, 14=freshLight).
    static func freshnessFill(daysLeft: Int) -> Color {
        let c = freshnessFillRGB(daysLeft: daysLeft)
        return Color(.sRGB, red: c.r, green: c.g, blue: c.b)
    }

    /// 카드 보조 글자(카테고리·상세 라벨)를 흰색으로 쓸지.
    /// 빨강~노랑(urgent·soon, D-3 이하)은 흰색, 초록(fresh, D-4+)은 검정.
    /// 휘도로는 노랑과 옅은 초록이 거의 같은 밝기(≈0.79)라 구분이 안 돼, 신선도(daysLeft)로 가른다.
    /// 경계(3)만 바꾸면 흰색 적용 범위가 조절된다.
    static func freshnessPrefersWhiteText(daysLeft: Int) -> Bool {
        daysLeft <= 3
    }

    /// daysLeft → 보간된 정규화 RGB(0…1). 면색과 휘도 계산이 공유한다.
    private static func freshnessFillRGB(daysLeft: Int) -> (r: Double, g: Double, b: Double) {
        // 무드보드 톤 — 살짝 밝되 채도는 톤다운한 신선도 램프(과하지 않게).
        let stops: [(day: Double, r: Double, g: Double, b: Double)] = [
            (0,  226, 128, 106), // deep urgent — 부드러운 테라코타
            (2,  240, 154, 124), // urgent — 코랄
            (3,  244, 200, 118), // soon — 마리골드
            (4,  206, 216, 138), // soon↔fresh
            (7,  176, 222, 152), // fresh — 그래스 그린
            (14, 224, 242, 210), // freshLight
        ]
        func norm(_ s: (day: Double, r: Double, g: Double, b: Double)) -> (r: Double, g: Double, b: Double) {
            (s.r / 255, s.g / 255, s.b / 255)
        }
        let d = Double(max(0, daysLeft))
        if d <= stops.first!.day { return norm(stops.first!) }
        if d >= stops.last!.day { return norm(stops.last!) }
        for i in 0 ..< (stops.count - 1) {
            let lo = stops[i], hi = stops[i + 1]
            guard d >= lo.day, d <= hi.day else { continue }
            let t = (d - lo.day) / (hi.day - lo.day)
            return (
                (lo.r + (hi.r - lo.r) * t) / 255,
                (lo.g + (hi.g - lo.g) * t) / 255,
                (lo.b + (hi.b - lo.b) * t) / 255
            )
        }
        return (173 / 255, 227 / 255, 147 / 255)
    }
}
