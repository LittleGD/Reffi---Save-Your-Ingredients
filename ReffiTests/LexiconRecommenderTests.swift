import Testing
import Foundation
@testable import Reffi

/// 정본 재료 사전 — 번들 로드·한/영 매칭·한 글자 규칙·기본 소비기한.
struct LexiconTests {
    private let lex = IngredientLexicon.shared

    @Test func bundleLoads() {
        #expect(lex.entries.count >= 200)
    }

    @Test func matchesKoreanAndEnglishNames() {
        #expect(lex.canonicalID(for: "달걀") == "egg")
        #expect(lex.canonicalID(for: "계란") == "egg")
        #expect(lex.canonicalID(for: "egg") == "egg")
        #expect(lex.canonicalID(for: "양파") == "onion")
    }

    @Test func longerKeywordWinsOverSubstring() {
        // 대파/쪽파는 green-onion — "onion"(양파)으로 오분류되면 발주가 엉뚱한 재료를 소비한다.
        #expect(lex.canonicalID(for: "대파") == "green-onion")
        #expect(lex.canonicalID(for: "green onion") == "green-onion")
        #expect(lex.canonicalID(for: "onion") == "onion")
    }

    @Test func containsMatchForCompoundNames() {
        // 영수증 축약 상품명("서울우유1L")도 포함 매칭으로 잡힌다 — OCR 경로의 전제.
        #expect(lex.canonicalID(for: "서울우유1L") == "milk")
    }

    @Test func staplesAreFlagged() {
        #expect(lex.isStaple("소금"))
        #expect(lex.isStaple("soy-sauce"))
        #expect(!lex.isStaple("beef"))
    }

    @Test func shelfLifeVariesByStorage() {
        let fridge = lex.shelfLifeDays(for: "소고기", storage: .fridge)
        let freezer = lex.shelfLifeDays(for: "소고기", storage: .freezer)
        #expect(fridge != nil && freezer != nil)
        #expect(freezer! > fridge!)   // 냉동이 냉장보다 길어야 정상
    }

    /// 신규 12종 글리프 재배정(§13.3 — corn·cucumber·pea·cabbage·chili·pumpkin·avocado·banana·
    /// noodles·rice·sauceBottle·can) 전수 검증. `GlyphTests`는 enum 자체의 계약만 보고 이쪽에서
    /// 미루기로 한 몫 — JSON의 `glyph` 문자열이 `FoodGlyph` rawValue 집합 밖으로 새면 픽커 그리드
    /// (일러스트 사전 픽커)가 조용히 `.generic`으로 무너진다. 디코드는 톨러런트해도 데이터 품질은 아니다.
    @Test func allEntryGlyphsAreValidFoodGlyphCases() {
        let validGlyphs = Set(FoodGlyph.allCases.map(\.rawValue))
        for entry in lex.entries {
            #expect(validGlyphs.contains(entry.glyph), "unknown glyph '\(entry.glyph)' for entry '\(entry.id)'")
        }
    }

    @Test func newGlyphsAreActuallyAssignedInLexicon() {
        // 재배정이 빠지면(예: 스크립트 재실행 실수) 픽커의 신규 종 타일이 전부 죽은 코드가 된다.
        let assigned = Set(lex.entries.map(\.glyph))
        for glyph in ["corn", "cucumber", "pea", "cabbage", "chili", "pumpkin",
                      "avocado", "banana", "noodles", "rice", "sauceBottle", "can"] {
            #expect(assigned.contains(glyph), "no lexicon entry uses new glyph '\(glyph)'")
        }
    }

    @Test func v2GlyphsAreActuallyAssignedInLexicon() {
        // v2 신규 17종도 사전에 실제 배정돼야 픽커 타일이 산다(seaweed는 미역·김·다시마 공용).
        let assigned = Set(lex.entries.map(\.glyph))
        for glyph in ["eggplant", "sweetPotato", "ginger", "seaweed",
                      "grape", "watermelon", "pineapple", "mango",
                      "sausage", "bacon", "crab", "squid", "clam",
                      "yogurt", "butter", "honey", "dumpling"] {
            #expect(assigned.contains(glyph), "no lexicon entry uses v2 glyph '\(glyph)'")
        }
    }
}

