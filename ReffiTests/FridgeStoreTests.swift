import Testing
import Foundation
@testable import Reffi

/// 스토어 — 스냅샷 라운드트립·v1 마이그레이션·undo 불변식·예약 모델·데이터 관리.
@MainActor
struct FridgeStoreTests {

    private func makeStore(daysLeft: [Int] = [0, 1, 3]) -> FridgeStore {
        let ings = daysLeft.enumerated().map { i, d in
            Ingredient(name: "Item\(i)", category: "Veg", daysLeft: d,
                       quantity: Quantity(value: 2, unit: .piece), glyph: .generic)
        }
        return FridgeStore(ingredients: ings, recipes: [], history: [])
    }

    // MARK: 스냅샷

    @Test func snapshotRoundTrip() throws {
        let ing = Ingredient(name: "연두부", category: "Protein", daysLeft: 2,
                             quantity: Quantity(value: 0.5, unit: .block), glyph: .tofu,
                             storage: .fridge)
        let snap = FridgeStore.Snapshot(
            schemaVersion: FridgeStore.currentSchemaVersion,
            ingredients: [ing], history: [], dismissedToBuy: ["milk"],
            counterIDs: [ing.id], activeCook: nil,
            userRecipes: [Recipe.userRecipe(name: "볶음밥", ingredientNames: ["계란", "밥"],
                                            minutes: 15, steps: ["볶는다"])],
            archivedAte: 3, archivedTossed: 1)
        let data = try JSONEncoder().encode(snap)
        let decoded = try #require(FridgeStore.decodeSnapshot(data))
        #expect(decoded.ingredients == [ing])
        #expect(decoded.userRecipes?.count == 1)
        #expect(decoded.archivedAte == 3)
    }

    @Test func decodesLegacyV1Payload() throws {
        // v1 실물 형태: schemaVersion·quantity·frozenAt·userRecipes 없음, amount 자유 문자열,
        // alternative 필드 존재, 날짜는 deferredToDate(참조시각 초).
        let legacy = """
        {"ingredients":[{"id":"3E29D5C3-99D5-44A5-BB80-1E1B62F0A6DD","name":"Beef",
        "category":"Meat · Beef","expiresAt":773236800,"amount":"300 g","alternative":"cook",
        "glyph":"meat","place":"Costco","storage":"Freezer","purchasedAt":773100000}],
        "history":[],"dismissedToBuy":[],"counterIDs":[]}
        """.replacingOccurrences(of: "\n", with: "")
        let snap = try #require(FridgeStore.decodeSnapshot(Data(legacy.utf8)))
        let ing = try #require(snap.ingredients.first)
        #expect(ing.quantity == Quantity(value: 300, unit: .gram))   // amount → 수량 마이그레이션
        #expect(ing.storage == .freezer)                             // 문자열 → enum
        #expect(ing.frozenAt == nil)                                 // 없던 필드는 nil
        #expect(snap.schemaVersion == nil)                           // v1 표식
    }

    @Test func decodesSnapshotWithRemovedAIRecipesKey() throws {
        // AI 생성 기능 제거 전에 저장된 파일 — Snapshot에 더 이상 없는 `aiRecipes` 키가 남아 있다.
        // 모르는 키는 무시되고 나머지 상태는 온전히 살아야 한다(격리·데이터 소실 금지).
        let json = """
        {"schemaVersion":2,"ingredients":[],"history":[],"dismissedToBuy":[],"counterIDs":[],
        "userRecipes":[],"archivedAte":4,"archivedTossed":2,
        "aiRecipes":[{"id":"ai-1","name":{"en":"Ghost Dish","ko":null},"minutes":10,
        "ingredients":[{"ref":null,"en":"x","ko":null}],"steps":{"en":["s"],"ko":null},"origin":"ai"}]}
        """.replacingOccurrences(of: "\n", with: "")
        let snap = try #require(FridgeStore.decodeSnapshot(Data(json.utf8)))
        #expect(snap.archivedAte == 4)
        #expect(snap.archivedTossed == 2)
        #expect(snap.userRecipes?.isEmpty == true)
    }

