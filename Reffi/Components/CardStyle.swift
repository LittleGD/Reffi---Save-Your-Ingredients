import SwiftUI

/// 재료 카드 디자인 옵션(사용자 선택용). 런치 인자 `-cardStyle A|B|C`로 전환, 기본은 A.
/// 공통 목표: 풀 파스텔의 낮은 대비·촌스러움을 줄이고, 카드 그림자가 라벨에 드리우지 않게 한다.
enum CardStyle: String, CaseIterable {
    case neutral   // A — 뉴트럴(화이트) 카드 + 신선도 좌측 레일, D-N은 색-dark
    case tint      // B — 소프트 신선도 light 틴트 면, D-N은 색-dark
    case pastel    // C — 정제 파스텔 면 + 다크 D-N 배지(대비 보강)

    static var current: CardStyle {
        switch UserDefaults.standard.string(forKey: "cardStyle")?.lowercased() {
        case "b", "tint":   return .tint
        case "c", "pastel": return .pastel
        default:            return .neutral
        }
    }

    var code: String {
        switch self { case .neutral: "A"; case .tint: "B"; case .pastel: "C" }
    }
    var title: String {
        switch self {
        case .neutral: "Neutral + freshness rail"
        case .tint:    "Soft tint"
        case .pastel:  "Refined pastel + badge"
        }
    }

    /// 카드 면 색 (depth로 인접 카드 미세 단차).
    func surface(_ f: Freshness, depth: Int = 0) -> Color {
        switch self {
        case .neutral: ReffiColor.oklch(max(0.965, 0.995 - Double(depth) * 0.006), 0.006, 92)
        case .tint:    f.light
        case .pastel:  f.face(depth: depth)
        }
    }

    /// 좌측 신선도 레일 — 현재 미사용(순수 뉴트럴 방향).
    var usesRail: Bool { false }

    /// D-N 글자 색 — 순수 뉴트럴(A)·파스텔(C)은 ink, 틴트(B)만 색-dark 액센트.
    func dayColor(_ f: Freshness) -> Color { self == .tint ? f.dark : ReffiColor.ink }

    /// D-N을 다크 솔리드 배지로 감싸는가(C).
    var dayAsBadge: Bool { self == .pastel }
}

/// 카드 분리 그림자 — 라벨에 드리우지 않게 아주 옅게(사용자 요청: 라벨 드롭섀도 금지).
struct CardLift: ViewModifier {
    var style: CardStyle
    @ViewBuilder func body(content: Content) -> some View {
        switch style {
        case .pastel:
            content.shadow(color: ReffiColor.ink.opacity(0.08), radius: 6, x: 0, y: -2)
        case .neutral, .tint:
            content
                .shadow(color: ReffiColor.ink.opacity(0.05), radius: 5, x: 0, y: 0)
                .shadow(color: ReffiColor.ink.opacity(0.035), radius: 1, x: 0, y: 1)
        }
    }
}
