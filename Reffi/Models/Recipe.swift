import Foundation

/// 레시피 — 임박 재료를 조합해 소비를 유도(§1).
struct Recipe: Identifiable {
    let id = UUID()
    var name: String                // "애호박 두부조림"
    var ingredientNames: [String]   // 사용 재료(매칭용)
    var minutes: Int                // 조리 시간(분)
    var glyph: FoodGlyph            // 히어로 대표 모티프
}
