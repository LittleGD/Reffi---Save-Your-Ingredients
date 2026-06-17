import Foundation

/// 레시피 추천 — "지금 가장 빠르게 소비해야 하는 재료들을 가장 많이 쓰는" 레시피를 점수순으로.
/// 임박할수록 큰 가중치(urgent3/soon2/fresh1). 스와이프 덱은 이 순서대로 위→아래.
enum RecipeRecommender {

    /// 매치 분모에서 빼는 상비 재료(거의 항상 있다고 가정).
    static let staples: Set<String> = [
        "소금", "물", "식용유", "기름", "간장", "국간장", "설탕", "후추",
        "다진마늘", "마늘", "대파", "참기름", "고춧가루", "올리브유", "밥",
    ]

    struct Result: Identifiable {
        let id: UUID                 // = recipe.id (안정적 정체성)
        var recipe: Recipe
        var used: [Ingredient]       // 보유 재료 중 이 레시피가 쓰는 것(임박 순)
        var total: Int               // 비-상비 재료 수(매치 분모)
        var missing: [String]        // 비-상비 중 미보유
        var urgentUsedCount: Int     // 그중 오늘(urgent) 소진되는 수
    }

    static func isStaple(_ token: String) -> Bool {
        staples.contains { token.contains($0) }
    }

    static func matches(_ ing: Ingredient, _ token: String) -> Bool {
        ing.name == token || ing.name.contains(token) || token.contains(ing.name)
    }

    static func weight(_ ing: Ingredient) -> Int {
        switch ing.freshness {
        case .urgent: 3
        case .soon:   2
        case .fresh:  1
        }
    }

    static func result(for recipe: Recipe, ingredients: [Ingredient]) -> Result {
        let nonStaple = recipe.ingredientNames.filter { !isStaple($0) }
        let used = ingredients
            .filter { ing in nonStaple.contains { matches(ing, $0) } }
            .sorted { $0.daysLeft < $1.daysLeft }
        let missing = nonStaple.filter { token in !ingredients.contains { matches($0, token) } }
        let urgent = used.filter { $0.freshness == .urgent }.count
        return Result(id: recipe.id, recipe: recipe, used: used,
                      total: nonStaple.count, missing: missing, urgentUsedCount: urgent)
    }

    /// 점수순 정렬된 추천 덱(보유 재료를 하나라도 쓰는 레시피만).
    static func rank(for ingredients: [Ingredient], from recipes: [Recipe]) -> [Result] {
        recipes
            .map { result(for: $0, ingredients: ingredients) }
            .filter { !$0.used.isEmpty }
            .sorted { a, b in
                let sa = a.used.reduce(0) { $0 + weight($1) }
                let sb = b.used.reduce(0) { $0 + weight($1) }
                if sa != sb { return sa > sb }
                if a.urgentUsedCount != b.urgentUsedCount { return a.urgentUsedCount > b.urgentUsedCount }
                return a.missing.count < b.missing.count
            }
    }

    /// 단일 추천(구 홈 화면 호환).
    static func recommend(for ingredients: [Ingredient], from recipes: [Recipe]) -> Result? {
        rank(for: ingredients, from: recipes).first
            ?? recipes.first.map { result(for: $0, ingredients: ingredients) }
    }
}
