import Foundation

/// 요리 스타일 선호(§5.2) — 프로필에서 멀티 선택, 추후 레시피 추천 가중치의 소스가 된다.
/// rawValue는 UserDefaults 영속화용 안정 키(라벨 바뀌어도 저장값 유지).
enum CuisineStyle: String, CaseIterable, Identifiable, Codable {
    case korean, western, japanese, chinese, italian, mexican
    case brazilian, indian, thai, mediterranean, vietnamese, vegetarian

    var id: String { rawValue }

    /// 칩·요약에 쓰는 한글 라벨.
    var label: String {
        switch self {
        case .korean:        "한식"
        case .western:       "양식"
        case .japanese:      "일식"
        case .chinese:       "중식"
        case .italian:       "이탈리안"
        case .mexican:       "멕시칸"
        case .brazilian:     "브라질식"
        case .indian:        "인도식"
        case .thai:          "태국식"
        case .mediterranean: "지중해식"
        case .vietnamese:    "베트남식"
        case .vegetarian:    "채식 위주"
        }
    }
}

extension Set where Element == CuisineStyle {
    /// 프로필 행 요약 — "한식 · 양식 +1" (CaseIterable 순서로 안정 정렬).
    var summaryText: String {
        guard !isEmpty else { return "아직 없음" }
        let ordered = CuisineStyle.allCases.filter { contains($0) }
        let head = ordered.prefix(2).map(\.label).joined(separator: " · ")
        let extra = ordered.count - Swift.min(2, ordered.count)
        return extra > 0 ? "\(head) +\(extra)" : head
    }
}
