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

    // MARK: 타이핑 검색 (To buy 직접 담기 시트)

    @Test func searchRanksPrefixAboveContains() {
        // "onion" — 양파(이름 자체가 prefix)가 대파("green onion", 포함)보다 앞.
        let ids = lex.search(query: "onion").map(\.id)
        #expect(ids.first == "onion")
        #expect(ids.contains("green-onion"))
    }

    @Test func searchRanksShorterNameFirstWithinPrefixHits() throws {
        // 같은 prefix 적중이면 쿼리를 더 꽉 채운(짧은) 이름이 먼저 — "배" → 배 > 배추 > 배추김치.
        let ids = lex.search(query: "배").map(\.id)
        #expect(ids.first == "pear")
        let napa = try #require(ids.firstIndex(of: "napa-cabbage"))
        let kimchi = try #require(ids.firstIndex(of: "kimchi"))
        #expect(napa < kimchi)
    }

    @Test func singleCharQueryMatchesPrefixOnly() {
        // 한 글자가 이름 안쪽에까지 걸리면 목록이 무의미해진다 — "양배추"(배가 중간)는 안 뜬다.
        let ids = lex.search(query: "배").map(\.id)
        #expect(!ids.contains("cabbage"))
        #expect(!ids.contains("brussels-sprout"))
        // 두 글자부터는 포함 매칭이 살아난다 — "양배추" → 양배추(prefix) + 방울양배추(포함).
        let two = lex.search(query: "양배추").map(\.id)
        #expect(two.first == "cabbage")
        #expect(two.contains("brussels-sprout"))
    }

    @Test func searchIsCappedAndEmptyForBlankQuery() {
        #expect(lex.search(query: "s").count == 20)        // 기본 상한
        #expect(lex.search(query: "s", limit: 3).count == 3)
        #expect(lex.search(query: "   ").isEmpty)          // 공백만 = 검색 아님
        #expect(lex.search(query: "zzz").isEmpty)
    }

    @Test func searchLimit60CoversToBuySearchSheetPath() {
        // `ToBuySearchSheet`가 실제로 넘기는 상한(60) — 기본값(20)만 덮던 공백. 쿼리 "c"는 (en+ko
        // prefix·contains 합쳐) 47개 항목에 걸린다 — 기본 상한(20)에서는 잘리지만, 60을 넘기면 커스텀
        // limit이 실제로 관철돼 전부(< 60) 담긴다. 정확히 60개를 채우는 단일 쿼리는 사전 223종 규모에서
        // 존재하지 않는다(브루트포스로 확인 — 최댓값이 47) — 그래서 "상한이 넘어간다"가 아니라
        // "커스텀 limit이 기본값 대신 적용된다"를 검증축으로 삼는다.
        #expect(lex.search(query: "c").count == 20)              // 기본 상한(20)에 잘림
        #expect(lex.search(query: "c", limit: 60).count == 47)   // 커스텀 60에선 전부 담김(자연 히트 < 60)
    }

    // MARK: 카테고리 섹션 (To buy 검색 시트의 재료 배열)

    @Test func categorySectionsCoverEveryEntryExactlyOnce() {
        // 섹션 그리드가 사전의 단일 뷰라는 계약 — 한 항목이 빠지면 UI에서 영영 도달 불가해지고,
        // 두 번 들어가면 같은 재료가 두 칸으로 뜬다.
        let sectioned = lex.categorySections.flatMap { $0.entries.map(\.id) }
        #expect(sectioned.count == lex.entries.count)
        #expect(Set(sectioned) == Set(lex.entries.map(\.id)))
    }

    @Test func categorySectionsFollowFixedOrderAndSkipEmpty() {
        let cats = lex.categorySections.map(\.category)
        #expect(!cats.isEmpty)
        // 순서는 `FoodGlyph.categoryOrder`(냉장고 필터 칩과 공유)의 부분 수열이어야 한다 — 항목 없는 카테고리만 빠지고, 남은 것들의
        // 상대 순서는 선언 순서 그대로다(빈 섹션 헤더도, 뒤죽박죽 순서도 안 된다).
        #expect(cats == FoodGlyph.categoryOrder.filter { cats.contains($0) })
        #expect(cats.first == "Veg")   // 사전에 채소가 없을 리 없다
    }

    @Test func categorySectionsGroupByGlyphCategoryAndSortByName() throws {
        for section in lex.categorySections {
            for entry in section.entries {
                let glyph = try #require(FoodGlyph(rawValue: entry.glyph))
                #expect(glyph.categoryLabel == section.category)
            }
            // 인접 쌍만 본다 — 동명이인(같은 표기)이 있으면 `sorted`와의 전량 비교는 불안정하다.
            let names = section.entries.map(\.displayName)
            for (a, b) in zip(names, names.dropFirst()) {
                #expect(a.localizedStandardCompare(b) != .orderedDescending,
                        "\(section.category): '\(a)' before '\(b)'")
            }
        }
        // 대표 샘플 — 분류 축이 글리프라는 사실이 바뀌면 여기가 먼저 깨진다.
        let veg = try #require(lex.categorySections.first { $0.category == "Veg" })
        #expect(veg.entries.contains { $0.id == "onion" })
        let dairy = try #require(lex.categorySections.first { $0.category == "Dairy" })
        #expect(dairy.entries.contains { $0.id == "milk" })
        #expect(!dairy.entries.contains { $0.id == "onion" })
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

    // MARK: 커버리지 점검 — 덱이 못 다룬 오늘 만료 재료(영상 브리지의 판별 근거)

    @Test func uncoveredUrgentSkipsIngredientsSomeTicketUses() {
        // 티켓이 실제로 쓰는 urgent 재료는 미커버가 아니다 — 덱이 이미 답을 주고 있다.
        let r = recipe(id: "beef-dish", refs: ["beef"], en: ["beef"])
        let stock = [ing("소고기", daysLeft: 0)]
        let results = RecipeRecommender.rank(for: stock, from: [r])
        #expect(results.count == 1)
        #expect(RecipeRecommender.uncoveredUrgent(ingredients: stock, results: results).isEmpty)
    }

    @Test func uncoveredUrgentReportsIngredientNoTicketUses() {
        // 덱은 살아 있는데(소고기 티켓) 오늘 만료 두부는 어느 티켓에도 없다 — 배너만 압박하고
        // 티켓은 침묵하는 그 상태가 정확히 브리지 행이 말해야 하는 것이다.
        let r = recipe(id: "beef-dish", refs: ["beef"], en: ["beef"])
        let beef = ing("소고기", daysLeft: 0)
        let tofu = ing("두부", daysLeft: 0)
        let results = RecipeRecommender.rank(for: [beef, tofu], from: [r])
        let uncovered = RecipeRecommender.uncoveredUrgent(ingredients: [beef, tofu], results: results)
        #expect(uncovered.map(\.name) == ["두부"])
    }

    @Test func uncoveredUrgentExcludesFreshAndSoon() {
        // urgent만 호명한다 — soon·fresh까지 세면 브리지 행이 상시 표시돼 경고가 배경이 된다.
        let r = recipe(id: "beef-dish", refs: ["beef"], en: ["beef"])
        let stock = [ing("소고기", daysLeft: 0), ing("당근", daysLeft: 2), ing("감자", daysLeft: 9)]
        let results = RecipeRecommender.rank(for: stock, from: [r])
        #expect(RecipeRecommender.uncoveredUrgent(ingredients: stock, results: results).isEmpty)
    }

    @Test func uncoveredUrgentReportsEverythingWhenDeckIsEmpty() {
        // 극단(덱 0장) — 모든 urgent가 미커버다. 순서는 입력(마감 임박순) 그대로 유지된다.
        let stock = [ing("두부", daysLeft: 0), ing("계란", daysLeft: -1), ing("당근", daysLeft: 5)]
        let uncovered = RecipeRecommender.uncoveredUrgent(ingredients: stock, results: [])
        #expect(uncovered.map(\.name) == ["두부", "계란"])
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

    // MARK: - 프로필 취향 반영(§5.2 선호 → 랭킹 실배선)

    /// 스토어 로드처럼 canonicalID를 해석해 둔 재료(matchKey가 캐논 키가 되게).
    private func resolvedIng(_ name: String, daysLeft: Int = 9) -> Ingredient {
        var i = ing(name, daysLeft: daysLeft)
        i.canonicalID = IngredientLexicon.shared.canonicalID(for: name)
        return i
    }

    private func prefs(cuisines: Set<String> = [], favorites: [String] = [],
                       disliked: [String] = [], allergies: [String] = []) -> RecipePreferences {
        RecipePreferences(cuisines: cuisines,
                          favoriteIDs: RecipePreferences.normalize(favorites),
                          dislikedIDs: RecipePreferences.normalize(disliked),
                          allergenIDs: RecipePreferences.normalize(allergies))
    }

    @Test func koreanTagNormalizesToCanonicalID() {
        // 한국어 태그도 canonical ID로 정규화("새우"→shrimp) — 매칭·필터가 표기 무관.
        #expect(RecipePreferences.normalize(["새우"]).contains("shrimp"))
        #expect(RecipePreferences.normalize(["Shrimp"]).contains("shrimp"))
        // 사전 밖 커스텀 태그는 소문자 원문 보관(no-ref exact 비교용).
        #expect(RecipePreferences.normalize(["My Secret Sauce"]).contains("my secret sauce"))
    }

    @Test func allergenHardFilterExcludesRecipe() {
        // 새우(shrimp) 알레르기 → 새우를 쓰는 레시피는 순위에서 통째로 빠진다(안전 P0).
        let shrimpDish = recipe(id: "shrimp-dish", refs: ["shrimp"], en: ["shrimp"])
        let safeDish = recipe(id: "carrot-dish", refs: ["carrot"], en: ["carrot"])
        let stock = [resolvedIng("새우", daysLeft: 1), resolvedIng("당근", daysLeft: 1)]
        let ranked = RecipeRecommender.rank(for: stock, from: [shrimpDish, safeDish],
                                            preferences: prefs(allergies: ["새우"]))
        #expect(!ranked.contains { $0.id == "shrimp-dish" })
        #expect(ranked.contains { $0.id == "carrot-dish" })
    }

    @Test func stapleAllergenIsAlsoFiltered() {
        // 간장(soy-sauce)은 상비재지만 알레르기는 상비재도 거른다(예외 없음).
        #expect(RecipeRecommender.isStaple(Recipe.Item(ref: "soy-sauce", en: "soy sauce", ko: nil)))
        let soyDish = recipe(id: "soy-dish", refs: ["beef", "soy-sauce"], en: ["beef", "soy sauce"])
        let plainDish = recipe(id: "plain-dish", refs: ["beef"], en: ["beef"])
        let stock = [resolvedIng("소고기", daysLeft: 1)]
        let ranked = RecipeRecommender.rank(for: stock, from: [soyDish, plainDish],
                                            preferences: prefs(allergies: ["간장"]))
        #expect(!ranked.contains { $0.id == "soy-dish" })   // 상비재 간장 때문에 제외
        #expect(ranked.contains { $0.id == "plain-dish" })
    }

    @Test func dislikedPenaltyReordersRanking() {
        // beef urgent(3) > carrot soon(2): 무취향이면 beefDish 먼저.
        let carrotDish = recipe(id: "carrot-dish", refs: ["carrot"], en: ["carrot"])
        let beefDish = recipe(id: "beef-dish", refs: ["beef"], en: ["beef"])
        let stock = [resolvedIng("당근", daysLeft: 1), resolvedIng("소고기", daysLeft: 0)]
        #expect(RecipeRecommender.rank(for: stock, from: [carrotDish, beefDish]).first?.id == "beef-dish")
        // 소고기 기피(-2) → beefDish 3-2=1 < carrotDish 2 → 역전.
        let ranked = RecipeRecommender.rank(for: stock, from: [carrotDish, beefDish],
                                            preferences: prefs(disliked: ["소고기"]))
        #expect(ranked.first?.id == "carrot-dish")
    }

    @Test func favoriteBonusRaisesRanking() {
        // rF(당근·계란, fresh) base 2 vs rO(소고기·양파·새우, fresh) base 3 → 무취향이면 rO 먼저.
        let rF = recipe(id: "fav-dish", refs: ["carrot", "egg"], en: ["carrot", "egg"])
        let rO = recipe(id: "other-dish", refs: ["beef", "onion", "shrimp"],
                        en: ["beef", "onion", "shrimp"])
        let stock = [resolvedIng("당근"), resolvedIng("계란"), resolvedIng("소고기"),
                     resolvedIng("양파"), resolvedIng("새우")]
        #expect(RecipeRecommender.rank(for: stock, from: [rF, rO]).first?.id == "other-dish")
        // 당근·계란 선호(+2) → rF 4 > rO 3 → 역전.
        let ranked = RecipeRecommender.rank(for: stock, from: [rF, rO],
                                            preferences: prefs(favorites: ["당근", "계란"]))
        #expect(ranked.first?.id == "fav-dish")
    }

    @Test func cuisineBonusRaisesRanking() {
        let korean = Recipe(id: "kr-dish", name: .init(en: "kr", ko: nil), cuisine: "korean",
                            minutes: 10, ingredients: [.init(ref: "carrot", en: "carrot", ko: nil)],
                            steps: .init(en: ["step"], ko: nil), isUser: nil)
        let american = Recipe(id: "us-dish", name: .init(en: "us", ko: nil), cuisine: "american",
                              minutes: 10, ingredients: [.init(ref: "beef", en: "beef", ko: nil)],
                              steps: .init(en: ["step"], ko: nil), isUser: nil)
        // beef urgent(3) > carrot soon(2): 무취향이면 미국식(beef) 먼저.
        let stock = [resolvedIng("당근", daysLeft: 3), resolvedIng("소고기", daysLeft: 0)]
        #expect(RecipeRecommender.rank(for: stock, from: [korean, american]).first?.id == "us-dish")
        // 한식 선호(+2) → korean 2+2=4 > american 3 → 역전.
        let ranked = RecipeRecommender.rank(for: stock, from: [korean, american],
                                            preferences: prefs(cuisines: ["korean"]))
        #expect(ranked.first?.id == "kr-dish")
    }

    /// 프로필 팩토리 경로 테스트용 — 임시 UserDefaults 스위트에 저장값을 심고 ProfileStore를 만든다.
    private func profileStore(cuisines: [String], suite suiteName: String) -> ProfileStore {
        let suite = UserDefaults(suiteName: suiteName)!
        suite.removePersistentDomain(forName: suiteName)
        suite.set(cuisines, forKey: "profile.cuisines")
        return ProfileStore(defaults: suite)
    }

    @Test func westernMappingBonusFires() {
        // 프로필 western → 시드 taxonomy(american·french·spanish)로 매핑돼 가점이 실제 발화한다.
        let p = RecipePreferences(profile: profileStore(cuisines: ["western"],
                                                        suite: "test.profile.western"))
        #expect(p.cuisines.isSuperset(of: ["american", "french", "spanish"]))
        let american = Recipe(id: "us-dish", name: .init(en: "us", ko: nil), cuisine: "american",
                              minutes: 10, ingredients: [.init(ref: "carrot", en: "carrot", ko: nil)],
                              steps: .init(en: ["step"], ko: nil), isUser: nil)
        let korean = Recipe(id: "kr-dish", name: .init(en: "kr", ko: nil), cuisine: "korean",
                            minutes: 10, ingredients: [.init(ref: "beef", en: "beef", ko: nil)],
                            steps: .init(en: ["step"], ko: nil), isUser: nil)
        // beef urgent(3) > carrot soon(2): 무취향이면 한식(beef) 먼저 → western 가점(+2)으로 역전.
        let stock = [resolvedIng("당근", daysLeft: 3), resolvedIng("소고기", daysLeft: 0)]
        #expect(RecipeRecommender.rank(for: stock, from: [american, korean]).first?.id == "kr-dish")
        let ranked = RecipeRecommender.rank(for: stock, from: [american, korean], preferences: p)
        #expect(ranked.first?.id == "us-dish")
        UserDefaults(suiteName: "test.profile.western")?.removePersistentDomain(forName: "test.profile.western")
    }

    @Test func vegetarianFiltersMeatAndSeafoodRecipes() {
        // vegetarian 선택 → cuisine 가점이 아니라 식이 하드 필터로 승격.
        let p = RecipePreferences(profile: profileStore(cuisines: ["vegetarian"],
                                                        suite: "test.profile.veg"))
        #expect(p.vegetarian)
        #expect(p.cuisines.isEmpty)   // cuisine 집합엔 들어가지 않는다
        let beefDish = recipe(id: "beef-dish", refs: ["beef"], en: ["beef"])
        let shrimpDish = recipe(id: "shrimp-dish", refs: ["shrimp"], en: ["shrimp"])
        let vegDish = recipe(id: "veg-dish", refs: ["carrot", "tofu"], en: ["carrot", "tofu"])
        let stock = [resolvedIng("소고기"), resolvedIng("새우"),
                     resolvedIng("당근"), resolvedIng("두부")]
        let ranked = RecipeRecommender.rank(for: stock, from: [beefDish, shrimpDish, vegDish],
                                            preferences: p)
        #expect(ranked.map(\.id) == ["veg-dish"])   // 고기·해산물 제외, 채소는 통과
        UserDefaults(suiteName: "test.profile.veg")?.removePersistentDomain(forName: "test.profile.veg")
    }

    @Test func legacyBrazilianRawValueDecodesSafely() {
        // 케이스 삭제된 brazilian이 저장값에 남아 있어도 compactMap이 무시(안전 디코드) —
        // 크래시·데이터 오염 없이 나머지 선택만 복원된다.
        let store = profileStore(cuisines: ["brazilian", "korean"], suite: "test.profile.brazilian")
        #expect(store.cuisines == [.korean])
        UserDefaults(suiteName: "test.profile.brazilian")?.removePersistentDomain(forName: "test.profile.brazilian")
    }

    @Test func nonePreferencesMatchesBaseline() {
        // preferences == .none → 기존 순위와 완전 동일(후방호환 회귀).
        let a = recipe(id: "a", refs: ["beef"], en: ["beef"])
        let b = recipe(id: "b", refs: ["carrot", "onion"], en: ["carrot", "onion"])
        let c = recipe(id: "c", refs: ["egg"], en: ["egg"])
        let stock = [resolvedIng("소고기", daysLeft: 0), resolvedIng("당근", daysLeft: 2),
                     resolvedIng("양파", daysLeft: 3), resolvedIng("계란", daysLeft: 9)]
        let base = RecipeRecommender.rank(for: stock, from: [a, b, c])
        let withNone = RecipeRecommender.rank(for: stock, from: [a, b, c], preferences: .none)
        #expect(base.map(\.id) == withNone.map(\.id))
    }
}

/// 표시 캐논화 — 저장 스키마(name)는 그대로 두고 표시만 사전에서 다시 읽는지.
struct DisplayNameTests {

    @Test func canonicalIDWinsOverStoredName() {
        let ing = Ingredient(name: "연두부라고 저장된 옛 표기", category: "Veg",
                             expiresAt: Date(), canonicalID: "egg")
        let expected = IngredientLexicon.shared.entry(id: "egg")?.displayName
        #expect(ing.displayName == expected)
    }

    @Test func freeTextKeepsStoredName() {
        let ing = Ingredient(name: "할머니표 장아찌", category: "Other", expiresAt: Date())
        #expect(ing.displayName == "할머니표 장아찌")
    }

    @Test func removalLogFollowsSameRule() {
        let log = RemovalLog(name: "old label", glyph: .milk, canonicalID: "milk",
                             removedAt: Date(), wasted: false)
        #expect(log.displayName == IngredientLexicon.shared.entry(id: "milk")?.displayName)
        let free = RemovalLog(name: "직접 만든 잼", glyph: .generic, removedAt: Date(), wasted: true)
        #expect(free.displayName == "직접 만든 잼")
    }
}
