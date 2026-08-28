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

    @Test func decodesSnapshotWithRemovedCookStepKeys() throws {
        // 단계 체크리스트 제거 전에 저장된 파일 — CookSession에 더 이상 없는 steps·completedSteps 키가 남아 있다.
        // 모르는 키는 무시되고 진행 중 세션(이름·개수·예약 재료)은 그대로 살아야 한다.
        let json = """
        {"schemaVersion":2,"ingredients":[],"history":[],"dismissedToBuy":[],"counterIDs":[],
        "activeCook":{"recipeName":"Bibimbap","startedAt":773236800,"count":3,
        "steps":["chop","stir"],"completedSteps":[0],
        "usedIDs":["3E29D5C3-99D5-44A5-BB80-1E1B62F0A6DF"]}}
        """.replacingOccurrences(of: "\n", with: "")
        let snap = try #require(FridgeStore.decodeSnapshot(Data(json.utf8)))
        let cook = try #require(snap.activeCook)
        #expect(cook.recipeName == "Bibimbap")
        #expect(cook.count == 3)
        #expect(cook.minutes == nil)              // 없던 필드는 nil — 공유 카드가 시간 줄을 생략한다
        #expect(cook.usedIDs?.count == 1)         // 예약(되돌릴 수 있는 재료)은 온전히 보존
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

    /// 이력 없는 삭제(정정)도 6초 undo 창을 연다(룰⑧) — 단, 이력 장부를 만들지 않는다.
    /// 로그를 만들면 낭비율·쇼핑리스트가 오염돼 "이력 없는 삭제"라는 함수 정의가 깨진다.
    @Test func removeOpensUndoWithoutWritingHistory() {
        let store = makeStore()
        let target = store.sorted[0]
        let ingBefore = store.ingredients
        let counterBefore = store.counterIDs

        store.remove(target)
        #expect(!store.ingredients.contains(where: { $0.id == target.id }))
        #expect(store.history.isEmpty)                      // 통계 오염 없음
        guard case .removed(let name)? = store.pendingUndo?.kind else {
            Issue.record("삭제 후 undo 창은 .removed여야 한다")
            return
        }
        #expect(name == target.name)

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

    /// `resetAllData()`가 실제로 지우는 것들(2026-08, 37차 — 게스트→계정 전환 보존 불변식의 절반).
    /// `RootGateView.reconcileDataOwner`가 **다른 계정으로 전환**(`DataOwner.shouldWipe` == true)할
    /// 때만 부르는 함수라, 이 계약이 무엇을 지우는지 고정해 두면 "언제 부르는가"(아래
    /// `DataOwnerTests`)와 합쳐 전체 그림이 완성된다. 지시문이 지목한 네 데이터셋(ingredients·
    /// history·manualToBuy·activeCook)을 전부 확인한다 — `history`는 `cook()`만으로는 안 쌓인다
    /// (소비 확정은 `finishCooking()`이 한다, §요리 완료)는 점에 유의해 Item0을 실제로 완주시키고,
    /// Item1로 두 번째 세션을 새로 열어 activeCook도 함께 채운다(둘이 서로 다른 재료라 충돌 없음).
    @Test func resetAllDataClearsEveryDataset() {
        let store = makeStore()
        let recipe0 = Recipe.userRecipe(name: "Test0", ingredientNames: ["Item0"], minutes: 10, steps: [])
        store.addUserRecipe(recipe0)
        store.cook(RecipeRecommender.result(for: recipe0, ingredients: store.sorted))
        store.finishCooking()   // Item0 소비 확정 — history에 실제로 한 줄 남는다(activeCook은 다시 nil)
        #expect(!store.history.isEmpty)
        #expect(!store.userRecipes.isEmpty)

        let recipe1 = Recipe.userRecipe(name: "Test1", ingredientNames: ["Item1"], minutes: 10, steps: [])
        store.cook(RecipeRecommender.result(for: recipe1, ingredients: store.sorted))
        _ = store.addToBuy(name: "Milk")
        #expect(store.activeCook != nil)
        #expect(!store.manualToBuy.isEmpty)
        #expect(!store.ingredients.isEmpty)

        store.resetAllData()

        #expect(store.ingredients.isEmpty)
        #expect(store.history.isEmpty)
        #expect(store.manualToBuy.isEmpty)
        #expect(store.activeCook == nil)
        #expect(store.userRecipes.isEmpty)
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
        let a = Recipe.userRecipe(name: "A", ingredientNames: ["Item0"], minutes: 10)
        let b = Recipe.userRecipe(name: "B", ingredientNames: ["Item1"], minutes: 20)
        store.cook(RecipeRecommender.result(for: a, ingredients: store.sorted))
        let sessionA = store.activeCook

        store.cook(RecipeRecommender.result(for: b, ingredients: store.sorted))   // 교체
        #expect(store.activeCook?.recipeName == "B")

        store.undoPending()   // B 발주 취소 → A 세션 전체(시작 시각·예약 재료까지) 복원
        #expect(store.activeCook == sessionA)
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

    // MARK: 직접 담은 장보기 항목 (manualToBuy)

    @Test func manualToBuyLeadsTheList() {
        // 이력 제안이 있어도 직접 담은 항목이 **맨 위**에 온다(내가 적은 게 먼저 읽혀야 한다).
        let store = FridgeStore(ingredients: [], recipes: [],
                                history: [RemovalLog(name: "Milk", glyph: .milk, daysAgo: 1, wasted: false)])
        #expect(store.addToBuy(name: "양파"))
        let list = store.toBuy
        // 수동 줄의 표기는 저장 원문이 아니라 **현재 로케일 표제어**다(displayName(for:)) —
        // 리터럴로 못 박으면 테스트 호스트 언어에 따라 갈린다.
        let onion = IngredientLexicon.shared.entry(id: "onion")?.displayName ?? "양파"
        #expect(list.map(\.name) == [onion, "Milk"])
        #expect(list.map(\.manual) == [true, false])
    }

    @Test func manualRowRendersTheLexiconDisplayNameForItsCanon() {
        // 사전 타일로 담은 줄은 담을 때의 로케일에 박제되지 않는다 — 캐논이 있고 저장 표기가
        // 사전 표제어와 일치하면 표시 시점의 표제어로 다시 푼다(같은 시트의 타일과 표기 일치).
        let store = FridgeStore(ingredients: [], recipes: [], history: [])
        #expect(store.addToBuy(name: "양파", canonicalID: "onion", glyph: .onion))
        let row = store.toBuy.first
        #expect(row?.key == "onion")
        #expect(row?.name == IngredientLexicon.shared.entry(id: "onion")?.displayName)
        #expect(store.manualToBuy.first?.name == "양파")   // 저장값 자체는 담을 때 원문 그대로
        // 패인(`ShoppingListContent.items`)은 `toBuy`가 아니라 `manualToBuy`를 직접 읽는다 —
        // 그 경로가 쓰는 `displayName(for:)`도 같은 답을 내야 화면·토스트·타일 표기가 안 갈린다.
        if let item = store.manualToBuy.first {
            #expect(FridgeStore.displayName(for: item) == row?.name)
        }
    }

    // MARK: Bought는 자기 행의 키로 메모를 내린다 (clearToBuy)

    /// 자유 입력 줄("서울우유")은 캐논이 없어 키가 친 문자열 그대로다. 재입고(`insert`)의 자동
    /// 내리기는 냉장고 재료의 **캐논** 키("milk")로 비교하므로 이 줄을 영영 못 내리고, 같은 캐논의
    /// 다른 줄이 있으면 그쪽이 대신 내려간다 — Bought(뷰)는 행 자신의 키로 `clearToBuy`를 불러야 한다.
    @Test func boughtClearsTheTappedFreeTextRowNotItsCanonSibling() {
        let store = FridgeStore(ingredients: [], recipes: [], history: [])
        #expect(store.addToBuy(name: "서울우유", canonicalID: nil, canonicalIsFinal: true))  // 자유 입력
        #expect(store.addToBuy(name: "우유", canonicalID: "milk"))                          // 사전 타일
        // Bought 재입고 — insert의 자동 내리기가 캐논("milk") 줄을 지운다("샀다"는 사실은 같으니 맞다).
        store.add(Ingredient(name: "서울우유", category: "Dairy",
                             expiresAt: Ingredient.day(offset: 3), glyph: .milk))
        // 뷰가 행 키로 부르는 명시 내리기 — 자유 입력 줄이 반드시 함께 내려간다.
        store.clearToBuy(key: "서울우유")
        #expect(store.manualToBuy.isEmpty,
                "Bought를 누른 자유 입력 줄이 목록에 남으면 안 된다")
    }

    /// 멱등 — 이미 내려간 키로 또 불러도(insert가 먼저 지운 캐논 줄 등) 아무 일도 없다.
    @Test func clearToBuyIsIdempotent() {
        let store = FridgeStore(ingredients: [], recipes: [], history: [])
        #expect(store.addToBuy(name: "우유", canonicalID: "milk"))
        store.clearToBuy(key: "milk")
        #expect(store.manualToBuy.isEmpty)
        store.clearToBuy(key: "milk")   // no-op — 크래시·persist 낭비 없음
        #expect(store.manualToBuy.isEmpty)
    }

    @Test func manualRowKeepsUserNotationEvenWhenItHasACanon() {
        // FREQUENT 칩은 이력 원문("서울우유1L")을 이름으로 싣고 캐논은 milk다 — 캐논만 보고
        // 무조건 덮으면 사용자가 적은 그 표기를 잃는다. 사전 표제어와 다르면 그대로 둔다.
        let store = FridgeStore(ingredients: [], recipes: [], history: [])
        #expect(store.addToBuy(name: "서울우유1L"))
        let row = store.toBuy.first
        #expect(row?.key == "milk")           // 캐논은 잡혔지만
        #expect(row?.name == "서울우유1L")     // 표기는 사용자 것 그대로
    }

    @Test func isPristineCountsManualToBuyAsUserData() {
        // isPristine이 true면 호출부가 확인 없이 loadSampleData()(복구 불가)를 실행한다 —
        // 냉장고·이력이 비어도 손으로 적은 장보기 메모가 있으면 '데이터 전무'가 아니다.
        let store = FridgeStore(ingredients: [], recipes: [], history: [])
        #expect(store.isPristine)
        #expect(store.addToBuy(name: "양파"))
        #expect(!store.isPristine, "메모만 있는 사용자에게 샘플 CTA가 그대로 뜬다 — 탭하면 메모가 지워진다")
        store.skipBuy(key: "onion")
        #expect(store.isPristine)   // 메모를 내리면 다시 첫 실행 상태
    }

    @Test func manualToBuyAbsorbsDuplicateSuggestion() {
        // 같은 품목이 이력 제안으로도 잡히면 수동이 흡수 — 한 줄로만 뜬다(표기가 달라도 캐논 동일).
        let store = FridgeStore(ingredients: [], recipes: [],
                                history: [RemovalLog(name: "양파", glyph: .onion, daysAgo: 2, wasted: false)])
        #expect(store.addToBuy(name: "onion"))
        let onions = store.toBuy.filter { $0.glyph == .onion }
        #expect(onions.count == 1)
        #expect(onions.first?.manual == true)
        #expect(!store.addToBuy(name: "양파"))   // 이미 담김 — 중복 추가 no-op
    }

    @Test func manualToBuyBypassesInStockFilter() {
        // 지금 있어도 더 사려고 손으로 적은 것 — 재고 유무로 지우지 않는다(파생 제안과 정반대 전제).
        let store = FridgeStore(ingredients: [ingredient("onion", glyph: .onion)], recipes: [], history: [])
        #expect(store.addToBuy(name: "onion"))
        #expect(store.toBuy.contains { $0.glyph == .onion && $0.manual })
    }

    @Test func addingStockClearsManualToBuy() {
        // Add 알약(재입고) = 샀다 — 어느 입구로 들어와도 담아둔 메모는 내려간다.
        let store = FridgeStore(ingredients: [], recipes: [], history: [])
        store.addToBuy(name: "양파")
        store.add(ingredient("onion", glyph: .onion))
        #expect(store.manualToBuy.isEmpty)
        #expect(store.toBuy.isEmpty)
    }

    // MARK: 티켓 Short 행 → To buy 원탭 (addMissingToBuy)

    /// 레시피 항목 리터럴 — 담기는 **표시명이 아니라 항목**을 받는다(`ref`가 있어야 표기를 풀 수 있다).
    private func item(_ en: String, ko: String? = nil, ref: String? = nil) -> Recipe.Item {
        Recipe.Item(ref: ref, en: en, ko: ko)
    }

    @Test func addMissingResolvesRecipeNamesToCanonicalKeys() throws {
        // 항목의 표시명은 캐논이 아니다 — 여기서 해석해 담지 않으면 같은 품목이 표기별로 여러 줄
        // 쌓이고, 재입고가 그 메모를 못 내린다.
        let store = FridgeStore(ingredients: [], recipes: [], history: [])
        #expect(store.addMissingToBuy([item("Green onion"), item("Onion", ko: "양파")]) == 2)
        #expect(Set(store.toBuy.map(\.key)) == ["green-onion", "onion"])
        // '대파'로 재입고 = 샀다 — 같은 캐논(green-onion)이라 표기가 달라도 그 줄이 내려간다.
        store.add(ingredient("대파", glyph: .onion))
        #expect(store.toBuy.map(\.key) == ["onion"])
    }

    @Test func addMissingPrefersTheRefOverTheWrittenName() throws {
        // `ref`가 있으면 표기를 읽지 않는다 — "pork (or beef)"를 이름으로 풀면 포함 매칭이 괄호
        // **안**의 beef에 먼저 걸린다(시드 실측). ref는 그 함정을 원천적으로 건너뛴다.
        let store = FridgeStore(ingredients: [], recipes: [], history: [])
        #expect(store.addMissingToBuy([item("pork (or beef)", ref: "pork")]) == 1)
        #expect(store.toBuy.map(\.key) == ["pork"])
    }

    /// 사전에 없는 서술형 라인은 **자기 줄로** 담겨야 한다.
    ///
    /// 이게 이 라운드의 실질 결함이었다: 괄호만 떼고 store에 넘기면 store가 그 이름으로 포함 매칭을
    /// 한 번 더 해서 "paprika powder"가 `bell-pepper`(파프리카)에 붙는다. 그 키가 이미 담겨 있으면
    /// 반환이 false가 되어 **파프리카 가루는 목록에 들어가지도 않는데** 호출부는 성공으로 읽는다.
    /// 시드 전수로 en 8종·ko 12종이 이 경로였다.
    @Test func addMissingKeepsUnresolvedItemsOffOtherIngredientsKeys() throws {
        let store = FridgeStore(ingredients: [], recipes: [], history: [])
        #expect(store.addMissingToBuy([item("bell pepper (diced)", ref: "bell-pepper"),
                                       item("paprika powder (or mild chili powder)")]) == 2)
        let keys = store.toBuy.map(\.key)
        #expect(keys.contains("bell-pepper"))
        #expect(keys.contains("paprika powder"))   // 남의 키에 흡수되지 않고 자기 줄로 남는다
        #expect(store.toBuy.count == 2)
    }

    @Test func addMissingFallsBackToLowercasedKeyOutsideTheLexicon() throws {
        // 사전 밖 표기(커스텀 레시피의 자유 항목)도 담긴다 — 키는 소문자 원문, 글리프는 매칭 결과.
        let store = FridgeStore(ingredients: [], recipes: [], history: [])
        #expect(store.addMissingToBuy([item("Qqzz")]) == 1)
        let row = try #require(store.toBuy.first)
        #expect(row.key == "qqzz")
        #expect(row.name == "Qqzz")            // 사용자(레시피) 표기 그대로
        #expect(row.glyph == FoodGlyph.match("Qqzz"))
        #expect(row.glyph == .generic)                     // 매칭 실패 = generic 폴백
        #expect(store.manualToBuy.first?.canonicalID == nil)
    }

    @Test func addMissingCountsOnlyNewRows() {
        // 반환값은 **새로 담긴 수**다 — 호출부(티켓 알약)가 0이면 성공 햅틱을 울리지 않는다.
        let store = FridgeStore(ingredients: [], recipes: [], history: [])
        #expect(store.addMissingToBuy([item("Onion", ko: "양파"), item("Carrot", ko: "당근")]) == 2)
        #expect(store.addMissingToBuy([item("onion"), item("carrot")]) == 0)   // 같은 캐논 — 중복 no-op
        #expect(store.addMissingToBuy([item("onion"), item("Potato", ko: "감자")]) == 1)   // 새것만 센다
        #expect(store.toBuy.count == 3)
    }

    @Test func addMissingIgnoresBlankNames() {
        // 빈 문자열·공백은 담지 않는다(레시피 데이터가 지저분해도 빈 줄을 만들지 않는다).
        let store = FridgeStore(ingredients: [], recipes: [], history: [])
        #expect(store.addMissingToBuy([item(""), item("   "), item("Onion", ko: "양파")]) == 1)
        #expect(store.toBuy.count == 1)
    }

    @Test func skipRemovesManualItemWithoutDismissing() {
        // 수동 항목의 Skip은 메모만 지운다 — 영구 제외 목록(dismissedToBuy)까지 오염시키지 않는다.
        let store = FridgeStore(ingredients: [], recipes: [], history: [])
        store.addToBuy(name: "양파")
        store.skipBuy("양파")
        #expect(store.manualToBuy.isEmpty)
        #expect(store.dismissedToBuy.isEmpty)
        #expect(store.toBuy.isEmpty)
    }

    @Test func skipRemovesManualItemThatAbsorbedSuggestion() {
        // 수동이 흡수하던 제안이 되살아나 같은 줄이 남으면 Skip이 안 먹은 것처럼 보인다 — 함께 접는다.
        let store = FridgeStore(ingredients: [], recipes: [],
                                history: [RemovalLog(name: "양파", glyph: .onion, daysAgo: 2, wasted: false)])
        store.addToBuy(name: "onion")
        store.skipBuy("onion")
        #expect(store.manualToBuy.isEmpty)
        #expect(store.toBuy.isEmpty)
    }

    // MARK: skipBuy(key:) — addToBuy와 대칭인 캐논 키 직접 전달 오버로드(이름 역조회 없음)

    @Test func skipBuyKeyOverloadMatchesNameOverloadBehavior() {
        // skipBuy(key:)는 이름을 역조회하지 않고 호출부가 넘긴 키를 그대로 쓴다 — 레거시
        // skipBuy(_:)(이름 역조회)와 최종 상태는 동일해야 한다(수동 흡수 + 제안 동반 접힘).
        let store = FridgeStore(ingredients: [], recipes: [],
                                history: [RemovalLog(name: "양파", glyph: .onion, daysAgo: 2, wasted: false)])
        #expect(store.addToBuy(name: "onion", canonicalID: "onion", glyph: .onion))
        store.skipBuy(key: "onion")
        #expect(store.manualToBuy.isEmpty)
        #expect(store.toBuy.isEmpty)
        #expect(store.dismissedToBuy.contains("onion"))   // 수동이 흡수하던 제안까지 함께 접힘
    }

    // MARK: History 세 표면의 수치 일치 (22차) — 히어로 · 30일 정산서 · 타임라인

    /// 한 이력 묶음으로 세 표면이 **같은 분류**를 쓰는지 본다.
    ///
    /// 제보("숫자끼리도 안 맞아")의 실체를 가리기 위한 테스트다. 세 표면은 창(window)이 다를 뿐
    /// 판정 기준은 하나여야 한다 — `wasted` 플래그 하나. 창 차이로 설명되지 않는 불일치가 있으면
    /// 그건 집계 버그다.
    @Test func historySurfacesShareOneClassification() {
        // 발주 소비(via)·버림·창 밖 로그를 섞은 고정 픽스처.
        let logs = [
            RemovalLog(name: "Egg", glyph: .egg, daysAgo: 0, wasted: false),
            RemovalLog(name: "Milk", glyph: .milk, daysAgo: 0, wasted: true),
            RemovalLog(name: "Beef", glyph: .meat, canonicalID: "beef",
                       removedAt: Ingredient.day(offset: -1), wasted: false, via: "Bibimbap"),
            RemovalLog(name: "Bread", glyph: .bread, daysAgo: 2, wasted: false),
            RemovalLog(name: "Apple", glyph: .apple, daysAgo: 40, wasted: true),   // 30일 창 밖
        ]
        let store = FridgeStore(ingredients: [], recipes: [], history: logs)

        // ① 히어로(이번 주) — 요일 칸의 합이 곧 고리의 분자다.
        let week = ConsumptionWeek.summary(of: store.history)
        #expect(week.days.reduce(0) { $0 + $1.eaten } == week.eaten)

        // ② 히어로 vs 타임라인 — 타임라인이 "Ate"로 그리는 줄(= !wasted)과 같은 집합이어야 한다.
        //    발주 소비(via != nil)도 타임라인에선 "Ate"이므로 히어로도 세야 한다.
        let weekStart = ConsumptionWeek.weekStart()
        let timelineAteThisWeek = store.history.filter { $0.removedAt >= weekStart && !$0.wasted }.count
        let timelineAllThisWeek = store.history.filter { $0.removedAt >= weekStart }.count
        #expect(week.eaten == timelineAteThisWeek)
        #expect(week.removed == timelineAllThisWeek)

        // ③ 30일 정산서 vs 타임라인 — 같은 플래그, 같은 창.
        let cutoff = Ingredient.day(offset: -30)
        let tallyAte = store.recentHistory.filter { !$0.wasted }.count
        let tallyTossed = store.recentHistory.filter(\.wasted).count
        #expect(tallyAte == store.history.filter { $0.removedAt >= cutoff && !$0.wasted }.count)
        #expect(tallyTossed == store.history.filter { $0.removedAt >= cutoff && $0.wasted }.count)
        #expect(tallyAte == 3)      // Egg · Beef(발주) · Bread
        #expect(tallyTossed == 1)   // Milk (Apple은 창 밖)
        #expect(store.wasteRate == 25)

        // ④ 창 밖 로그는 어느 창에도 안 샌다.
        #expect(store.recentHistory.count == 4)
        #expect(week.removed <= store.recentHistory.count)
    }

    /// 발주로 소비된 줄(`via`)이 히어로에서 빠지면 요리를 많이 한 주가 가장 나쁜 주로 보인다 —
    /// 타임라인은 그 줄을 "Ate"로 그리므로 두 표면이 정면으로 어긋난다.
    @Test func recipeConsumptionCountsAsEatenOnEverySurface() {
        let logs = [
            RemovalLog(name: "Beef", glyph: .meat, canonicalID: "beef",
                       removedAt: Ingredient.day(offset: 0), wasted: false, via: "Bibimbap"),
            RemovalLog(name: "Onion", glyph: .onion, canonicalID: "onion",
                       removedAt: Ingredient.day(offset: 0), wasted: false, via: "Bibimbap"),
        ]
        let store = FridgeStore(ingredients: [], recipes: [], history: logs)
        let week = ConsumptionWeek.summary(of: store.history)
        #expect(week.eaten == 2)
        #expect(week.eatenRate == 100)
        #expect(store.recentHistory.filter { !$0.wasted }.count == 2)
        #expect(store.wasteRate == 0)
    }

    /// 정산서의 "Cooked into recipes" 행 — 발주(레시피 티켓)로 소비된 줄만, 그리고 **30일 창 안**에서만.
    /// `Ate`의 **부분집합**이라 두 값이 함께 성립해야 한다(같은 줄을 두 행이 각자 세지 않는다).
    @Test func cookedCountIsTheRecipeSliceOfAteInsideTheThirtyDayWindow() {
        let logs = [
            RemovalLog(name: "Beef", glyph: .meat, canonicalID: "beef",
                       removedAt: Ingredient.day(offset: 0), wasted: false, via: "Bibimbap"),
            RemovalLog(name: "Onion", glyph: .onion, canonicalID: "onion",
                       removedAt: Ingredient.day(offset: -3), wasted: false, via: "Bibimbap"),
            // 직접 먹음 판정 — 출처가 없으니 요리 행에는 안 선다(그래도 Ate에는 선다).
            RemovalLog(name: "Egg", glyph: .egg, daysAgo: 1, wasted: false),
            // 버림 — 출처가 없고, 있더라도 요리로 세면 안 된다.
            RemovalLog(name: "Milk", glyph: .milk, daysAgo: 2, wasted: true),
            // 창 밖(40일 전) 발주 소비 — 헤더가 "past 30 days"라 이 행도 같은 창을 써야 한다.
            RemovalLog(name: "Pork", glyph: .meat, canonicalID: "pork-belly",
                       removedAt: Ingredient.day(offset: -40), wasted: false, via: "Kimchi stew"),
        ]
        let store = FridgeStore(ingredients: [], recipes: [], history: logs)

        #expect(store.cookedCount == 2)
        // 부분집합 불변식 — 요리 행이 먹음 행을 넘을 수는 없다.
        let ate = store.recentHistory.filter { !$0.wasted }.count
        #expect(ate == 3)
        #expect(store.cookedCount <= ate)
        // 출처가 붙은 버림이 생겨도 요리로 새지 않는다(현재 프로덕션 경로엔 없지만 방어를 잠근다).
        let tainted = FridgeStore(ingredients: [], recipes: [],
                                  history: [RemovalLog(name: "Beef", glyph: .meat,
                                                       removedAt: Ingredient.day(offset: 0),
                                                       wasted: true, via: "Bibimbap")])
        #expect(tainted.cookedCount == 0)
    }

    // MARK: skipBuyUndoable — 밀어서 삭제 전용(21차). 결과는 skipBuy와 같고 되돌리기 창만 더한다.

    @Test func swipeRemovalRestoresTheRowInItsOriginalPlace() {
        // 되돌린 줄이 목록 맨 끝으로 튀면 "되돌렸다"가 아니라 "다시 담았다"로 읽힌다 —
        // 가운데 줄을 지웠다가 되돌려 자리까지 회복되는지 본다.
        let store = FridgeStore(ingredients: [], recipes: [], history: [])
        #expect(store.addToBuy(name: "양파", canonicalID: "onion", glyph: .onion))
        #expect(store.addToBuy(name: "Milk", canonicalID: "milk", glyph: .milk))
        #expect(store.addToBuy(name: "Egg", canonicalID: "egg", glyph: .egg))
        let before = store.manualToBuy.map(\.matchKey)
        #expect(before == ["onion", "milk", "egg"])

        store.skipBuyUndoable(key: "milk")
        #expect(store.manualToBuy.map(\.matchKey) == ["onion", "egg"])
        #expect(store.pendingUndo != nil)   // 밀기는 오발이 잦다 — 창이 열려야 한다

        store.undoPending()
        #expect(store.manualToBuy.map(\.matchKey) == before)   // 제자리로
        #expect(store.pendingUndo == nil)
    }

    @Test func swipeRemovalUndoAlsoReleasesTheDismissKeyItAdded() {
        // 수동이 흡수하던 제안이 있으면 skipBuy가 영구 제외에도 넣는다 — 되돌리기는 그것까지 풀어야
        // 같은 품목이 다시 제안으로 잡힐 수 있다(안 풀면 되돌려도 반쪽만 복구된다).
        let store = FridgeStore(ingredients: [], recipes: [],
                                history: [RemovalLog(name: "양파", glyph: .onion, daysAgo: 2, wasted: false)])
        #expect(store.addToBuy(name: "onion", canonicalID: "onion", glyph: .onion))
        store.skipBuyUndoable(key: "onion")
        #expect(store.dismissedToBuy.contains("onion"))

        store.undoPending()
        #expect(!store.dismissedToBuy.contains("onion"))
        #expect(store.manualToBuy.map(\.matchKey) == ["onion"])
    }

    @Test func swipeRemovalKeepsADismissKeyThatWasAlreadyThere() {
        // 이번 호출이 **새로** 넣은 키만 되돌린다 — 원래 제외돼 있던 품목까지 풀면
        // 되돌리기가 사용자가 예전에 내린 결정을 조용히 뒤집는다.
        let store = FridgeStore(ingredients: [], recipes: [],
                                history: [RemovalLog(name: "양파", glyph: .onion, daysAgo: 2, wasted: false)])
        store.skipBuy(key: "onion")                    // 먼저 제안을 접어 둔다
        #expect(store.dismissedToBuy.contains("onion"))
        #expect(store.addToBuy(name: "onion", canonicalID: "onion", glyph: .onion))

        store.skipBuyUndoable(key: "onion")
        store.undoPending()
        #expect(store.dismissedToBuy.contains("onion"))   // 옛 결정은 그대로
        #expect(store.manualToBuy.map(\.matchKey) == ["onion"])
    }

    @Test func swipeRemovalOfANonManualKeyOpensNoUndoWindow() {
        // 되돌릴 줄이 없으면 창도 없다 — 빈 토스트가 6초 떠 있는 상태를 만들지 않는다.
        let store = FridgeStore(ingredients: [], recipes: [],
                                history: [RemovalLog(name: "양파", glyph: .onion, daysAgo: 2, wasted: false)])
        store.skipBuyUndoable(key: "onion")             // 파생 제안일 뿐 수동 항목이 아니다
        #expect(store.pendingUndo == nil)
        #expect(store.dismissedToBuy.contains("onion"))  // 동작 자체는 skipBuy 그대로
    }

    @Test func skipBuyKeyOverloadRemovesManualItemWithoutDismissing() {
        // key 버전도 순수 수동 항목(이력 제안과 안 겹침)은 영구 제외 목록을 오염시키지 않는다
        // (skipRemovesManualItemWithoutDismissing의 key 버전 — 회귀 방지).
        let store = FridgeStore(ingredients: [], recipes: [], history: [])
        #expect(store.addToBuy(name: "양파", canonicalID: "onion", glyph: .onion))
        store.skipBuy(key: "onion")
        #expect(store.manualToBuy.isEmpty)
        #expect(store.dismissedToBuy.isEmpty)
        #expect(store.toBuy.isEmpty)
    }

    @Test func toBuyRowKeyDrivesSkipBuyKeyForDerivedSuggestion() throws {
        // ShoppingListView의 빼기(✕) 버튼은 이제 이름을 넘기지 않고 store.toBuy가 실어 나른 `key`로
        // skipBuy(key:)를 호출한다 — 그 축이 실제로 맞물리는지 스토어 레벨에서 검증
        // (뷰 유닛 테스트가 없는 영역이라 이 계약이 유일한 회귀 방지선이다).
        let store = FridgeStore(ingredients: [], recipes: [],
                                history: [RemovalLog(name: "양파", glyph: .onion, daysAgo: 2, wasted: false)])
        let row = try #require(store.toBuy.first)
        #expect(row.key == "onion")
        #expect(!row.manual)
        store.skipBuy(key: row.key)
        #expect(store.toBuy.isEmpty)
    }

    @Test func toBuyRowKeyDrivesSkipBuyKeyForManualItem() throws {
        // 같은 계약을 수동 항목 경로에서도 확인 — key는 matchKey 그대로다.
        let store = FridgeStore(ingredients: [], recipes: [], history: [])
        #expect(store.addToBuy(name: "onion", canonicalID: "onion", glyph: .onion))
        let row = try #require(store.toBuy.first)
        #expect(row.key == "onion")
        #expect(row.manual)
        store.skipBuy(key: row.key)
        #expect(store.manualToBuy.isEmpty)
        #expect(store.toBuy.isEmpty)
    }

    // MARK: 티켓의 부족 재료 → 살 것 (OrderMemoCard "Add to To buy")

    @Test func missingTicketItemsLandInToBuyWithCanonicalKeys() throws {
        // 카드가 하는 일을 그대로 태운다: result.missing → toBuyEntry → addToBuy.
        // 표시명("gim (seaweed sheets)"·"water (or anchovy stock)")을 store에 그대로 넘기면
        // 이름 역조회(포함 매칭)가 괄호 **안** 단어에 붙어 엉뚱한 품목 키가 박힌다
        // (실측: 앞은 우연히 맞고, 뒤는 anchovy로 간다). 뷰 유닛 테스트가 없는 영역이라 여기가 방지선.
        //
        // **물은 아예 `missing`에 안 남는다.** `isStaple`이 담기와 같은 3단 해석을 쓰므로
        // `water (or anchovy stock)`은 괄호를 뗀 뒤 머리말 `water`(사전상 staple)로 잡혀 상비재로
        // 분류된다. 예전엔 `isStaple`이 정확 일치만 봐서 이 줄이 Short에 뜬 뒤 담을 때만 `water`로
        // 풀렸고, 그래서 장보기 목록에 "물"이 적혔다 — 이 테스트가 그 동작을 기대값으로 못 박고 있었다.
        let recipe = Recipe(id: "gimbap-test",
                            name: Recipe.LocalizedName(en: "Gimbap", ko: nil),
                            cuisine: nil, minutes: 30,
                            ingredients: [Recipe.Item(ref: "seaweed", en: "gim (seaweed sheets)", ko: "김밥용 김"),
                                          Recipe.Item(ref: nil, en: "water (or anchovy stock)", ko: nil)],
                            steps: Recipe.LocalizedSteps(en: [], ko: nil), isUser: nil)
        let store = FridgeStore(ingredients: [], recipes: [recipe], history: [])
        let result = RecipeRecommender.result(for: recipe, ingredients: [])
        #expect(result.missing.count == 1, "상비재(물)는 부족 재료로 세지 않는다")
        #expect(result.missing.allSatisfy { !$0.en.contains("water") })

        for item in result.missing {
            let entry = RecipeRecommender.toBuyEntry(for: item)
            store.addToBuy(name: entry.name, canonicalID: entry.canonicalID, glyph: entry.glyph)
        }
        #expect(Set(store.manualToBuy.map(\.matchKey)) == ["seaweed"],
                "상비재는 장보기 목록에 들어가지 않는다")

        let gim = try #require(store.manualToBuy.first { $0.matchKey == "seaweed" })
        #expect(gim.glyph == .seaweed)      // 사전 글리프 — 이름 추측이 아니다
        #expect(!gim.name.contains("("))    // 목록에 조리 지시가 아니라 재료명이 남는다
    }

    // MARK: 자주 쓰는 재료 칩 (검색 시트 빈 쿼리 상태)

    @Test func frequentIngredientsRankByHistoryCount() {
        // 빈도 내림차순, 동률이면 이름순. 표기는 최근 로그 원문. 이력 상위(4종)가 limit(12)에 못 미치면
        // 시드가 부족분을 항상 채운다 — 이 4종은 전부 시드 풀에도 있는 재료라 정확히 12개까지 채워진다
        // (이전 계단식 회귀: 이력이 3종에서 4종이 되는 순간 칩이 12개→4개로 급감하던 버그의 회귀 테스트).
        let history = [
            RemovalLog(name: "Milk", glyph: .milk, daysAgo: 1, wasted: false),
            RemovalLog(name: "milk", glyph: .milk, daysAgo: 3, wasted: false),
            RemovalLog(name: "Egg", glyph: .egg, daysAgo: 2, wasted: false),
            RemovalLog(name: "Tofu", glyph: .tofu, daysAgo: 4, wasted: false),
            RemovalLog(name: "Onion", glyph: .onion, daysAgo: 5, wasted: false),
        ]
        let store = FridgeStore(ingredients: [], recipes: [], history: history)
        let chips = store.frequentIngredients()
        #expect(chips.map(\.name).first == "Milk")   // 2회로 최다
        #expect(Set(chips.prefix(4).map(\.key)) == ["milk", "egg", "tofu", "onion"])   // 이력 상위 4종
        #expect(chips.count == 12)                    // 계단식 급감 없이 limit까지 채운다
        #expect(Set(chips.map(\.key)).count == chips.count)   // 시드 보충에도 중복 없음
    }

    @Test func frequentIngredientsIgnoreStockAndSkip() {
        // 제안(derivedToBuy)과 달리 재고 보유·'이번엔 안 사기'로 지우지 않는다 — 자주 쓰는 건 또 산다.
        let history = (0..<5).map { _ in RemovalLog(name: "양파", glyph: .onion, daysAgo: 2, wasted: false) }
        let store = FridgeStore(ingredients: [ingredient("onion", glyph: .onion)],
                                recipes: [], history: history)
        store.skipBuy("onion")
        #expect(store.toBuy.isEmpty)             // 제안 목록에선 빠졌지만
        #expect(store.frequentIngredients().contains { $0.key == "onion" })   // 칩에는 남는다
    }

    @Test func frequentIngredientsFallBackToSeedAndCap() {
        // 이력이 부족한 초기 사용자 — 이력 종수와 무관하게 큐레이션 시드로 부족분을 항상 채우되
        // 상한(limit)은 넘지 않는다.
        let store = FridgeStore(ingredients: [], recipes: [], history: [])
        let seeded = store.frequentIngredients()
        #expect(seeded.count == 12)
        #expect(seeded.map(\.key) == Array(FridgeStore.frequentSeedIDs.prefix(12)))
        #expect(store.frequentIngredients(limit: 5).count == 5)   // 상한 준수
        // 이력 1종만 있어도 시드가 뒤를 채우고, 중복은 생기지 않는다.
        let one = FridgeStore(ingredients: [], recipes: [],
                              history: [RemovalLog(name: "양파", glyph: .onion, daysAgo: 1, wasted: false)])
        let mixed = one.frequentIngredients()
        #expect(mixed.first?.key == "onion")
        #expect(mixed.count == 12)
        #expect(Set(mixed.map(\.key)).count == mixed.count)
    }

    @Test func tappingSuggestedItemAbsorbsItIntoManual() {
        // 시트 탭의 실제 경로(뷰가 게이팅하지 않는다) — 파생 제안만 떠 있던 품목을 담으면 흡수된다.
        let store = FridgeStore(ingredients: [], recipes: [],
                                history: [RemovalLog(name: "양파", glyph: .onion, daysAgo: 2, wasted: false)])
        #expect(store.toBuy.map(\.manual) == [false])          // 지금은 제안 한 줄
        #expect(store.addToBuy(name: "onion", canonicalID: "onion", glyph: .onion))
        let list = store.toBuy
        #expect(list.count == 1)                                // 두 줄로 갈라지지 않고
        #expect(list.first?.manual == true)                     // 수동이 흡수
        #expect(!store.addToBuy(name: "onion", canonicalID: "onion", glyph: .onion))   // 재탭은 no-op
    }

    @Test func manualToBuySurvivesSnapshotRoundTrip() throws {
        let item = FridgeStore.ManualBuyItem(name: "양파", canonicalID: "onion", glyph: .onion)
        let snap = FridgeStore.Snapshot(
            schemaVersion: FridgeStore.currentSchemaVersion,
            ingredients: [], history: [], dismissedToBuy: [], counterIDs: [], activeCook: nil,
            userRecipes: nil, archivedAte: nil, archivedTossed: nil, manualToBuy: [item])
        let decoded = try #require(FridgeStore.decodeSnapshot(try JSONEncoder().encode(snap)))
        #expect(decoded.manualToBuy == [item])
        #expect(decoded.manualToBuy?.first?.matchKey == "onion")
    }

    @Test func legacySnapshotHasNoManualToBuy() throws {
        // 구버전 파일엔 필드 자체가 없다 — 옵셔널+기본 nil 규약(디코드 실패로 통째 격리되면 안 된다).
        let legacy = """
        {"ingredients":[],"history":[],"dismissedToBuy":[],"counterIDs":[]}
        """
        let snap = try #require(FridgeStore.decodeSnapshot(Data(legacy.utf8)))
        #expect(snap.manualToBuy == nil)
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

    /// `FridgeView`의 필터 자동 해제는 이 함수만 호출한다 — 뷰에 같은 판단이 중복되지 않으므로
    /// 여기서 검증하는 규칙이 곧 화면 동작이다.
    @Test func resolvedClearsFilterWhenCategoryEmpties() {
        let items = mixedItems
        #expect(FridgeCategoryFilter.resolved("Dairy", in: items) == "Dairy")
        // 마지막 유제품이 사라지면 전체로 되돌아간다(빈 화면에 가두지 않는다).
        let withoutDairy = items.filter { FridgeCategoryFilter.key(of: $0) != "Dairy" }
        #expect(FridgeCategoryFilter.resolved("Dairy", in: withoutDairy) == nil)
        #expect(FridgeCategoryFilter.resolved("Veg", in: []) == nil)
        #expect(FridgeCategoryFilter.resolved(nil, in: items) == nil)
    }

    @Test func resolvedClearsFilterWhenNewItemLandsOutsideIt() {
        // Dairy 필터를 켠 채 고기를 추가 — 화면이 그대로면 "추가가 안 됐다"로 읽힌다.
        let fish = categorized(.fish, "Salmon")
        let after = mixedItems + [fish]
        #expect(FridgeCategoryFilter.resolved("Dairy", in: after, added: [fish.id]) == nil)

        // 필터 안쪽에 추가되면 유지 — 굳이 넓힐 이유가 없다(추가분이 이미 보인다).
        let yogurt = categorized(.yogurt, "Yogurt")
        #expect(FridgeCategoryFilter.resolved("Dairy", in: mixedItems + [yogurt],
                                              added: [yogurt.id]) == "Dairy")
        // 여러 개를 한꺼번에(영수증 스캔) 추가해 하나라도 필터 안이면 유지.
        #expect(FridgeCategoryFilter.resolved("Dairy", in: mixedItems + [yogurt, fish],
                                              added: [yogurt.id, fish.id]) == "Dairy")
        // 추가가 없는 변화(먹음·버림)는 ②를 판정하지 않는다 — 재고만 남아 있으면 필터 유지.
        #expect(FridgeCategoryFilter.resolved("Dairy", in: mixedItems, added: []) == "Dairy")
    }

    /// 이름 수정으로 카테고리만 바뀌는 경우 — id가 그대로라 뷰의 감지 키가 id였을 땐 훅이 아예 돌지
    /// 않아 필터가 빈 카테고리를 계속 가리켰다(재고가 가득한데 빈 상태 화면). 감지 키에 카테고리를
    /// 섞어 변화로 잡히는지, 그리고 그때 `resolved`가 전체로 풀어 주는지 함께 고정한다.
    @Test func renameThatChangesCategoryIsDetectedAndClearsFilter() {
        let milk = categorized(.milk, "Milk")
        var renamed = milk
        renamed.name = "Beef"
        renamed.glyph = .meat            // FridgeStore.update가 이름 변경 때 다시 파생시키는 값
        renamed.category = renamed.glyph.categoryLabel

        #expect(renamed.id == milk.id)   // 전제 — id는 그대로다
        #expect(FridgeCategoryFilter.changeKey(of: renamed) != FridgeCategoryFilter.changeKey(of: milk))

        let before = [milk, categorized(.leaf, "Lettuce")]
        let after = [renamed, categorized(.leaf, "Lettuce")]
        #expect(FridgeCategoryFilter.resolved("Dairy", in: before) == "Dairy")
        #expect(FridgeCategoryFilter.resolved("Dairy", in: after) == nil)
        // 같은 재료가 그대로면 키도 그대로 — 불필요한 재판정을 만들지 않는다.
        #expect(FridgeCategoryFilter.changeKey(of: milk) == FridgeCategoryFilter.changeKey(of: milk))
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