    @Test func recipesPoolIsCustomPlusSeed() {
        let seed = Recipe(id: "seed-1", name: Recipe.LocalizedName(en: "Seed Dish", ko: nil),
                          cuisine: nil, minutes: 10,
                          ingredients: [Recipe.Item(ref: nil, en: "x", ko: nil)],
                          steps: Recipe.LocalizedSteps(en: ["s"], ko: nil), isUser: nil)
        let store = FridgeStore(ingredients: [], recipes: [seed], history: [])
        store.addUserRecipe(Recipe.userRecipe(name: "Mine", ingredientNames: ["egg"],
                                              minutes: 5, steps: ["cook"]))
        #expect(store.recipes.map(\.name.en) == ["Mine", "Seed Dish"])   // 커스텀 우선 + 시드
    }

    /// 영속 데이터 호환 — origin 필드는 제거된 AI 기능이 남긴 값을 잃지 않게 모델에 남아 있다.
    @Test func recipeKeepsOriginFieldForPersistedData() throws {
        let json = #"{"id":"ai-1","name":{"en":"Legacy"},"minutes":10,"ingredients":[{"en":"x"}],"steps":{"en":["s"]},"origin":"ai"}"#
        let recipe = try JSONDecoder().decode(Recipe.self, from: Data(json.utf8))
        #expect(recipe.origin == "ai")
        #expect(recipe.displayName == "Legacy")
    }

    @Test func unknownStorageFallsBackToFridge() throws {
        let json = """
        {"ingredients":[{"id":"3E29D5C3-99D5-44A5-BB80-1E1B62F0A6DE","name":"X","category":"Veg",
        "expiresAt":773236800,"amount":"1","glyph":"generic","place":"","storage":"Cellar",
        "purchasedAt":773100000}],"history":[],"dismissedToBuy":[],"counterIDs":[]}
        """.replacingOccurrences(of: "\n", with: "")
        let snap = try #require(FridgeStore.decodeSnapshot(Data(json.utf8)))
        #expect(snap.ingredients.first?.storage == .fridge)
    }

    // MARK: 판정 + undo

    @Test func decisionUndoRestoresEverything() {
        let store = makeStore()
        let target = store.sorted[0]
        let ingBefore = store.ingredients
        let counterBefore = store.counterIDs

        store.eat(target)
        #expect(!store.ingredients.contains(where: { $0.id == target.id }))
        #expect(store.history.count == 1)

        store.undoPending()
        #expect(Set(store.ingredients.map(\.id)) == Set(ingBefore.map(\.id)))
        #expect(store.history.isEmpty)
        #expect(store.counterIDs == counterBefore)
        #expect(store.pendingUndo == nil)
    }

    // MARK: 예약 모델 (fire → Finish 확정)

    @Test func fireReservesWithoutLogging() {
        let store = makeStore()
        let recipe = Recipe.userRecipe(name: "Test", ingredientNames: ["Item0"], minutes: 10, steps: [])
        let result = RecipeRecommender.result(for: recipe, ingredients: store.sorted)
        #expect(!result.used.isEmpty)

        store.cook(result)
        // 예약만 — 재고는 그대로, 이력 0, 작업대·추천에서는 빠진다.
        #expect(store.ingredients.count == 3)
        #expect(store.history.isEmpty)
        #expect(store.reservedIDs.contains(result.used[0].id))
        #expect(!store.counterIngredients.contains(where: { $0.id == result.used[0].id }))
        #expect(!store.available.contains(where: { $0.id == result.used[0].id }))
    }

