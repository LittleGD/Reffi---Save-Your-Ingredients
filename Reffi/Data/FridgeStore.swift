import Observation

/// 냉장고 상태 — 메인 페이지의 단일 소스. 디자인 빌드라 샘플 데이터로 시드한다.
@Observable
final class FridgeStore {
    var ingredients: [Ingredient]
    var recipes: [Recipe]

    init(ingredients: [Ingredient] = SampleData.ingredients,
         recipes: [Recipe] = SampleData.recipes) {
        self.ingredients = ingredients
        self.recipes = recipes
    }

    /// 마감 임박 오름차순(§8.1) — 위에서부터 "먹어야 할 순서".
    var sorted: [Ingredient] {
        ingredients.sorted { $0.daysLeft < $1.daysLeft }
    }

    /// 오늘의 추천 레시피(가장 급한 재료들을 가장 많이 쓰는 것).
    var recommendation: RecipeRecommender.Result? {
        RecipeRecommender.recommend(for: sorted, from: recipes)
    }

    /// 스와이프 덱 — 점수순 추천 배열(위에서부터 먹어야 할 순서).
    var rankedRecipes: [RecipeRecommender.Result] {
        RecipeRecommender.rank(for: sorted, from: recipes)
    }

    func remove(_ ingredient: Ingredient) {
        ingredients.removeAll { $0.id == ingredient.id }
    }

    // MARK: - 음식 낭비 추적(Ate / Tossed)

    private(set) var ateCount = 0
    private(set) var tossedCount = 0

    /// 다 먹음 — 보유에서 빼고 "먹음" 카운트.
    func eat(_ ingredient: Ingredient) { ateCount += 1; remove(ingredient) }
    /// 버림 — 보유에서 빼고 "버림" 카운트.
    func toss(_ ingredient: Ingredient) { tossedCount += 1; remove(ingredient) }
}
