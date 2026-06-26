import Observation

/// 냉장고 상태 — 메인 페이지의 단일 소스. 디자인 빌드라 샘플 데이터로 시드한다.
@Observable
final class FridgeStore {
    var ingredients: [Ingredient]
    var recipes: [Recipe]
    /// 소비/버림 이력 — History·낭비율의 소스(최신이 앞).
    var history: [RemovalLog]

    init(ingredients: [Ingredient] = SampleData.ingredients,
         recipes: [Recipe] = SampleData.recipes,
         history: [RemovalLog] = SampleData.history) {
        self.ingredients = ingredients
        self.recipes = recipes
        self.history = history
        self.ateCount = history.filter { !$0.wasted }.count
        self.tossedCount = history.filter(\.wasted).count
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

    /// 편집 저장 — 같은 id를 찾아 교체.
    func update(_ ingredient: Ingredient) {
        if let i = ingredients.firstIndex(where: { $0.id == ingredient.id }) {
            ingredients[i] = ingredient
        }
    }

    // MARK: - 음식 낭비 추적(Ate / Tossed)

    private(set) var ateCount = 0
    private(set) var tossedCount = 0

    /// 다 먹음 — 보유에서 빼고 이력 기록 + "먹음" 카운트.
    func eat(_ ingredient: Ingredient) {
        ateCount += 1
        history.insert(RemovalLog(name: ingredient.name, glyph: ingredient.glyph, daysAgo: 0, wasted: false), at: 0)
        remove(ingredient)
    }
    /// 버림 — 보유에서 빼고 이력 기록 + "버림" 카운트.
    func toss(_ ingredient: Ingredient) {
        tossedCount += 1
        history.insert(RemovalLog(name: ingredient.name, glyph: ingredient.glyph, daysAgo: 0, wasted: true), at: 0)
        remove(ingredient)
    }

    /// 낭비율(%) — 버림 / (먹음 + 버림).
    var wasteRate: Int {
        let total = ateCount + tossedCount
        guard total > 0 else { return 0 }
        return Int((Double(tossedCount) / Double(total) * 100).rounded())
    }

    // MARK: - 사야 할 식재료(쇼핑 리스트)

    /// "이번엔 안 살" 항목 — toBuy에서 제외.
    var dismissedToBuy: Set<String> = []

    /// 자주 쓰는데(이력에 있는데) 지금 냉장고엔 없는 = 사야 할 식재료. 빈도 많은 순.
    var toBuy: [(name: String, glyph: FoodGlyph)] {
        let inStock = Set(ingredients.map { $0.name })
        let grouped = Dictionary(grouping: history) { $0.name }
        return grouped
            .filter { !inStock.contains($0.key) && !dismissedToBuy.contains($0.key) }
            .map { (name: $0.key, glyph: $0.value.first!.glyph, count: $0.value.count) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.name < $1.name }
            .map { (name: $0.name, glyph: $0.glyph) }
    }

    /// 이번엔 안 사기 — 쇼핑 리스트에서 제외.
    func skipBuy(_ name: String) { dismissedToBuy.insert(name) }
}
