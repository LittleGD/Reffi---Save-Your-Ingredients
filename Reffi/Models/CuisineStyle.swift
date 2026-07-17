import Foundation

/// 요리 스타일 선호(§5.2) — 프로필에서 멀티 선택, 추후 레시피 추천 가중치의 소스가 된다.
/// rawValue는 UserDefaults 영속화용 안정 키(라벨 바뀌어도 저장값 유지).
/// brazilian은 제거 — 시드 레시피에 대응 cuisine이 0건이라 어떤 실동작(가점)도 못 만드는
/// 위약 옵션이었다(MVP 원칙). 저장된 rawValue는 ProfileStore가 compactMap으로 무시(안전 디코드).
enum CuisineStyle: String, CaseIterable, Identifiable, Codable {
    case korean, western, japanese, chinese, italian, mexican
    case indian, thai, mediterranean, vietnamese, vegetarian

    var id: String { rawValue }

    /// 칩·요약 라벨 — 저장값은 영문 식별자 그대로, 표시만 로컬라이즈.
    var label: String {
        switch self {
        case .korean:        String(localized: "Korean")
        case .western:       String(localized: "Western")
        case .japanese:      String(localized: "Japanese")
        case .chinese:       String(localized: "Chinese")
        case .italian:       String(localized: "Italian")
        case .mexican:       String(localized: "Mexican")
        case .indian:        String(localized: "Indian")
        case .thai:          String(localized: "Thai")
        case .mediterranean: String(localized: "Mediterranean")
        case .vietnamese:    String(localized: "Vietnamese")
        case .vegetarian:    String(localized: "Vegetarian")
        }
    }
}

extension Set where Element == CuisineStyle {
    /// 프로필 행 요약 — "한식 · 양식 +1" (CaseIterable 순서로 안정 정렬).
    var summaryText: String {
        guard !isEmpty else { return String(localized: "None yet") }
        let ordered = CuisineStyle.allCases.filter { contains($0) }
        let head = ordered.prefix(2).map(\.label).joined(separator: " · ")
        let extra = ordered.count - Swift.min(2, ordered.count)
        return extra > 0 ? "\(head) +\(extra)" : head
    }
}