    @Test func finishCommitsAndLeftoverHalves() {
        let store = makeStore()
        let recipe = Recipe.userRecipe(name: "Test", ingredientNames: ["Item0", "Item1"],
                                       minutes: 10, steps: [])
        let result = RecipeRecommender.result(for: recipe, ingredients: store.sorted)
        #expect(result.used.count == 2)
        store.cook(result)

        let leftoverID = result.used[1].id
        store.finishCooking(leftovers: [leftoverID])
        // 다 쓴 재료는 이력으로, 남은 재료는 수량 절반으로 잔류.
        #expect(store.history.count == 1)
        #expect(store.history[0].via == "Test")
        let leftover = store.ingredients.first { $0.id == leftoverID }
        #expect(leftover?.quantity.value == 1)   // 2 → 1
        #expect(store.activeCook == nil)
    }

    @Test func cancelCookingReleasesReservation() {
        let store = makeStore()
        let recipe = Recipe.userRecipe(name: "Test", ingredientNames: ["Item0"], minutes: 10, steps: [])
        store.cook(RecipeRecommender.result(for: recipe, ingredients: store.sorted))
        #expect(!store.reservedIDs.isEmpty)

        store.cancelCooking()
        #expect(store.reservedIDs.isEmpty)
        #expect(store.history.isEmpty)
        #expect(store.ingredients.count == 3)
        #expect(store.counterIngredients.count == 3)   // 작업대 복귀
    }

    @Test func fireUndoReleasesReservation() {
        let store = makeStore()
        let counterBefore = store.counterIDs
        let recipe = Recipe.userRecipe(name: "Test", ingredientNames: ["Item0"], minutes: 10, steps: [])
        store.cook(RecipeRecommender.result(for: recipe, ingredients: store.sorted))

        store.undoPending()
        #expect(store.activeCook == nil)
        #expect(store.reservedIDs.isEmpty)
        #expect(store.counterIDs == counterBefore)
    }

    // MARK: 프리저 + 작업대 정책

    @Test func freezeGivesGraceAndLeavesCounter() {
        let store = makeStore(daysLeft: [0, 1])
        let urgent = store.sorted[0]
        #expect(urgent.canFreeze)

        store.freeze(urgent)
        let frozen = store.ingredients.first { $0.id == urgent.id }!
        #expect(frozen.isFrozen && frozen.frozenAt != nil)
        #expect(frozen.effectiveDaysLeft == Ingredient.freezerGraceDays)
        // 유예가 넉넉한 냉동 재료는 작업대(오늘의 행동 표면)에서 빠진다.
        #expect(!store.counterIngredients.contains(where: { $0.id == urgent.id }))
        // 재냉동 불가.
        store.freeze(frozen)
        #expect(store.ingredients.first { $0.id == urgent.id }!.frozenAt == frozen.frozenAt)
    }

    // MARK: 정정 삭제 + 데이터 관리 불변식

    @Test func removeLeavesNoHistory() {
        let store = makeStore()
        let target = store.sorted[0]
        store.remove(target)
        #expect(store.history.isEmpty)
        #expect(!store.ingredients.contains(where: { $0.id == target.id }))
        #expect(!store.counterIDs.contains(target.id))
    }

    @Test func loadSampleDataResetsCookSession() {
        let store = makeStore()
        let recipe = Recipe.userRecipe(name: "Test", ingredientNames: ["Item0"], minutes: 10, steps: [])
        store.cook(RecipeRecommender.result(for: recipe, ingredients: store.sorted))
        #expect(store.activeCook != nil)

        store.loadSampleData()
        #expect(store.activeCook == nil)   // 유령 'Cooking now' 카드 방지
        #expect(!store.ingredients.isEmpty)
    }

    // MARK: 리뷰 회귀 (2026-07-02 코드리뷰 확정 결함)

