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
        // 저장된 캐논 ID를 fast path로(해석 완료 재료) — nil이면 사전 조회(캐시)로 폴백.
        let ingID = ing.canonicalID ?? IngredientLexicon.shared.canonicalID(for: ing.name)
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
    /// `preferences`(프로필 취향, §5.2)가 주어지면 알레르기 하드 필터 + 선호/기피/요리스타일 보정을
    /// 적용한다. 기본 `.none`은 순수 freshness 랭킹(기존 호출·테스트 후방호환).
    static func rank(for ingredients: [Ingredient], inventory: [Ingredient]? = nil,
                     from recipes: [Recipe],
                     preferences: RecipePreferences = .none) -> [Result] {
        recipes
            .filter { recipe in
                !containsAllergen(recipe, preferences.allergenIDs)   // 알레르기 하드 필터(안전 P0)
                    && !(preferences.vegetarian && containsAnimalProtein(recipe))   // 채식 하드 필터
            }
            .map { result(for: $0, ingredients: ingredients, inventory: inventory) }
            .filter { !$0.used.isEmpty }
            .sorted { a, b in
                let sa = score(a, preferences: preferences)
                let sb = score(b, preferences: preferences)
                if sa != sb { return sa > sb }
                if a.urgentUsedCount != b.urgentUsedCount { return a.urgentUsedCount > b.urgentUsedCount }
                return a.missing.count < b.missing.count
            }
    }

    // MARK: - 취향 반영(§5.2 프로필 선호 → 랭킹 실배선)

    // 튜닝 상수(§근거) — freshness 합(urgent3/soon2/fresh1)이 1차 기준이고, 아래 보정은 그 합에
    // 더해진다. 크기를 freshness 가중치대(1~3)와 같은 급으로 잡아, 취향이 순위를 '기울이되'
    // 임박도를 뒤엎지 않게 한다(예: 여러 재료가 임박한 레시피는 취향과 무관하게 여전히 위).
    /// 선호 요리 스타일 일치 — 재료 한 개 임박(soon)만큼의 가점.
    static let cuisineBonus = 2
    /// 좋아하는 재료(used에 실제로 있는) 한 개당 가점과 상한(과대 편향 방지).
    static let favoriteBonusPerItem = 1
    static let favoriteBonusCap = 3
    /// 싫어하는 재료(레시피에 포함) 한 개당 감점과 하한(한 레시피가 무한정 내려가지 않게).
    static let dislikedPenaltyPerItem = -2
    static let dislikedPenaltyFloor = -6

    /// 정렬 점수 — freshness 합(1차 기준) + 취향 보정. `.none`이면 보정 0이라 순수 freshness.
    private static func score(_ result: Result, preferences: RecipePreferences) -> Int {
        result.used.reduce(0) { $0 + weight($1) } + preferenceScore(for: result, preferences: preferences)
    }

    /// 취향 보정 점수 — cuisine 가점 + favorites 가점(used 기준) + disliked 감점(레시피 전체 재료 기준).
    static func preferenceScore(for result: Result, preferences p: RecipePreferences) -> Int {
        guard !p.isEmpty else { return 0 }
        var score = 0
        // ① 선호 요리 스타일 — recipe.cuisine(시드 cuisine 문자열, seedCuisines 매핑 후) 비교.
        if let cuisine = result.recipe.cuisine, p.cuisines.contains(cuisine) {
            score += cuisineBonus
        }
        // ② favorites — 보유하고 이 레시피가 쓰는(used) 재료 중 좋아하는 것(matchKey 기준). 상한 적용.
        if !p.favoriteIDs.isEmpty {
            let favs = result.used.reduce(0) { $0 + (p.favoriteIDs.contains($1.matchKey) ? 1 : 0) }
            score += min(favs * favoriteBonusPerItem, favoriteBonusCap)
        }
        // ③ disliked — 레시피 재료(전체) 중 싫어하는 항목 수만큼 감점. 하한 적용.
        if !p.dislikedIDs.isEmpty {
            let dis = result.recipe.ingredients.reduce(0) { $0 + (item($1, matchesAny: p.dislikedIDs) ? 1 : 0) }
            score += max(dis * dislikedPenaltyPerItem, dislikedPenaltyFloor)
        }
        return score
    }

    /// 알레르기 하드 필터 — 레시피 재료 중 하나라도 알레르겐이면 레시피 전체를 제외한다.
    /// **상비재 예외 없음**(알레르기는 상비재도 거른다 — 안전 함의).
    /// 한계: `canonicalID(of:)`/exact 비교에 기대므로, "chicken or vegetable stock" 같은 서술형
    /// no-ref 라인에 알레르겐이 **부분 포함**되면 검사할 수 없다(포함 매칭은 오탐 위험이라 안 씀).
    private static func containsAllergen(_ recipe: Recipe, _ allergenIDs: Set<String>) -> Bool {
        guard !allergenIDs.isEmpty else { return false }
        return recipe.ingredients.contains { item($0, matchesAny: allergenIDs) }
    }

    /// 채식 하드 필터가 배제하는 글리프 — Meat(meat·poultry·sausage·bacon) + Seafood(fish·shrimp·
    /// crab·squid·clam) 카테고리(`FoodGlyph.categoryLabel` 기준). 계란·유제품은 통과(락토오보 채식).
    private static let animalGlyphs: Set<FoodGlyph> = [.meat, .poultry, .sausage, .bacon,
                                                       .fish, .shrimp, .crab, .squid, .clam]

    /// 채식(§5.2 vegetarian 옵션) 하드 필터 — 비상비(non-staple) 재료 중 사전 글리프가
    /// Meat/Seafood 계열이면 레시피 전체 제외. canonical ID로 판별할 수 없는 항목(서술형 no-ref
    /// 라인 등)은 **통과**시킨다 — 보수성보다 가용성(판별 불가 라인 때문에 추천 풀이 말라붙지 않게).
    private static func containsAnimalProtein(_ recipe: Recipe) -> Bool {
        recipe.ingredients.contains { item in
            guard !isStaple(item),
                  let id = canonicalID(of: item),
                  let raw = IngredientLexicon.shared.entry(id: id)?.glyph,
                  let glyph = FoodGlyph(rawValue: raw) else { return false }
            return animalGlyphs.contains(glyph)
        }
    }

    /// 레시피 항목이 정규화 키 집합에 속하는지 — canonicalID 우선, no-ref 항목은 exact 텍스트(소문자).
    /// (`RecipePreferences`의 no-ref 태그 소문자 원문 보관 규칙과 대칭 — 표기 무관 비교가 산다.)
    private static func item(_ item: Recipe.Item, matchesAny ids: Set<String>) -> Bool {
        if let id = canonicalID(of: item) { return ids.contains(id) }
        if ids.contains(norm(item.en)) { return true }
        if let ko = item.ko, ids.contains(norm(ko)) { return true }
        return false
    }
}

