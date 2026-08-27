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

    /// **동률 최종 타이브레이크는 표시 이름의 로케일 알파벳순**이어야 한다(30차) — 내부 캐논 id는 항상
    /// 영문 슬러그라, id 오름차순으로 동률을 가르면 한국어 로케일에서 사용자가 보는 순서와 어긋난다.
    ///
    /// "고기" 포함 매칭에서 rank(1)·length(3)이 정확히 겹치는 동률 집합이 소고기(beef)·닭고기(chicken)·
    /// 양고기(lamb) 셋이다(`돼지고기`·`오리고기`는 length 4라 별도 동률 그룹 — 여기 대상이 아니다).
    @Test func searchBreaksRankAndLengthTiesByLocalizedDisplayNameOrder() {
        let tieIDs: Set<String> = ["beef", "chicken", "lamb"]
        let hits = lex.search(query: "고기", limit: 60)
        let tied = hits.filter { tieIDs.contains($0.id) }
        #expect(tied.count == 3, "사전 데이터가 바뀌었다 — 세 항목이 '고기' 동률 집합이어야 이 테스트가 유효하다")

        // 반환 순서는 표시 이름 오름차순(`localizedStandardCompare`)과 일치해야 한다 — 로케일 무관하게 성립.
        let expected = tied.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
        #expect(tied.map(\.id) == expected.map(\.id))

        // 회귀 고정 — 이 앱의 기본/QA 로케일(한국어)에서는 표시 이름 순서(닭고기·소고기·양고기)가 내부 id
        // 알파벳순(beef·chicken·lamb)과 실제로 다르다. 이 값이 깨지면 표시 이름이 아니라 id로 도로 정렬된 것이다.
        if Recipe.isKorean {
            #expect(tied.map(\.id) == ["chicken", "beef", "lamb"])
        }
    }

    // MARK: 카테고리 섹션 (To buy 검색 시트의 재료 배열 — 2026-08 30차부터 UI 소비처 없음, 모델만 유지)

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

    // MARK: - 부족 재료 과다 레시피 제외 (덱은 '지금 비우는 요리'만)

    /// 경계 정확도 — 2개 부족은 남고 **3개부터 탈락**한다. 이 숫자가 흔들리면 덱의 성격이 바뀐다
    /// (장 봐야 하는 레시피가 오늘 상해가는 재료를 밀어낸다).
    @Test func rankDropsRecipesMissingThreeOrMore() {
        // 재고는 소고기 하나. 나머지 재료 수만 늘려 부족 개수를 0/1/2/3으로 만든다.
        let stock = [resolvedIng("소고기", daysLeft: 0)]
        let none = recipe(id: "miss0", refs: ["beef"], en: ["beef"])
        let one = recipe(id: "miss1", refs: ["beef", "carrot"], en: ["beef", "carrot"])
        let two = recipe(id: "miss2", refs: ["beef", "carrot", "onion"],
                         en: ["beef", "carrot", "onion"])
        let three = recipe(id: "miss3", refs: ["beef", "carrot", "onion", "egg"],
                           en: ["beef", "carrot", "onion", "egg"])
        let ranked = RecipeRecommender.rank(for: stock, from: [none, one, two, three])
        let ids = ranked.map(\.id)
        #expect(ids.contains("miss0"))
        #expect(ids.contains("miss1"))
        #expect(ids.contains("miss2"), "부족 2개는 경계 안 — 남아야 한다")
        #expect(!ids.contains("miss3"), "부족 3개는 경계 밖 — 덱에서 빠져야 한다")
        // 남은 티켓의 missing 계산 자체는 그대로다(Short 줄·담기 칩이 쓴다).
        #expect(ranked.first(where: { $0.id == "miss2" })?.missing.count == 2)
    }

    /// **후보가 있으면 덱은 비지 않는다.** 제외 규칙은 더 나은 티켓에 자리를 내주라는 것이지,
    /// 보여 줄 게 없어도 빈 화면을 내라는 것이 아니다. 재료가 1~3종뿐인 냉장고(신규 사용자)에서는
    /// 문턱 ①(`clearedCount >= missing.count`)이 구조적으로 못 넘겨져 후보가 전부 탈락한다.
    @Test func rankNeverReturnsEmptyWhileCandidatesExist() {
        let stock = [resolvedIng("소고기", daysLeft: 0)]
        let heavy = recipe(id: "heavy", refs: ["beef", "carrot", "onion", "egg"],
                           en: ["beef", "carrot", "onion", "egg"])
        #expect(RecipeRecommender.rank(for: stock, from: [heavy]).map(\.id) == ["heavy"],
                "제외 규칙에 다 걸려도 덱 장수만큼은 점수 순으로 채워야 한다")
    }

    /// 바닥은 **덱 장수까지만** 채운다 — 통과한 티켓이 이미 충분하면 탈락분이 따라 들어오지 않는다.
    @Test func rankFloorDoesNotResurrectDropsOnceTheDeckIsFull() {
        let stock = [resolvedIng("소고기", daysLeft: 0), resolvedIng("당근", daysLeft: 1),
                     resolvedIng("양파", daysLeft: 2), resolvedIng("감자", daysLeft: 3)]
        let light = (1...3).map { i in
            recipe(id: "light\(i)", refs: ["beef", "carrot"], en: ["beef", "carrot"])
        }
        let heavy = recipe(id: "heavy", refs: ["beef", "bean-sprouts", "zucchini", "garlic"],
                           en: ["beef", "bean sprouts", "zucchini", "minced garlic"])
        let ids = RecipeRecommender.rank(for: stock, from: light + [heavy]).map(\.id)
        #expect(!ids.contains("heavy"), "통과한 티켓이 덱 장수를 채우면 탈락분은 살아나지 않는다")
    }

    /// 덱 바닥(`deckSize`)이 탈락분을 되살리지 않도록 **통과 티켓으로 덱을 채우는 들러리**.
    /// 제외 규칙만 따로 보려면 통과분이 덱 장수를 채워야 한다 — 안 그러면 바닥이 탈락분을 끌어올려
    /// "빠져야 할 티켓이 보인다"가 되고, 그건 규칙이 아니라 바닥을 보는 것이다.
    private func fillers(_ refs: [String], count: Int = 3) -> [Recipe] {
        (0..<count).map { recipe(id: "filler\($0)", refs: refs, en: refs) }
    }

    /// 같은 캐논을 다른 표기 두 줄로 등록해 둔 사용자에게 문턱이 공짜로 낮아지면 안 된다.
    /// (`양파`·`적양파`는 사전상 둘 다 `onion` — 이름 편집만으로 한 로케일에서도 만들어진다.)
    @Test func rankCountsCanonicalIdentityNotWrittenName() {
        let stock = [resolvedIng("양파", daysLeft: 1), resolvedIng("적양파", daysLeft: 1),
                     resolvedIng("감자", daysLeft: 1)]
        // 재고 3줄이지만 실제 소진 재료는 2종(onion·potato) → 부족 3개를 못 넘긴다.
        let plan = recipe(id: "plan", refs: ["onion", "potato", "beef", "carrot", "spinach"],
                          en: ["onion", "potato", "beef", "carrot", "spinach"])
        let easy = recipe(id: "easy", refs: ["onion", "potato"], en: ["onion", "potato"])
        let ids = RecipeRecommender.rank(for: stock, from: [plan, easy] + fillers(["onion"], count: 2)).map(\.id)
        #expect(ids.contains("easy"))
        #expect(!ids.contains("plan"),
                "표기만 다른 같은 캐논 두 줄이 '서로 다른 재료 2종'으로 세어지면 안 된다")
    }

    @Test func missingCountStillComputedForExcludedRecipes() {
        // 제외는 **덱 구성 단계**에서만 한다 — `result(for:)`는 그대로 전부 계산한다.
        let stock = [resolvedIng("소고기", daysLeft: 0)]
        let heavy = recipe(id: "heavy", refs: ["beef", "carrot", "onion", "egg"],
                           en: ["beef", "carrot", "onion", "egg"])
        #expect(RecipeRecommender.result(for: heavy, ingredients: stock).missing.count == 3)
    }

    /// 제외 기준의 **예외** — 임박 재료를 혼자 다루면서 채우는 게 사는 것보다 적지 않으면 남는다.
    ///
    /// 이 예외가 없으면 재고를 4종 소진하는 티켓이 부족 3개라는 이유만으로 사라지고, 그 티켓만
    /// 쓰던 임박 재료는 어느 티켓에도·어느 브리지에도 남지 않는다(커버리지 브리지는 urgent만
    /// 호명하므로 soon 재료는 이름조차 불리지 않는다). 배너는 "위험"이라 압박하는데 화면 어디에도
    /// 행동 경로가 없는 상태가 된다.
    @Test func rankKeepsHeavyTicketThatAloneRescuesAtRiskStock() {
        // 재고 4종(전부 임박) 중 시금치는 `clearsSpinach`만 쓴다.
        let stock = [resolvedIng("시금치", daysLeft: 1), resolvedIng("소고기", daysLeft: 0),
                     resolvedIng("당근", daysLeft: 2), resolvedIng("계란", daysLeft: 2)]
        // 부족 3개지만 재고를 4종 소진한다 — 채우는 게 사는 것보다 많다.
        let clearsSpinach = recipe(id: "clears", refs: ["spinach", "beef", "carrot", "egg",
                                                        "bean-sprouts", "zucchini", "garlic"],
                                   en: ["spinach", "beef", "carrot", "egg",
                                        "bean sprouts", "zucchini", "minced garlic"])
        // 재고는 소고기 하나만 쓰면서 3종을 사야 한다 — 장보기 계획이라 예외를 못 받는다.
        let shoppingPlan = recipe(id: "plan", refs: ["beef", "bean-sprouts", "zucchini", "garlic"],
                                  en: ["beef", "bean sprouts", "zucchini", "minced garlic"])
        // 들러리 둘은 시금치를 건드리지 않는다 — clears의 "혼자 구해 낸다"가 흐려지지 않게.
        let deck = [clearsSpinach, shoppingPlan] + [recipe(id: "filler0", refs: ["beef"], en: ["beef"]),
                                                    recipe(id: "filler1", refs: ["egg"], en: ["egg"])]
        let ids = RecipeRecommender.rank(for: stock, from: deck).map(\.id)
        #expect(ids.contains("clears"), "재고 4종을 소진하며 시금치를 혼자 다루는 티켓은 남아야 한다")
        #expect(!ids.contains("plan"), "재고 1종에 3종을 사야 하는 티켓은 덱에 오를 자격이 없다")
    }

    /// 같은 임박 재료를 이미 덮은 뒤라면 무거운 티켓은 더 남을 이유가 없다 — 예외는 **한 번만** 쓴다.
    ///
    /// 무게 조건(`used >= missing`)은 **통과시켜 놓고** 커버리지 조건만으로 탈락시킨다 — 그래야
    /// `rescuesSomethingNew`를 지웠을 때 이 테스트가 실제로 깨진다(무게 조건만 남으면 통과해 버린다).
    @Test func rankDropsHeavyTicketOnceItsAtRiskStockIsAlreadyCovered() {
        let stock = [resolvedIng("소고기", daysLeft: 0), resolvedIng("당근", daysLeft: 1),
                     resolvedIng("양파", daysLeft: 9), resolvedIng("감자", daysLeft: 9)]
        // light는 같은 4종을 쓰면서 살 게 없다 — 점수가 같고 부족이 적어 **먼저** 선다(tie-break).
        let light = recipe(id: "light", refs: ["beef", "carrot", "onion", "potato"],
                           en: ["beef", "carrot", "onion", "potato"])
        // 재고 4종을 쓰고 3종을 사므로 무게 조건은 통과한다. 그런데 임박(소고기·당근)은 light가
        // 이미 덮었고 나머지(양파·감자)는 fresh라 새로 구해 내는 것이 없다 → 탈락해야 한다.
        let heavy = recipe(id: "heavy",
                           refs: ["beef", "carrot", "onion", "potato", "egg", "spinach", "tofu"],
                           en: ["beef", "carrot", "onion", "potato", "egg", "spinach", "tofu"])
        let deck = [light, heavy] + [recipe(id: "filler0", refs: ["beef"], en: ["beef"]),
                                     recipe(id: "filler1", refs: ["carrot"], en: ["carrot"])]
        let ids = RecipeRecommender.rank(for: stock, from: deck).map(\.id)
        #expect(ids.contains("light"))
        #expect(!ids.contains("heavy"), "임박 재료를 앞 티켓이 이미 덮었으면 무거운 티켓은 빠진다")
    }

    /// 무게 조건도 단독으로 검증한다 — 임박 재료를 혼자 구해 내도 사는 게 더 많으면 못 남는다.
    @Test func rankDropsHeavyTicketThatBuysMoreThanItClears() {
        let stock = [resolvedIng("시금치", daysLeft: 1)]
        let plan = recipe(id: "plan", refs: ["spinach", "beef", "carrot", "onion"],
                          en: ["spinach", "beef", "carrot", "onion"])
        // 부족 1~2개짜리 들러리로 덱을 채워 바닥이 안 돌게 한다.
        let deck = [plan, recipe(id: "f0", refs: ["spinach", "beef"], en: ["spinach", "beef"]),
                    recipe(id: "f1", refs: ["spinach", "carrot"], en: ["spinach", "carrot"]),
                    recipe(id: "f2", refs: ["spinach", "onion"], en: ["spinach", "onion"])]
        #expect(!RecipeRecommender.rank(for: stock, from: deck).map(\.id).contains("plan"),
                "재고 1종에 3종을 사야 하는 티켓은 임박 재료를 혼자 다뤄도 덱에 오를 자격이 없다")
    }

    /// 같은 재료를 여러 줄로 등록해 둔 사용자에게 무게 문턱이 공짜로 낮아지면 안 된다 —
    /// `used`의 줄 수가 아니라 **서로 다른 재료 수**를 센다.
    @Test func rankCountsDistinctIngredientsNotDuplicateRows() {
        // 시금치를 세 줄로 등록(장 볼 때마다 새 줄) → used는 3줄이지만 실제로 비우는 재료는 1종.
        let stock = [resolvedIng("시금치", daysLeft: 1), resolvedIng("시금치", daysLeft: 1),
                     resolvedIng("시금치", daysLeft: 1)]
        let plan = recipe(id: "plan", refs: ["spinach", "beef", "carrot", "onion"],
                          en: ["spinach", "beef", "carrot", "onion"])
        let deck = [plan, recipe(id: "f0", refs: ["spinach", "beef"], en: ["spinach", "beef"]),
                    recipe(id: "f1", refs: ["spinach", "carrot"], en: ["spinach", "carrot"]),
                    recipe(id: "f2", refs: ["spinach", "onion"], en: ["spinach", "onion"])]
        #expect(!RecipeRecommender.rank(for: stock, from: deck).map(\.id).contains("plan"),
                "중복 등록으로 used 줄 수가 늘어도 비우는 재료는 1종이라 문턱을 못 넘는다")
    }

    /// 냉장고가 전부 신선하면 "오늘 비우는 순서"라는 기준이 안 선다 — 그때는 커버리지 조건을
    /// 요구하지 않는다. 안 그러면 잘 채워진 냉장고가 빈 덱을 받고, 빈 상태 문안("재료 이름 확인·장보기")이
    /// 그 사용자에겐 둘 다 틀린 말이 된다.
    @Test func rankKeepsSubstantialTicketsWhenNothingIsAtRisk() {
        let stock = [resolvedIng("소고기", daysLeft: 9), resolvedIng("당근", daysLeft: 9),
                     resolvedIng("양파", daysLeft: 9), resolvedIng("감자", daysLeft: 9)]
        let heavy = recipe(id: "heavy",
                           refs: ["beef", "carrot", "onion", "potato", "egg", "spinach", "tofu"],
                           en: ["beef", "carrot", "onion", "potato", "egg", "spinach", "tofu"])
        #expect(RecipeRecommender.rank(for: stock, from: [heavy]).map(\.id) == ["heavy"],
                "임박한 게 없으면 재고를 많이 쓰는 티켓은 부족이 3개여도 남아야 한다")
    }

    // MARK: - 번들 시드로 도는 랭킹 (합성 픽스처가 못 보는 것)

    /// 덱 구성 규칙은 **실제 시드 80종**으로도 돌려 본다 — 합성 4개짜리 픽스처는 상수를 함께 고치면
    /// 그대로 통과하므로, "이 규칙이 진짜 덱을 얼마나 깎는가"를 못 잡는다.
    ///
    /// 여기서 잠그는 것은 숫자가 아니라 **성립 조건**이다: 앱이 온보딩에서 실제로 주는 샘플 냉장고로
    /// ① 덱이 비지 않고 ② 임박 재료가 덱 어딘가에 실제로 남는다. 둘 중 하나라도 깨지면 사용자는
    /// 첫 화면에서 빈 덱이나 "행동 경로 없는 위험 배너"를 본다.
    @Test func rankOverBundledSeedKeepsSampleFridgeActionable() throws {
        let recipes = RecipeCatalog.loadSeed()
        #expect(recipes.count >= 50, "번들 시드를 못 읽었다")
        let stock: [Ingredient] = SampleData.ingredients
        let ranked = RecipeRecommender.rank(for: stock, from: recipes)
        #expect(!ranked.isEmpty, "샘플 냉장고로 덱이 통째로 비면 첫 화면이 빈 상태가 된다")

        // 임박(urgent·soon) 재고가 덱에서 실제로 다뤄지는가 — 배너가 세는 것과 덱이 다루는 것이 갈리면
        // 사용자는 "위험하다"는 말만 듣고 할 일을 못 받는다.
        let atRisk = stock.filter { $0.freshness != Freshness.fresh }
        #expect(!atRisk.isEmpty, "샘플 냉장고에는 임박 재료가 있어야 한다(시드 전제)")
        let coveredIDs = Set(ranked.prefix(3).flatMap { $0.used.map(\.id) })
        let uncovered = atRisk.filter { !coveredIDs.contains($0.id) }
        #expect(uncovered.count < atRisk.count,
                "상위 3장이 임박 재료를 하나도 안 다루면 덱이 오늘의 할 일을 말하지 못한다")
    }

    /// **신규 사용자의 작은 냉장고**(재료 2~3종, 전부 신선) — 여기가 첫 화면이다.
    ///
    /// 제외 문턱 ①(`clearedCount >= missing.count`)은 재고 종수가 곧 상한이라, 이 구간에서는
    /// 부족 3개 이상인 후보가 통째로 탈락한다(실측: 3종 조합의 45%, 2종이면 56%가 덱 0장이었다).
    /// 게다가 전부 신선하면 빈 상태의 atRisk 분기를 못 타서 **버튼 하나 없는 정적 문구**만 남고,
    /// 그 문구의 조언("재료 이름을 확인하라")은 이 사용자에게 틀린 말이다 — 이름이 맞았으니 후보가
    /// 수십 장이었기 때문이다. 덱 바닥(`deckSize`)이 그 구간을 메운다.
    @Test func rankOverBundledSeedFillsSmallFreshFridges() {
        let recipes = RecipeCatalog.loadSeed()
        for names in [["양파", "두부", "닭고기"], ["양파", "양배추", "돼지고기"], ["계란", "우유"]] {
            let stock = names.map { resolvedIng($0, daysLeft: 7) }   // 전부 신선
            let ranked = RecipeRecommender.rank(for: stock, from: recipes)
            #expect(!ranked.isEmpty, "\(names): 후보가 있는데 신규 사용자에게 빈 덱을 준다")
        }
    }

    // MARK: - 부족 재료 → 장보기 메모 매핑 (표시명 역조회 금지)

    @Test func toBuyEntryTrustsRefOverParentheticalText() {
        // 시드 표기는 괄호 주석을 달고 다닌다("pork (or beef)") — 이름 역조회는 포함 매칭이라
        // 괄호 **안** 단어에 먼저 걸린다. ref가 있으면 그게 정본이고, 표기도 사전 표제어로 정리된다.
        let pork = Recipe.Item(ref: "pork", en: "pork (or beef)", ko: nil)
        #expect(IngredientLexicon.shared.canonicalID(for: pork.en) == "beef")   // 역조회의 함정(회귀 고정)
        let entry = RecipeRecommender.toBuyEntry(for: pork)
        #expect(entry.canonicalID == "pork")
        #expect(entry.glyph == .meat)
        #expect(!entry.name.contains("("))   // 장보기 목록은 조리 지시가 아니라 살 것을 적는 자리

        // 괄호가 다른 재료를 통째로 품는 경우("gim (seaweed sheets)")도 ref가 이긴다.
        let gim = RecipeRecommender.toBuyEntry(for: Recipe.Item(ref: "seaweed",
                                                                en: "gim (seaweed sheets)", ko: "김밥용 김"))
        #expect(gim.canonicalID == "seaweed")
        #expect(gim.glyph == .seaweed)
    }

    @Test func toBuyEntryStripsParentheticalsFromUnresolvedLines() {
        // ref도 없고 정확 일치도 없는 서술형 라인 — 괄호를 떼야 재료명이 남는다.
        // 원문 그대로 store에 넘기면 이름 역조회가 멸치(anchovy)에 붙는다.
        let water = Recipe.Item(ref: nil, en: "water (or anchovy stock)", ko: nil)
        #expect(RecipeRecommender.canonicalID(of: water) == nil)
        #expect(IngredientLexicon.shared.canonicalID(for: water.en) == "anchovy")   // 함정 고정
        let entry = RecipeRecommender.toBuyEntry(for: water)
        // 괄호를 뗀 "water"는 그 자체로 사전 표제어라 캐논까지 확정된다(표기는 표제어로 정리된다).
        #expect(entry.canonicalID == "water")
        #expect(entry.name.lowercased() == "water")
    }

    /// **머리말 일치** — 사전 표제어가 이름의 *끝*에 올 때만 캐논으로 채택한다.
    ///
    /// 포함 매칭을 그대로 쓰면 앞에 걸리는 키워드가 대개 딴 재료라(시드 실측 4건) 그 품목이 남의
    /// 줄에 흡수돼 **목록에 들어가지도 않는다**. 여기서 두 방향을 다 고정한다: 진짜 머리말은 살리고,
    /// 수식어 자리에 걸린 이름은 캐논 없이 표기 그대로 남긴다.
    @Test func toBuyEntryUsesHeadNounNotSubstringMatch() {
        let lex = IngredientLexicon.shared
        // ① 수식어 자리에 걸린 이름 — 포함 매칭의 함정. 캐논을 붙이면 안 된다.
        for (en, trap) in [("paprika powder (or mild chili powder)", "bell-pepper"),
                           ("chicken or vegetable stock (kept warm)", "chicken")] {
            let item = Recipe.Item(ref: nil, en: en, ko: nil)
            #expect(lex.canonicalID(for: en) == trap, "\(en): 포함 매칭 함정이 그대로여야 한다(회귀 고정)")
            let entry = RecipeRecommender.toBuyEntry(for: item)
            #expect(entry.canonicalID != trap, "\(en): 수식어에 걸린 캐논이 붙으면 안 된다")
        }
        // "chicken or vegetable stock"은 머리말이 stock이라 그쪽으로 붙는다 — 이건 정답이다.
        #expect(RecipeRecommender.toBuyEntry(
            for: Recipe.Item(ref: nil, en: "chicken or vegetable stock (kept warm)", ko: nil)
        ).canonicalID == "stock")
        // "paprika powder"의 머리말(powder)은 사전에 없다 → 캐논 없이 표기 그대로(안전한 실패).
        #expect(RecipeRecommender.toBuyEntry(
            for: Recipe.Item(ref: nil, en: "paprika powder (or mild chili powder)", ko: nil)
        ).canonicalID == nil)

        // ② 진짜 머리말은 살린다 — 수식이 붙어도 끝에 오는 표제어가 재료다.
        #expect(RecipeRecommender.toBuyEntry(
            for: Recipe.Item(ref: nil, en: "minced garlic", ko: nil)).canonicalID == "garlic")
        #expect(RecipeRecommender.toBuyEntry(
            for: Recipe.Item(ref: nil, en: "cold water", ko: nil)).canonicalID == "water")
    }

    /// **머리말 일치는 `en`으로만 본다** — 기기 언어가 장보기 키를 바꾸면 안 된다(CLAUDE.md: 데이터는
    /// 영문 캐논으로 저장하고 표시만 로컬라이즈).
    ///
    /// `미소 된장`은 머리말이 `된장`이라 ko로 읽으면 사전의 `doenjang`에 붙는다 — 미소와 된장은 다른
    /// 제품이라 한국어 기기에서만 **미소 대신 된장**이 담기고, 목록에 이미 된장이 있으면 그 재료는
    /// 중복으로 취급돼 아예 들어가지도 않는다. en(`miso paste`)의 머리말 `paste`는 사전에 없으므로
    /// 두 로케일 모두 표기 그대로 담긴다.
    @Test func toBuyEntryResolvesTheSameWayInEveryLocale() {
        let miso = Recipe.Item(ref: nil, en: "miso paste", ko: "미소 된장")
        #expect(IngredientLexicon.shared.headNounCanonicalID(for: "미소 된장") == "doenjang")  // 함정 고정
        #expect(RecipeRecommender.toBuyEntry(for: miso).canonicalID == nil,
                "한국어 표기의 머리말로 엉뚱한 캐논이 붙으면 안 된다")

        // 반대 방향도 같다 — ko가 못 잡는 표기라도 en이 잡으면 두 로케일 모두 캐논이 붙는다.
        let basil = Recipe.Item(ref: nil, en: "fresh basil", ko: "바질 잎")
        #expect(IngredientLexicon.shared.headNounCanonicalID(for: "바질 잎") == nil)
        #expect(RecipeRecommender.toBuyEntry(for: basil).canonicalID == "basil")
    }

    /// 상비재는 Short 줄에도, 장보기 목록에도 나오면 안 된다 — `isStaple`과 담기가 **같은 눈**으로 읽는다.
    /// 정확 일치만 보던 시절 `cold water`는 비-상비로 분류돼 Short에 뜬 뒤 담을 때만 `water`로 풀려
    /// 장보기 목록에 "물"이 적혔다.
    @Test func stapleDetectionUsesTheSameResolutionAsShopping() {
        for en in ["cold water", "water (or anchovy stock)", "sweet soy sauce (kecap manis)"] {
            let item = Recipe.Item(ref: nil, en: en, ko: nil)
            #expect(RecipeRecommender.isStaple(item), "\(en): 상비재로 잡혀 Short 줄에서 빠져야 한다")
        }
    }

    @Test func toBuyEntryKeepsTextWhenParenthesesAreUnbalanced() {
        // 커스텀 레시피의 오타로 괄호가 안 닫히면, 뒤를 통째로 잘라 이름을 조용히 줄이는 것보다
        // 사용자가 적은 표기를 그대로 두는 편이 안전하다("Sauce (soy" → "Sauce"가 되면 안 된다).
        let typo = Recipe.Item(ref: nil, en: "Sauce (soy", ko: nil)
        #expect(RecipeRecommender.toBuyEntry(for: typo).name == "Sauce (soy")
        // 짝이 맞는 경우는 종전대로 괄호를 떼고 정리한다(회귀 대비 대조군).
        let balanced = Recipe.Item(ref: nil, en: "Sauce (soy sauce)", ko: nil)
        #expect(RecipeRecommender.toBuyEntry(for: balanced).name == "Sauce")
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

/// 표시 이름 — **가드형 단일 정책**(`IngredientLexicon.displayName(stored:canonicalID:)`).
/// 저장 스키마(`name`)는 손대지 않고, 저장 표기가 사전 표제어(en/ko)와 일치할 때만 지금 로케일
/// 표제어로 다시 읽는다. "사용자가 적은 표기는 데이터다 — 사전이 아는 말일 때만 사전이 말한다."
struct DisplayNameTests {

    /// 표제어로 담은 것은 언어를 따라온다 — **반대 로케일 표기를 넣어** 왕복을 세운다.
    /// 테스트에서 호스트 언어를 못 바꾸므로(`Recipe.isKorean`은 `Locale.current`를 읽는다),
    /// 지금 호스트가 아닌 *반대쪽* 표기를 저장값으로 주고 지금 쪽 표제어가 나오는지 본다 —
    /// 어느 호스트에서 돌려도 실제 언어 전환 왕복(ko 입력 → en 표시)을 재현한다.
    @Test func lexiconHeadwordIsRedrawnInTheCurrentLocale() throws {
        let entry = try #require(IngredientLexicon.shared.entry(id: "onion"))
        let ko = try #require(entry.names.ko.first)        // "양파"
        let en = try #require(entry.names.en.first)        // "onion"(사전의 영문은 매칭용 소문자 캐논)
        let stored = Recipe.isKorean ? en : ko
        let ing = Ingredient(name: stored, category: "Veg", expiresAt: Date(), canonicalID: "onion")
        #expect(ing.displayName == entry.displayName)
        #expect(ing.displayName == (Recipe.isKorean ? ko : en.localizedCapitalized))
        #expect(ing.name == stored)                        // 저장값 자체는 건드리지 않는다
    }

    /// 캐논이 붙어 있어도 **사전이 모르는 표기는 덮지 않는다**(가드형의 핵심).
    /// 영수증 줄 "서울우유1L"은 포함 매칭으로 캐논이 milk지만, 사용자가 산 그 물건의 이름이
    /// 화면에서 "Milk"로 바뀌면 안 된다.
    @Test func freeTextSurvivesEvenWhenItMatchedACanon() {
        #expect(IngredientLexicon.shared.canonicalID(for: "서울우유1L") == "milk")   // 전제
        let ing = Ingredient(name: "서울우유1L", category: "Dairy",
                             expiresAt: Date(), canonicalID: "milk")
        #expect(ing.displayName == "서울우유1L")
    }

    @Test func freeTextKeepsStoredName() {
        let ing = Ingredient(name: "할머니표 장아찌", category: "Other", expiresAt: Date())
        #expect(ing.displayName == "할머니표 장아찌")
    }

    /// 한 품목은 **어느 화면에서든 같은 이름으로 불린다**. 표면마다 규칙이 갈렸던 전례를 못 박는다:
    /// 같은 이력 로그가 History에선 "Milk", To buy에선 "서울우유1L"로 읽혔다(재고 카드·뱃지·알림은
    /// `Ingredient`, 타임라인은 `RemovalLog`, 장보기 메모는 `ManualBuyItem`을 그린다).
    @MainActor   // `FridgeStore.displayName(for:)`는 스토어와 함께 메인 액터에 산다
    @Test func everySurfaceAgreesOnTheSameName() throws {
        let entry = try #require(IngredientLexicon.shared.entry(id: "milk"))
        let headword = try #require(entry.names.ko.first)
        for stored in [headword, "서울우유1L"] {          // 표제어 / 자유 입력 양쪽
            let ing = Ingredient(name: stored, category: "Dairy",
                                 expiresAt: Date(), canonicalID: "milk")
            let log = RemovalLog(name: stored, glyph: .milk, canonicalID: "milk",
                                 removedAt: Date(), wasted: false)
            let memo = FridgeStore.ManualBuyItem(name: stored, canonicalID: "milk", glyph: .milk)
            #expect(ing.displayName == log.displayName)
            #expect(log.displayName == FridgeStore.displayName(for: memo))
        }
    }

    @Test func removalLogFollowsSameRule() {
        let log = RemovalLog(name: "우유", glyph: .milk, canonicalID: "milk",
                             removedAt: Date(), wasted: false)
        #expect(log.displayName == IngredientLexicon.shared.entry(id: "milk")?.displayName)
        // 캐논이 있어도 사전 밖 표기는 그대로 — 타임라인이 사용자가 산 물건 이름을 지우지 않는다.
        let kept = RemovalLog(name: "old label", glyph: .milk, canonicalID: "milk",
                              removedAt: Date(), wasted: false)
        #expect(kept.displayName == "old label")
        let free = RemovalLog(name: "직접 만든 잼", glyph: .generic, removedAt: Date(), wasted: true)
        #expect(free.displayName == "직접 만든 잼")
    }
}