    @Test func finishUndoRestoresLeftoverQuantityAndSession() {
        let store = makeStore()
        let recipe = Recipe.userRecipe(name: "Test", ingredientNames: ["Item0", "Item1"],
                                       minutes: 10, steps: [])
        let result = RecipeRecommender.result(for: recipe, ingredients: store.sorted)
        store.cook(result)
        let session = store.activeCook
        let leftoverID = result.used[1].id

        store.finishCooking(leftovers: [leftoverID])
        #expect(store.ingredients.first { $0.id == leftoverID }?.quantity.value == 1)   // 2 → 1
        if case .finished = store.pendingUndo?.kind {} else {
            Issue.record("finish 후 undo 창은 .finished여야 한다")
        }

        store.undoPending()
        // 절반 수량 원복 + 이력 회수 + 조리 세션 재개.
        #expect(store.ingredients.first { $0.id == leftoverID }?.quantity.value == 2)
        #expect(store.history.isEmpty)
        #expect(store.activeCook?.recipeName == session?.recipeName)
        #expect(Set(store.activeCook?.usedIDs ?? []) == Set(session?.usedIDs ?? []))
    }

    @Test func cancelAndFinishClearStaleFireUndo() {
        let store = makeStore()
        let recipe = Recipe.userRecipe(name: "Test", ingredientNames: ["Item0"], minutes: 10, steps: [])
        store.cook(RecipeRecommender.result(for: recipe, ingredients: store.sorted))
        if case .fired = store.pendingUndo?.kind {} else { Issue.record("fire 직후 .fired 창") }

        store.cancelCooking()
        #expect(store.pendingUndo == nil)   // 취소된 발주의 'Started' 토스트가 남지 않는다

        // 전부-leftover finish도 fired 창을 finished 창으로 교체한다(가짜 원복 방지).
        store.cook(RecipeRecommender.result(for: recipe, ingredients: store.sorted))
        let id = store.activeCook!.usedIDs![0]
        store.finishCooking(leftovers: [id])
        if case .finished = store.pendingUndo?.kind {} else {
            Issue.record("전부-leftover finish 후에도 .finished 창이 열려야 한다")
        }
    }

    @Test func eatingReservedIngredientSyncsSession() {
        let store = makeStore()
        let recipe = Recipe.userRecipe(name: "Test", ingredientNames: ["Item0", "Item1"],
                                       minutes: 10, steps: [])
        store.cook(RecipeRecommender.result(for: recipe, ingredients: store.sorted))
        let reserved = store.activeCook!.usedIDs!
        #expect(reserved.count == 2)

        // Fridge 탭 경로 — 예약 재료를 직접 판정해도 세션 카운트·목록이 동기화된다.
        let target = store.ingredients.first { $0.id == reserved[0] }!
        store.eat(target)
        #expect(store.activeCook?.usedIDs?.contains(target.id) == false)
        #expect(store.activeCook?.count == 1)
    }

    @Test func undoDoesNotReturnFreshlyFrozenToCounter() {
        let store = makeStore(daysLeft: [0, 0, 5])
        let first = store.sorted[0]
        let second = store.sorted[1]
        store.eat(first)                    // undo 창(counterSnapshot에 second 포함)
        store.freeze(second)                // 곧바로 냉동 — 유예 D-14, 작업대 부적격
        store.undoPending()                 // first 복원
        #expect(store.ingredients.contains { $0.id == first.id })
        // 냉동된 second는 스냅샷 원복으로도 작업대에 돌아오면 안 된다(유예 D-3 규칙).
        #expect(!store.counterIngredients.contains { $0.id == second.id })
    }

    @Test func replacingSessionUndoRestoresPreviousSession() {
        let store = makeStore()
        let a = Recipe.userRecipe(name: "A", ingredientNames: ["Item0"], minutes: 10, steps: ["s1"])
        let b = Recipe.userRecipe(name: "B", ingredientNames: ["Item1"], minutes: 10, steps: [])
        store.cook(RecipeRecommender.result(for: a, ingredients: store.sorted))
        store.toggleCookStep(0)
        let sessionA = store.activeCook

        store.cook(RecipeRecommender.result(for: b, ingredients: store.sorted))   // 교체
        #expect(store.activeCook?.recipeName == "B")

        store.undoPending()   // B 발주 취소 → A 세션(체크 진행 포함) 복원
        #expect(store.activeCook?.recipeName == "A")
        #expect(store.activeCook?.completedSteps == sessionA?.completedSteps)
    }