/// 프로필 취향(§5.2)을 레시피 랭킹에 반영하기 위한 값 타입.
/// 재료 태그(favorites/disliked/allergies)는 `IngredientLexicon.canonicalID`로 정규화해
/// 한/영 표기 무관 매칭한다. 사전 밖(커스텀) 태그는 정규화 실패 시 **소문자 원문**을 보관해,
/// ref 없는 레시피 항목의 exact 텍스트 비교(`canonicalID(of:)`와 대칭)에도 쓴다.
struct RecipePreferences {
    /// 선호 요리 스타일 — **시드 cuisine 문자열**(`seedCuisines` 매핑을 거친) 집합.
    /// `Recipe.cuisine`과 직접 비교하므로, 프로필 옵션(CuisineStyle)이 아니라 시드 taxonomy가 단위다.
    var cuisines: Set<String>
    /// 좋아하는 재료(canonical ID, 실패 시 소문자 원문) — used에 있으면 가점.
    var favoriteIDs: Set<String>
    /// 싫어하는 재료 — 레시피에 포함되면 감점.
    var dislikedIDs: Set<String>
    /// 알레르겐 — 하드 필터의 근거(안전 P0). 상비재도 예외 없이 거른다.
    var allergenIDs: Set<String>
    /// 채식(§5.2 vegetarian 옵션) — cuisine 가점이 아니라 **식이 하드 필터**로 승격
    /// (Meat/Seafood 글리프 재료를 쓰는 레시피 제외 — 가점으로는 실동작을 못 만든다).
    var vegetarian: Bool = false

