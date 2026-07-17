import Testing
import Foundation
@testable import Reffi

// MARK: - 공용 헬퍼

/// 호출 순서 기록용 참조 상자 — fake 소스가 호출 순서를 남긴다.
private final class CallBox {
    private(set) var ids: [String] = []
    func record(_ id: String) { ids.append(id) }
}

/// 결정적 fake 소스 — 가용성·성공/실패를 주입하고 호출을 기록한다(FM/네트워크 없이 폴백 검증).
private struct FakeSource: RecipeSuggesting {
    let sourceID: String
    let isAvailable: Bool
    let result: Result<[Recipe], Error>
    let box: CallBox
    func suggest(_ request: RecipeGenerationRequest) async throws -> [Recipe] {
        box.record(sourceID)
        return try result.get()
    }
}

private enum FakeError: Error { case boom }

private func makeRecipe(nameEN: String, origin: String? = nil) -> Recipe {
    Recipe(id: UUID().uuidString,
           name: Recipe.LocalizedName(en: nameEN, ko: nil),
           cuisine: nil, minutes: 10,
           ingredients: [Recipe.Item(ref: nil, en: "x", ko: nil)],
           steps: Recipe.LocalizedSteps(en: ["step"], ko: nil),
           isUser: nil, origin: origin)
}

private func makeRequest() -> RecipeGenerationRequest {
    RecipeGenerationRequest(ingredients: [], preferences: .none, count: 2, locale: "en")
}

// MARK: - 엔진 폴백

/// 소스 우선순위·폴백·중단(첫 성공) 규약 — 시뮬레이터엔 FM/네트워크가 없어 이 경로가 실주행 경로다.
struct RecipeEnginePipelineTests {

    @Test func fallsBackToNextSourceOnFailure() async {
        let box = CallBox()
        let a = FakeSource(sourceID: "A", isAvailable: true, result: .failure(FakeError.boom), box: box)
        let b = FakeSource(sourceID: "B", isAvailable: true,
                           result: .success([makeRecipe(nameEN: "eggs")]), box: box)
        let out = await RecipeEngine(sources: [a, b]).recipes(for: makeRequest())
        #expect(out.map(\.name.en) == ["eggs"])
        #expect(box.ids == ["A", "B"])           // A 실패 → B 호출
    }

    @Test func stopsAtFirstSuccess() async {
        let box = CallBox()
        let a = FakeSource(sourceID: "A", isAvailable: true,
                           result: .success([makeRecipe(nameEN: "a")]), box: box)
        let b = FakeSource(sourceID: "B", isAvailable: true,
                           result: .success([makeRecipe(nameEN: "b")]), box: box)
        let out = await RecipeEngine(sources: [a, b]).recipes(for: makeRequest())
        #expect(out.map(\.name.en) == ["a"])
        #expect(box.ids == ["A"])                // A 성공 → B 미호출
    }

    @Test func skipsUnavailableSources() async {
        let box = CallBox()
        let a = FakeSource(sourceID: "A", isAvailable: false,
                           result: .success([makeRecipe(nameEN: "a")]), box: box)
        let b = FakeSource(sourceID: "B", isAvailable: true,
                           result: .success([makeRecipe(nameEN: "b")]), box: box)
        let out = await RecipeEngine(sources: [a, b]).recipes(for: makeRequest())
        #expect(out.map(\.name.en) == ["b"])
        #expect(box.ids == ["B"])                // A는 isAvailable=false라 미호출
    }

    @Test func emptySuccessFallsThrough() async {
        let box = CallBox()
        let a = FakeSource(sourceID: "A", isAvailable: true, result: .success([]), box: box)
        let b = FakeSource(sourceID: "B", isAvailable: true,
                           result: .success([makeRecipe(nameEN: "b")]), box: box)
        let out = await RecipeEngine(sources: [a, b]).recipes(for: makeRequest())
        #expect(out.map(\.name.en) == ["b"])
        #expect(box.ids == ["A", "B"])           // 빈 결과는 성공으로 치지 않음
    }

    @Test func allFailingReturnsEmpty() async {
        let box = CallBox()
        let a = FakeSource(sourceID: "A", isAvailable: true, result: .failure(FakeError.boom), box: box)
        let out = await RecipeEngine(sources: [a]).recipes(for: makeRequest())
        #expect(out.isEmpty)                      // 모두 실패 → 빈 배열(호출부 조용히 무시)
    }
}

// MARK: - 순수 매핑(Draft → Recipe)