    @Test func unknownGlyphDecodesToGeneric() throws {
        let json = """
        {"ingredients":[{"id":"3E29D5C3-99D5-44A5-BB80-1E1B62F0A6DF","name":"X","category":"Veg",
        "expiresAt":773236800,"amount":"1","glyph":"hologram-kimbap","place":"","storage":"Fridge",
        "purchasedAt":773100000}],"history":[],"dismissedToBuy":[],"counterIDs":[]}
        """.replacingOccurrences(of: "\n", with: "")
        let snap = try #require(FridgeStore.decodeSnapshot(Data(json.utf8)))
        // 미지 글리프는 스냅샷 전체 격리가 아니라 .generic 폴백으로 끝난다.
        #expect(snap.ingredients.first?.glyph == .generic)
    }

    @Test func toBuyDedupesCaseInsensitive() {
        let history = [
            RemovalLog(name: "Milk", glyph: .milk, daysAgo: 1, wasted: false),
            RemovalLog(name: "milk", glyph: .milk, daysAgo: 3, wasted: false),
            RemovalLog(name: "Egg", glyph: .egg, daysAgo: 2, wasted: false),
        ]
        let store = FridgeStore(ingredients: [], recipes: [], history: history)
        let names = store.toBuy.map(\.name)
        #expect(names.count == 2)
        #expect(names.first == "Milk")   // 빈도 우선(2회), 표기는 최근 로그 원문
    }

    // MARK: canonicalID 정규화 매칭 (교차 표기 — 양파↔onion)

    private func ingredient(_ name: String, daysLeft: Int = 3, glyph: FoodGlyph = .generic) -> Ingredient {
        Ingredient(name: name, category: "Veg", daysLeft: daysLeft,
                   quantity: Quantity(value: 1, unit: .piece), glyph: glyph)
    }

    @Test func toBuyExcludesInStockAcrossLocaleNames() {
        // '양파'로 소진한 이력 + 'onion' 재고 — 같은 캐논(onion)이므로 쇼핑리스트에 안 뜬다.
        let store = FridgeStore(ingredients: [ingredient("onion", glyph: .onion)],
                                recipes: [],
                                history: [RemovalLog(name: "양파", glyph: .onion, daysAgo: 2, wasted: false)])
        #expect(store.ingredients.first?.canonicalID == "onion")   // 로드 시 승격
        #expect(store.history.first?.canonicalID == "onion")
        #expect(store.toBuy.isEmpty)
    }

    @Test func skipBuyExcludesAcrossLocaleNames() {
        // 재고 없이 '양파' 이력만 → 원래 쇼핑리스트에 뜬다. 'Onion'(영문)으로 스킵하면 같은 캐논으로 제외.
        let store = FridgeStore(ingredients: [], recipes: [],
                                history: [RemovalLog(name: "양파", glyph: .onion, daysAgo: 2, wasted: false)])
        #expect(store.toBuy.contains { $0.glyph == .onion })
        store.skipBuy("Onion")
        #expect(!store.toBuy.contains { $0.glyph == .onion })
    }

