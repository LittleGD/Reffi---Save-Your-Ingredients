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
}