/// FM/클라우드 공용 매핑 — ref 역조회·알레르기 폐기·origin·형태 검증(FM 타입 없이 검증).
struct DraftRecipeMappingTests {

    @Test func mapsRefsOriginAndClampsMinutes() {
        let draft = DraftRecipe(nameEN: "Tofu Stew", nameKO: "두부찌개", minutes: 500,
                                ingredientsEN: ["tofu", "onion", "xyzzy widget"],
                                ingredientsKO: ["두부", "양파", "가상재료"],
                                stepsEN: ["boil", "serve"], stepsKO: ["끓이기", "담기"])
        let r = try! #require(draft.toRecipe(allergenIDs: []))
        #expect(r.isAI && r.origin == "ai")
        #expect(r.id.hasPrefix("ai-"))
        #expect(r.cuisine == nil)
        #expect(r.minutes == 120)                        // 5~120 클램프
        #expect(r.ingredients[0].ref == "tofu")
        #expect(r.ingredients[1].ref == "onion")
        #expect(r.ingredients[2].ref == nil)             // 미매치 → nil(no-ref 규칙 유지)
        #expect(r.ingredients[1].ko == "양파")
        #expect(r.name.ko == "두부찌개")
    }

    @Test func discardsWhenAllergenPresent() {
        let allergens = RecipePreferences.normalize(["계란"])   // 한글 알레르기 → egg 캐논 정규화
        let draft = DraftRecipe(nameEN: "Omelette", nameKO: "오믈렛", minutes: 10,
                                ingredientsEN: ["egg", "milk"], ingredientsKO: nil,
                                stepsEN: ["mix", "cook"], stepsKO: nil)
        #expect(draft.toRecipe(allergenIDs: allergens) == nil)   // 사후 검증 폐기(안전 P0)
    }

    @Test func rejectsMalformedDrafts() {
        func draft(name: String, ings: [String], steps: [String]) -> DraftRecipe {
            DraftRecipe(nameEN: name, nameKO: nil, minutes: 10, ingredientsEN: ings,
                        ingredientsKO: nil, stepsEN: steps, stepsKO: nil)
        }
        #expect(draft(name: "  ", ings: ["a"], steps: ["s"]).toRecipe(allergenIDs: []) == nil)  // 이름 공백
        #expect(draft(name: "X", ings: [], steps: ["s"]).toRecipe(allergenIDs: []) == nil)      // 재료 없음
        #expect(draft(name: "X", ings: ["a"], steps: []).toRecipe(allergenIDs: []) == nil)      // 단계 없음
    }
}

// MARK: - 클라우드 파서/바디

/// CloudProxy 순수 파서·인코더 — 정상/오류 픽스처, ref 보강, origin 강제, 알레르기 폐기, 바디 계약.
struct CloudProxyParsingTests {

    private let goodJSON = """
    {"recipes":[{"id":"srv-1","name":{"en":"Fried Rice","ko":"볶음밥"},"minutes":15,
     "ingredients":[{"ref":null,"en":"rice","ko":"밥"},{"ref":"egg","en":"egg","ko":"계란"}],
     "steps":{"en":["fry"],"ko":["볶기"]},"origin":"ai"}]}
    """.data(using: .utf8)!

    @Test func parsesAndBackfillsRefs() throws {
        let recipes = try CloudProxyRecipeSource.decode(goodJSON, allergenIDs: [])
        #expect(recipes.count == 1)
        #expect(recipes[0].isAI)
        #expect(recipes[0].ingredients[0].ref == "rice")   // 빈 ref 역조회 보강
        #expect(recipes[0].ingredients[1].ref == "egg")    // 서버가 준 ref 유지
    }

    @Test func forcesOriginEvenIfServerOmits() throws {
        let json = """
        {"recipes":[{"id":"x","name":{"en":"Boiled Water","ko":null},"minutes":10,
         "ingredients":[{"ref":null,"en":"water","ko":null}],"steps":{"en":["boil"],"ko":null}}]}
        """.data(using: .utf8)!
        let recipes = try CloudProxyRecipeSource.decode(json, allergenIDs: [])
        #expect(recipes.first?.origin == "ai")             // 서버가 생략해도 강제
    }

    @Test func dropsAllergenRecipes() throws {
        let recipes = try CloudProxyRecipeSource.decode(goodJSON,
                                                        allergenIDs: RecipePreferences.normalize(["egg"]))
        #expect(recipes.isEmpty)                            // egg 포함 → compactMap 폐기
    }