    @Test func legacyDecodeResolvesCanonicalIDOnLoad() throws {
        // canonicalID 필드가 없는 레거시 재료·이력 — 디코드 직후엔 nil, 스토어 로드(마이그레이션)에서 승격.
        let legacy = """
        {"ingredients":[{"id":"3E29D5C3-99D5-44A5-BB80-1E1B62F0A6E0","name":"onion","category":"Veg",
        "expiresAt":773236800,"amount":"1","glyph":"onion","place":"","storage":"Fridge",
        "purchasedAt":773100000}],
        "history":[{"id":"3E29D5C3-99D5-44A5-BB80-1E1B62F0A6E1","name":"양파","glyph":"onion",
        "removedAt":773100000,"wasted":false}],
        "dismissedToBuy":[],"counterIDs":[]}
        """.replacingOccurrences(of: "\n", with: "")
        let snap = try #require(FridgeStore.decodeSnapshot(Data(legacy.utf8)))
        #expect(snap.ingredients.first?.canonicalID == nil)   // 디코드 직후엔 미해석
        #expect(snap.history.first?.canonicalID == nil)
        // 스토어 로드 경로 통과 후 — 사전으로 캐논 키가 채워진다.
        let store = FridgeStore(ingredients: snap.ingredients, recipes: [], history: snap.history)
        #expect(store.ingredients.first?.canonicalID == "onion")
        #expect(store.history.first?.canonicalID == "onion")
    }

    @Test func lastSnapshotFoundAcrossLocaleNames() {
        // 'onion'을 소비 → removeLogging이 캐논을 이력에 복사. '양파'로 재입고 조회해도 스냅샷을 찾는다.
        let store = FridgeStore(ingredients: [ingredient("onion", glyph: .onion)], recipes: [], history: [])
        store.eat(store.ingredients.first { $0.name == "onion" }!)
        let snap = store.lastSnapshot(named: "양파")
        #expect(snap?.name == "onion")
        #expect(snap?.canonicalID == "onion")
    }

    @Test func addReleasesDismissAcrossLocaleNames() {
        // 'Onion' 스킵 후, '양파'를 추가하면 같은 캐논이라 '이번엔 안 사기'가 해제된다.
        let store = FridgeStore(ingredients: [], recipes: [],
                                history: [RemovalLog(name: "onion", glyph: .onion, daysAgo: 2, wasted: false)])
        store.skipBuy("Onion")
        #expect(!store.toBuy.contains { $0.glyph == .onion })
        store.add(ingredient("양파", glyph: .onion))
        // 재고가 생겼고 스킵도 풀렸다 — 캐논(onion) 기준.
        #expect(store.ingredients.contains { $0.canonicalID == "onion" })
    }

    // MARK: 스캔 일괄 추가 상한 + 임박 승격 (시임 수정 Fix3·Fix4)

    @Test func batchAddCapsCounterToCapacityMostUrgentFirst() {
        let store = FridgeStore(ingredients: [], recipes: [], history: [])
        // day 15..1 (i=14가 가장 임박) — 15개 일괄(스캔) 추가.
        let items = (0..<15).map { i in
            Ingredient(name: "Item\(i)", category: "Veg", daysLeft: 15 - i,
                       quantity: Quantity(value: 1, unit: .piece), glyph: .generic)
        }
        store.add(contentsOf: items)
        #expect(store.ingredients.count == 15)
        #expect(store.counterIngredients.count <= 6)                    // 상한 준수
        // 최임박 6개(day 1..6)만 작업대에 — counterIngredients는 임박순.
        #expect(store.counterIngredients.map(\.effectiveDaysLeft) == [1, 2, 3, 4, 5, 6])
    }

    // MARK: 카테고리 필터 (냉장고 칩 행 — 순수 로직)

    /// 카테고리별 재료 — 글리프가 필터 키를 정한다(저장 category 문자열이 아니라).
    private func categorized(_ glyph: FoodGlyph, _ name: String, category: String = "Other") -> Ingredient {
        Ingredient(name: name, category: category, daysLeft: 3,
                   quantity: Quantity(value: 1, unit: .piece), glyph: glyph)
    }

