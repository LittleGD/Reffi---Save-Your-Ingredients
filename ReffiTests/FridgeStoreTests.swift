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

    // MARK: 직접 담은 장보기 항목 (manualToBuy)

    @Test func manualToBuyLeadsTheList() {
        // 이력 제안이 있어도 직접 담은 항목이 **맨 위**에 온다(내가 적은 게 먼저 읽혀야 한다).
        let store = FridgeStore(ingredients: [], recipes: [],
                                history: [RemovalLog(name: "Milk", glyph: .milk, daysAgo: 1, wasted: false)])
        #expect(store.addToBuy(name: "양파"))
        let list = store.toBuy
        #expect(list.map(\.name) == ["양파", "Milk"])
        #expect(list.map(\.manual) == [true, false])
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
