import Foundation

/// 음식 모티프 종류 — 커스텀 색면 일러스트(FoodMotif)가 이 값으로 그린다.
enum FoodGlyph {
    case tofu, leaf, squash, root, apple, egg, citrus, generic
}

/// 재료 카드의 데이터 — 재료 · 소비량 · 대안액션(사용자 스펙).
struct Ingredient: Identifiable {
    let id = UUID()
    var name: String              // "연두부"
    var category: String          // "콩 · 두부"
    var daysLeft: Int             // D-day (음수 = 지남)
    var amount: String            // 소비량 "½모 남음"
    var alternative: AlternativeAction
    var glyph: FoodGlyph

    var freshness: Freshness { Freshness(daysLeft: daysLeft) }

    /// D-N 표기. D-0 = 오늘, 음수 = 지남(D+N). 데이터성 숫자(§3.4).
    var dDayText: String {
        daysLeft >= 0 ? "D-\(daysLeft)" : "D+\(-daysLeft)"
    }
}