    private var mixedItems: [Ingredient] {
        [categorized(.leaf, "Lettuce"), categorized(.onion, "Onion"), categorized(.tomato, "Tomato"),
         categorized(.meat, "Beef", category: "Meat · Beef"),   // 레거시 자유 문자열 — 글리프로 흡수
         categorized(.milk, "Milk"), categorized(.apple, "Apple")]
    }

    @Test func filterReturnsOnlyMatchingCategory() {
        let items = mixedItems
        let veg = FridgeCategoryFilter.apply("Veg", to: items)
        #expect(veg.map(\.name) == ["Lettuce", "Onion", "Tomato"])   // 입력 정렬 순서 보존
        #expect(FridgeCategoryFilter.apply(nil, to: items).count == items.count)
        #expect(FridgeCategoryFilter.apply("Seafood", to: items).isEmpty)
    }

    @Test func bucketsCountPresentCategoriesInCanonicalOrder() {
        let buckets = FridgeCategoryFilter.buckets(of: mixedItems)
        // 재고에 있는 것만, 캐논 순서(Veg → Fruit → Dairy → Meat)로.
        #expect(buckets.map(\.category) == ["Veg", "Fruit", "Dairy", "Meat"])
        #expect(buckets.map(\.count) == [3, 1, 1, 1])
        #expect(buckets.map(\.count).reduce(0, +) == mixedItems.count)   // 합 = 전체(누락 카테고리 없음)
        #expect(FridgeCategoryFilter.buckets(of: []).isEmpty)
    }

    @Test func legacyCategoryStringFoldsIntoGlyphCategory() {
        // "Meat · Beef"로 저장된 레거시 재료도 Meat 칩 하나로 묶인다(칩 파편화 방지).
        let beef = categorized(.meat, "Beef", category: "Meat · Beef")
        #expect(FridgeCategoryFilter.key(of: beef) == "Meat")
        #expect(FridgeCategoryFilter.apply("Meat", to: [beef]).count == 1)
    }

    @Test func resolvedClearsFilterWhenCategoryEmpties() {
        let items = mixedItems
        #expect(FridgeCategoryFilter.resolved("Dairy", in: items) == "Dairy")
        // 마지막 유제품이 사라지면 전체로 되돌아간다(빈 화면에 가두지 않는다).
        let withoutDairy = items.filter { FridgeCategoryFilter.key(of: $0) != "Dairy" }
        #expect(FridgeCategoryFilter.resolved("Dairy", in: withoutDairy) == nil)
        #expect(FridgeCategoryFilter.resolved("Veg", in: []) == nil)
        #expect(FridgeCategoryFilter.resolved(nil, in: items) == nil)
    }

    @Test func promoteUrgentSwapsInMoreUrgentWhenCounterFull() {
        // day 10..15 fresh 6개 — init에서 작업대가 이 6개로 찬다.
        let fresh = (0..<6).map { i in
            Ingredient(name: "Fresh\(i)", category: "Veg", daysLeft: 10 + i,
                       quantity: Quantity(value: 1, unit: .piece), glyph: .generic)
        }
        let store = FridgeStore(ingredients: fresh, recipes: [], history: [])
        #expect(store.counterIngredients.count == 6)

        // 스캔으로 더 임박한 재료 추가 — 작업대가 이미 6개라 등재 안 되고 냉장고에만(Fix3).
        let urgent = Ingredient(name: "Urgent", category: "Veg", daysLeft: 1,
                                quantity: Quantity(value: 1, unit: .piece), glyph: .generic)
        store.add(contentsOf: [urgent])
        #expect(!store.counterIngredients.contains { $0.id == urgent.id })

        store.promoteUrgent()
        #expect(store.counterIngredients.contains { $0.id == urgent.id })   // 승격됨
        #expect(store.counterIngredients.count == 6)                        // 총원 유지(교체)
        // 교체 수 ≤ 2 — 가장 여유로운 fresh 하나(day 15)만 빠진다.
        #expect(store.counterIngredients.filter { $0.name.hasPrefix("Fresh") }.count == 5)
    }
}
