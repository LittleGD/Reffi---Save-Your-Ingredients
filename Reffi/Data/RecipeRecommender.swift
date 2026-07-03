import Foundation

/// 레시피 추천 — "지금 가장 빠르게 소비해야 하는 재료들을 가장 많이 쓰는" 레시피를 점수순으로.
/// 임박할수록 큰 가중치(urgent3/soon2/fresh1). 스와이프 덱은 이 순서대로 위→아래.
///
/// 매칭은 정본 재료 사전(`IngredientLexicon`)의 **canonical ID 동일성**이 원칙이다 —
/// 양방향 부분문자열 비교(Green onion↔Onion, Pineapple↔Apple 오탐)는 쓰지 않는다.
/// 발주가 곧 재고 소비이므로 매칭 오탐은 데이터 파괴다.
enum RecipeRecommender {

    struct Result: Identifiable {
        let id: String               // = recipe.id (안정적 정체성)
        var recipe: Recipe
        var used: [Ingredient]       // 보유 재료 중 이 레시피가 쓰는 것(임박 순)
        var total: Int               // 비-상비 재료 수(매치 분모)
        var missing: [String]        // 비-상비 중 미보유(표시명)
        var urgentUsedCount: Int     // 그중 오늘(urgent) 소진되는 수
    }

    /// 정규화 — 트림 + 소문자.
    private static func norm(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// 레시피 재료 한 줄의 canonical ID — ref 우선. ref 없는(no-ref) 표기는 **정확 일치**만
    /// 역조회한다 — "chicken or vegetable stock" 같은 서술형 라인이 포함 매칭으로 chicken에
    /// 오매핑되어 발주가 엉뚱한 재고를 소비하는 것을 막는다(포함 매칭은 재료명 쪽에만 허용).
    static func canonicalID(of item: Recipe.Item) -> String? {
        if let ref = item.ref { return ref }
        let lex = IngredientLexicon.shared
        return lex.exactCanonicalID(for: item.en) ?? item.ko.flatMap { lex.exactCanonicalID(for: $0) }
    }

    /// 상비재 판별 — 사전의 staple 플래그가 정본.
    static func isStaple(_ item: Recipe.Item) -> Bool {
        if let id = canonicalID(of: item) { return IngredientLexicon.shared.isStaple(id) }
        return false
    }

    /// 재료 ↔ 레시피 항목 매칭 — ① canonical ID 동일성 ② (사전 밖 커스텀 항목만) 정규화 정확 일치.
    static func matches(_ ing: Ingredient, _ item: Recipe.Item) -> Bool {
        let ingName = norm(ing.name)
        guard !ingName.isEmpty else { return false }
        let ingID = IngredientLexicon.shared.canonicalID(for: ing.name)
        let itemID = canonicalID(of: item)
        if let a = ingID, let b = itemID { return a == b }
        // 둘 중 하나라도 사전 밖(사용자 커스텀 표기) — 정확 일치만 허용, 부분문자열 금지.
        if ingName == norm(item.en) { return true }
        if let ko = item.ko, ingName == norm(ko) { return true }
        return false
    }

    static func weight(_ ing: Ingredient) -> Int {
        switch ing.freshness {
        case .urgent: 3
        case .soon:   2
        case .fresh:  1
        }
    }

    /// `ingredients` = 티켓이 소비할 후보, `inventory` = 부족(missing) 판정 기준(전체 재고).
    /// inventory를 따로 주지 않으면 ingredients가 기준.
    static func result(for recipe: Recipe, ingredients: [Ingredient],
                       inventory: [Ingredient]? = nil) -> Result {
        let nonStaple = recipe.ingredients.filter { !isStaple($0) }
        let used = ingredients
            .filter { ing in nonStaple.contains { matches(ing, $0) } }
            .sorted { $0.effectiveDaysLeft < $1.effectiveDaysLeft }
        let stock = inventory ?? ingredients
        let missing = nonStaple
            .filter { item in !stock.contains { matches($0, item) } }
            .map(\.displayName)
        let urgent = used.filter { $0.freshness == .urgent }.count
        return Result(id: recipe.id, recipe: recipe, used: used,
                      total: nonStaple.count, missing: missing, urgentUsedCount: urgent)
    }

    /// 점수순 정렬된 추천 덱(보유 재료를 하나라도 쓰는 레시피만).
    static func rank(for ingredients: [Ingredient], inventory: [Ingredient]? = nil,
                     from recipes: [Recipe]) -> [Result] {
        recipes
            .map { result(for: $0, ingredients: ingredients, inventory: inventory) }
            .filter { !$0.used.isEmpty }
            .sorted { a, b in
                let sa = a.used.reduce(0) { $0 + weight($1) }
                let sb = b.used.reduce(0) { $0 + weight($1) }
                if sa != sb { return sa > sb }
                if a.urgentUsedCount != b.urgentUsedCount { return a.urgentUsedCount > b.urgentUsedCount }
                return a.missing.count < b.missing.count
            }
    }
}