    @Test func throwsOnErrorJSON() {
        let json = #"{"error":"rate_limited"}"#.data(using: .utf8)!
        #expect(throws: (any Error).self) {
            try CloudProxyRecipeSource.decode(json, allergenIDs: [])
        }
    }

    @Test func bodyIncludesPreferencesLocaleAndIngredients() throws {
        let ing = Ingredient(name: "두부", category: "Protein", daysLeft: 2,
                             quantity: Quantity(value: 1, unit: .piece), glyph: .tofu)
        let prefs = AIRecipePreferences(cuisines: ["korean"], allergies: ["peanut"],
                                        disliked: ["cilantro"], favorites: ["egg"])
        let req = RecipeGenerationRequest(ingredients: [ing], preferences: prefs, count: 2, locale: "ko")
        let data = try CloudProxyRecipeSource.encodeBody(req)
        let obj = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(obj["locale"] as? String == "ko")
        #expect(obj["count"] as? Int == 2)
        let p = try #require(obj["preferences"] as? [String: Any])
        #expect(p["allergies"] as? [String] == ["peanut"])
        #expect(p["favorites"] as? [String] == ["egg"])
        #expect(p["cuisines"] as? [String] == ["korean"])
        let ings = try #require(obj["ingredients"] as? [[String: Any]])
        #expect(ings.count == 1)
        #expect(ings[0]["id"] as? String == "tofu")        // 두부 → 캐논 ID
    }
}

// MARK: - FridgeStore AI 캐시(병합·중복·캡·라운드트립)

@MainActor
struct FridgeStoreAIRecipesTests {

    @Test func mergeDedupesAgainstSeedUserAndExisting() {
        let existing = [makeRecipe(nameEN: "Alpha")]
        let others = [makeRecipe(nameEN: "Kimchi Stew")]     // 시드/커스텀 역할
        let incoming = [makeRecipe(nameEN: "kimchi stew"),   // 시드와 충돌(대소문자 무관) → 폐기
                        makeRecipe(nameEN: "Alpha"),          // 기존 AI와 충돌 → 폐기
                        makeRecipe(nameEN: "Beta")]           // 신규
        let merged = FridgeStore.mergedAIRecipes(existing: existing, incoming: incoming,
                                                 others: others, cap: 30)
        #expect(merged.map(\.name.en) == ["Beta", "Alpha"])  // 신규만 prepend
    }

    @Test func mergeEnforcesCapDroppingOldest() {
        let existing = (0..<30).map { makeRecipe(nameEN: "old\($0)") }
        let merged = FridgeStore.mergedAIRecipes(existing: existing,
                                                 incoming: [makeRecipe(nameEN: "new")],
                                                 others: [], cap: 30)
        #expect(merged.count == 30)
        #expect(merged.first?.name.en == "new")              // 최신 앞
        #expect(!merged.contains { $0.name.en == "old29" })  // 가장 오래된(뒤) 제거
    }

    @Test func recipesPoolIncludesAICache() {
        let ai = makeRecipe(nameEN: "AI Dish", origin: "ai")
        let store = FridgeStore(ingredients: [], recipes: [], history: [], aiRecipes: [ai])
        #expect(store.aiRecipes.count == 1)
        #expect(store.recipes.contains { $0.isAI && $0.name.en == "AI Dish" })
    }

    @Test func snapshotRoundTripsAIRecipes() throws {
        let ai = makeRecipe(nameEN: "AI Dish", origin: "ai")
        let snap = FridgeStore.Snapshot(schemaVersion: FridgeStore.currentSchemaVersion,
                                        ingredients: [], history: [], dismissedToBuy: [],
                                        counterIDs: [], activeCook: nil, userRecipes: [],
                                        archivedAte: 0, archivedTossed: 0, aiRecipes: [ai])
        let data = try JSONEncoder().encode(snap)
        let decoded = try #require(FridgeStore.decodeSnapshot(data))
        #expect(decoded.aiRecipes?.count == 1)
        #expect(decoded.aiRecipes?.first?.origin == "ai")
    }

    @Test func legacySnapshotWithoutAIRecipesDecodes() throws {
        // 구버전 파일 — aiRecipes 키 없음 → nil(레거시 디코드 안전).
        let json = #"{"ingredients":[],"history":[],"dismissedToBuy":[],"counterIDs":[]}"#.data(using: .utf8)!
        let decoded = try #require(FridgeStore.decodeSnapshot(json))
        #expect(decoded.aiRecipes == nil)
    }
}