/// 추천 매칭 — canonical ID 동일성 원칙(부분문자열 오탐 금지)·랭킹.
struct RecommenderTests {

    private func recipe(id: String, refs: [String], en: [String]) -> Recipe {
        Recipe(id: id,
               name: Recipe.LocalizedName(en: id, ko: nil),
               cuisine: nil, minutes: 10,
               ingredients: zip(refs, en).map { Recipe.Item(ref: $0.0.isEmpty ? nil : $0.0, en: $0.1, ko: nil) },
               steps: Recipe.LocalizedSteps(en: ["step"], ko: nil),
               isUser: nil)
    }

    private func ing(_ name: String, daysLeft: Int = 3) -> Ingredient {
        Ingredient(name: name, category: "Veg", daysLeft: daysLeft,
                   quantity: Quantity(value: 1, unit: .piece), glyph: .generic)
    }

    @Test func noSubstringFalsePositives() {
        // 대파(green-onion)는 onion 항목에 매칭되면 안 된다 — 발주 = 재고 소비라 오탐은 데이터 파괴.
        let onionItem = Recipe.Item(ref: "onion", en: "onion", ko: nil)
        #expect(!RecipeRecommender.matches(ing("대파"), onionItem))
        #expect(RecipeRecommender.matches(ing("양파"), onionItem))
        // Pineapple ↔ Apple 유형의 교차 오탐도 차단.
        let appleItem = Recipe.Item(ref: "apple", en: "apple", ko: nil)
        #expect(!RecipeRecommender.matches(ing("pineapple"), appleItem))
    }

    @Test func urgencyWeightsRanking() {
        let r1 = recipe(id: "uses-urgent", refs: ["beef"], en: ["beef"])
        let r2 = recipe(id: "uses-fresh", refs: ["carrot"], en: ["carrot"])
        let stock = [ing("소고기", daysLeft: 0), ing("당근", daysLeft: 9)]
        let ranked = RecipeRecommender.rank(for: stock, from: [r2, r1])
        #expect(ranked.first?.id == "uses-urgent")   // urgent(3) > fresh(1)
    }

    @Test func staplesExcludedFromMissing() {
        let r = recipe(id: "soup", refs: ["beef", "salt"], en: ["beef", "salt"])
        let result = RecipeRecommender.result(for: r, ingredients: [ing("소고기", daysLeft: 1)])
        #expect(result.missing.isEmpty)   // salt는 상비재 — 부족으로 표기하지 않는다
        #expect(result.total == 1)
    }

    @Test func customTextMatchesExactOnly() {
        // 사전 밖 커스텀 표기는 정확 일치만 — 부분문자열 매칭 금지.
        let custom = Recipe.Item(ref: nil, en: "homemade chili paste", ko: nil)
        #expect(!RecipeRecommender.matches(ing("chili"), custom))
        #expect(RecipeRecommender.matches(ing("homemade chili paste"), custom))
    }

    @Test func noRefDescriptiveLineNeverContainsMatches() {
        // 시드의 no-ref 서술형 라인("chicken or vegetable stock")이 포함 매칭으로
        // chicken에 붙으면 발주가 실재고 닭고기를 소비한다 — 정확 일치만 허용해야 한다.
        let stock = Recipe.Item(ref: nil, en: "chicken or vegetable stock (kept warm)", ko: nil)
        #expect(RecipeRecommender.canonicalID(of: stock) == nil)
        #expect(!RecipeRecommender.matches(ing("chicken"), stock))
        #expect(!RecipeRecommender.matches(ing("닭고기"), stock))
        // ref가 있으면 그대로 신뢰.
        let chicken = Recipe.Item(ref: "chicken", en: "chicken thigh", ko: nil)
        #expect(RecipeRecommender.matches(ing("닭고기"), chicken))
    }
}
