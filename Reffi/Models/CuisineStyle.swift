import Foundation

/// 요리 스타일 선호(§5.2) — 프로필에서 멀티 선택, 추후 레시피 추천 가중치의 소스가 된다.
/// rawValue는 UserDefaults 영속화용 안정 키(라벨 바뀌어도 저장값 유지).
enum CuisineStyle: String, CaseIterable, Identifiable, Codable {
    case korean, western, japanese, chinese, italian, mexican
    case brazilian, indian, thai, mediterranean, vietnamese, vegetarian

    var id: String { rawValue }

    /// 칩·요약 라벨(앱 디폴트 = 영문).
    var label: String {
        switch self {
        case .korean:        "Korean"
        case .western:       "Western"
        case .japanese:      "Japanese"
        case .chinese:       "Chinese"
        case .italian:       "Italian"
        case .mexican:       "Mexican"
        case .brazilian:     "Brazilian"
        case .indian:        "Indian"
        case .thai:          "Thai"
        case .mediterranean: "Mediterranean"
        case .vietnamese:    "Vietnamese"
        case .vegetarian:    "Vegetarian"
        }
    }
}

extension Set where Element == CuisineStyle {
    /// 프로필 행 요약 — "한식 · 양식 +1" (CaseIterable 순서로 안정 정렬).
    var summaryText: String {
        guard !isEmpty else { return "None yet" }
        let ordered = CuisineStyle.allCases.filter { contains($0) }
        let head = ordered.prefix(2).map(\.label).joined(separator: " · ")
        let extra = ordered.count - Swift.min(2, ordered.count)
        return extra > 0 ? "\(head) +\(extra)" : head
    }
}