    /// 취향 미적용(기본) — 랭킹은 순수 freshness. 후방호환 회귀의 기준.
    static let none = RecipePreferences(cuisines: [], favoriteIDs: [],
                                        dislikedIDs: [], allergenIDs: [])

    /// 보정할 취향이 하나도 없으면 점수 계산을 건너뛴다(=.none 후방호환).
    var isEmpty: Bool {
        cuisines.isEmpty && favoriteIDs.isEmpty && dislikedIDs.isEmpty
            && allergenIDs.isEmpty && !vegetarian
    }

    /// 재료 태그 목록 → 정규화 키 집합. 사전 매칭 성공 시 canonical ID, 실패 시 소문자 원문
    /// (`Ingredient.matchKey`·`canonicalID(of:)`의 no-ref 규칙과 대칭이라 표기 무관 비교가 산다).
    static func normalize(_ tags: [String]) -> Set<String> {
        let lex = IngredientLexicon.shared
        var out: Set<String> = []
        for tag in tags {
            let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            out.insert(lex.canonicalID(for: trimmed) ?? trimmed.lowercased())
        }
        return out
    }
}

extension RecipePreferences {
    /// 프로필 옵션(CuisineStyle) → 시드 cuisine 문자열 매핑. 시드 taxonomy(80레시피 기준:
    /// korean 22 · american 11 · italian 9 · japanese 7 · chinese 6 · french 6 · mexican 5 ·
    /// other 5 · indian 3 · thai 2 · vietnamese 2 · middle-eastern 2)와 프로필 옵션이 1:1이
    /// 아니라서: western은 미국·프랑스(향후 spanish 포함) 계열로, mediterranean은 이탈리아·
    /// 스페인·중동 계열로 넓혀 가점이 실제로 발화하게 한다(위약 옵션 금지 — MVP 원칙).
    /// 겹치는 8종(korean 등)은 동일 문자열 그대로. vegetarian은 cuisine이 아니라 식이 필터.
    static let seedCuisines: [CuisineStyle: Set<String>] = [
        .korean:        ["korean"],
        .japanese:      ["japanese"],
        .chinese:       ["chinese"],
        .italian:       ["italian"],
        .mexican:       ["mexican"],
        .indian:        ["indian"],
        .thai:          ["thai"],
        .vietnamese:    ["vietnamese"],
        .western:       ["american", "french", "spanish"],
        .mediterranean: ["italian", "spanish", "middle-eastern"],
    ]

    /// 프로필(§5.2)에서 취향 스냅샷을 만든다 — cuisines는 시드 매핑을 거친 문자열 집합,
    /// vegetarian 선택은 식이 하드 필터 플래그로 승격, 재료 태그는 정규화 키.
    init(profile: ProfileStore) {
        var cuisines: Set<String> = []
        for c in profile.cuisines where c != .vegetarian {
            cuisines.formUnion(Self.seedCuisines[c] ?? [c.rawValue])
        }
        self.init(cuisines: cuisines,
                  favoriteIDs: Self.normalize(profile.favorites),
                  dislikedIDs: Self.normalize(profile.disliked),
                  allergenIDs: Self.normalize(profile.allergies),
                  vegetarian: profile.cuisines.contains(.vegetarian))
    }
}
