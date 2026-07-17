import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// AI 레시피 파이프라인 — **AI 증강 전용** 소스 체인. 시드/커스텀은 이미 상시 랭킹 풀
/// (`FridgeStore.recipes`)이라 엔진에서 제외했다: 엔진은 "냉장고 재료로 새 레시피를 만들어
/// 캐시에 얹는" 일만 한다. 소스 교체·추가 시 뷰/스토어는 손대지 않는다 — `RecipeEngine.standard`만 갱신.
///
/// 로드맵(2026-07):
///  1차  온디바이스 Foundation Models(iOS 26+, Apple Intelligence 기기) — @Generable 구조화 생성. 동의 불필요.
///  2차  Supabase Edge Function 프록시(recipe-generate) → 서버 측 모델 폴백 체인. **명시 동의 게이트**.
protocol RecipeSuggesting {
    var sourceID: String { get }
    /// 이 소스가 현 기기·현 시점에 실사용 가능한가(기기 지원·동의·네트워크는 호출 실패로 판정).
    var isAvailable: Bool { get }
    /// 요청 기반 레시피 생성. 실패는 throw — 엔진이 다음 소스로 폴백한다.
    func suggest(_ request: RecipeGenerationRequest) async throws -> [Recipe]
}

// MARK: - 요청 · 취향

/// 생성 요청 — 보유 재료·취향·개수·로케일을 한 값으로. 재료는 엔진/소스가 컨텍스트 예산에 맞춰 캡한다.
struct RecipeGenerationRequest {
    var ingredients: [Ingredient]
    var preferences: AIRecipePreferences
    var count: Int
    var locale: String            // "ko" | "en"

    /// 프롬프트/바디용 보유 재료명(canonical displayName, 최대 12) — 4K 컨텍스트 예산 준수.
    var ingredientNames: [String] {
        let lex = IngredientLexicon.shared
        return ingredients.prefix(12).map { ing in
            if let id = ing.canonicalID, let e = lex.entry(id: id) { return e.displayName }
            return lex.entry(for: ing.name)?.displayName ?? ing.name
        }
    }
}

/// AI 생성용 취향 스냅샷 — 프롬프트/클라우드 바디에 실리는 **원문 선호**와, 사후 알레르기
/// 검증용 정규화 키를 함께 나른다. FridgeStore는 ProfileStore에 결합하지 않고 호출부(UI)가
/// `init(profile:)`로 주입한다(`rankedRecipes` ↔ `RecipePreferences`와 같은 패턴).
struct AIRecipePreferences: Equatable {
    var cuisines: [String]        // 선호 요리 스타일(원문 rawValue) — 프롬프트 힌트·클라우드 바디
    var allergies: [String]       // 알레르기(사용 금지) — 프롬프트 금지어·사후 검증 근거
    var disliked: [String]        // 비선호(사용 금지) — 프롬프트 금지어
    var favorites: [String]       // 좋아하는 재료 — 클라우드 바디(서버 랭킹 힌트)

    static let none = AIRecipePreferences(cuisines: [], allergies: [], disliked: [], favorites: [])

    /// 사후 알레르기 검증용 정규화 키(canonical ID 우선, 실패 시 소문자 원문) — 한/영 표기 무관.
    var allergenIDs: Set<String> { RecipePreferences.normalize(allergies) }

    /// 프롬프트 '사용 금지' 재료(알레르기 + 비선호, 표시 원문 유지).
    var avoidNames: [String] { allergies + disliked }
}

extension AIRecipePreferences {
    /// 프로필(§5.2) → AI 취향 스냅샷. cuisines는 rawValue(원문), 재료 태그는 사용자 원문 그대로.
    init(profile: ProfileStore) {
        self.init(cuisines: CuisineStyle.allCases.filter { profile.cuisines.contains($0) }.map(\.rawValue),
                  allergies: profile.allergies,
                  disliked: profile.disliked,
                  favorites: profile.favorites)
    }
}

// MARK: - 순수 매핑(테스트 가능)

/// FM `@Generable` / 클라우드 JSON을 `Recipe`로 잇는 중간 표현. 순수 매핑(ref 역조회·알레르기
/// 폐기·origin·형태 검증)을 FoundationModels 타입과 분리해 시뮬레이터·테스트에서도 검증 가능하게 한다.
struct DraftRecipe {
    var nameEN: String
    var nameKO: String?
    var minutes: Int
    var ingredientsEN: [String]
    var ingredientsKO: [String]?
    var stepsEN: [String]
    var stepsKO: [String]?

    /// `Recipe`로 매핑. ref는 `lexicon.canonicalID` 역조회(미매치 nil — no-ref 정확 일치 규칙 유지),
    /// origin "ai", cuisine nil, id "ai-"+UUID. **알레르겐이 하나라도 포함되면 nil**(사후 폐기, 안전 P0).
    /// 최소 형태 검증(이름·재료·단계 비어있지 않음)에 실패해도 nil. minutes는 5~120으로 클램프.
    func toRecipe(allergenIDs: Set<String>, lexicon: IngredientLexicon = .shared) -> Recipe? {
        let name = nameEN.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }

        let items: [Recipe.Item] = ingredientsEN.enumerated().compactMap { idx, rawEN in
            let en = rawEN.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !en.isEmpty else { return nil }
            var ko: String? = nil
            if let kos = ingredientsKO, idx < kos.count {
                let k = kos[idx].trimmingCharacters(in: .whitespacesAndNewlines)
                ko = k.isEmpty ? nil : k
            }
            return Recipe.Item(ref: lexicon.canonicalID(for: en), en: en, ko: ko)
        }
        guard !items.isEmpty else { return nil }

        let cleanStepsEN = stepsEN.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !cleanStepsEN.isEmpty else { return nil }
        let cleanStepsKO = stepsKO?.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }

        // 사후 알레르기 검증 — ref/이름(한·영) 어느 쪽이든 알레르겐이면 폐기.
        if Self.containsAllergen(items, allergenIDs: allergenIDs, lexicon: lexicon) { return nil }

        let koName = nameKO?.trimmingCharacters(in: .whitespacesAndNewlines)
        return Recipe(id: "ai-" + UUID().uuidString,
                      name: Recipe.LocalizedName(en: name, ko: (koName?.isEmpty == false ? koName : nil)),
                      cuisine: nil,
                      minutes: min(max(minutes, 5), 120),
                      ingredients: items,
                      steps: Recipe.LocalizedSteps(en: cleanStepsEN,
                                                   ko: (cleanStepsKO?.isEmpty == false ? cleanStepsKO : nil)),
                      isUser: false,
                      origin: "ai")
    }

    /// 재료 목록에 알레르겐이 포함되는지 — ref → canonical(en) → 소문자 원문(en·ko) 순으로 검사.
    /// (`RecipePreferences.normalize`의 캐논/소문자 규칙과 대칭이라 표기 무관 비교가 산다.)
    static func containsAllergen(_ items: [Recipe.Item], allergenIDs: Set<String>,
                                 lexicon: IngredientLexicon = .shared) -> Bool {
        guard !allergenIDs.isEmpty else { return false }
        return items.contains { item in
            if let ref = item.ref, allergenIDs.contains(ref) { return true }
            if let id = lexicon.canonicalID(for: item.en), allergenIDs.contains(id) { return true }
            if allergenIDs.contains(IngredientLexicon.norm(item.en)) { return true }
            if let ko = item.ko, allergenIDs.contains(IngredientLexicon.norm(ko)) { return true }
            return false
        }
    }
}

// MARK: - 1차: 온디바이스(FoundationModels, iOS 26+)

/// 온디바이스 생성 — FoundationModels `LanguageModelSession` + @Generable 스키마.
/// 동의 불필요(재료가 기기를 떠나지 않음). 배포 타깃 iOS 18이라 `#if canImport` + `@available` 이중 가드.
struct OnDeviceModelRecipeSource: RecipeSuggesting {
    let sourceID = "on-device-fm"

    /// Apple Intelligence 기기·모델 다운로드 완료·기능 켜짐이어야 available. 시뮬레이터·미지원 기기는 false.
    var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return SystemLanguageModel.default.availability == .available
        }
        return false
        #else
        return false
        #endif
    }

    func suggest(_ request: RecipeGenerationRequest) async throws -> [Recipe] {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return try await generate(request)
        }
        throw RecipeEngineError.sourceUnavailable(sourceID)
        #else
        throw RecipeEngineError.sourceUnavailable(sourceID)
        #endif
    }

    #if canImport(FoundationModels)
    /// 회당 1개 생성을 count회 반복(4K 토큰 예산상 안전) — 직전 결과를 프롬프트에 '중복 금지'로 넣는다.
    @available(iOS 26.0, *)
    private func generate(_ request: RecipeGenerationRequest) async throws -> [Recipe] {
        guard SystemLanguageModel.default.availability == .available else {
            throw RecipeEngineError.sourceUnavailable(sourceID)
        }
        let allergenIDs = request.preferences.allergenIDs
        let session = LanguageModelSession(instructions: Self.instructions)
        session.prewarm()

        var out: [Recipe] = []
        let target = max(1, min(request.count, 2))
        for _ in 0..<target {
            let prompt = Self.prompt(for: request, avoiding: out.map(\.name.en))
            // guardrailViolation·unsupportedLanguageOrLocale·exceededContextWindowSize 등은 throw → 엔진 폴백.
            let response = try await session.respond(to: prompt, generating: GeneratedRecipe.self)
            let g = response.content
            let draft = DraftRecipe(nameEN: g.nameEN, nameKO: g.nameKO, minutes: g.minutes,
                                    ingredientsEN: g.ingredientsEN, ingredientsKO: g.ingredientsKO,
                                    stepsEN: g.stepsEN, stepsKO: g.stepsKO)
            if let recipe = draft.toRecipe(allergenIDs: allergenIDs) { out.append(recipe) }
        }
        guard !out.isEmpty else { throw RecipeEngineError.emptyResult(sourceID) }
        return out
    }

    private static let instructions = """
    You are a home-cooking assistant. Suggest ONE real, common dish that mainly uses the \
    ingredients the user already has. Prefer simple everyday recipes people actually make. \
    Never invent unsafe or fictional dishes. Fill every field of the schema in both English and Korean.
    """

    @available(iOS 26.0, *)
    private static func prompt(for request: RecipeGenerationRequest, avoiding priorNames: [String]) -> String {
        var lines: [String] = []
        lines.append("Ingredients on hand: " + request.ingredientNames.joined(separator: ", "))
        let cuisines = request.preferences.cuisines.prefix(2)
        if !cuisines.isEmpty {
            lines.append("Preferred cuisine: " + cuisines.joined(separator: ", "))
        }
        let avoid = request.preferences.avoidNames
        if !avoid.isEmpty {
            lines.append("Never use these ingredients (allergy/dislike): " + avoid.joined(separator: ", "))
        }
        if !priorNames.isEmpty {
            lines.append("Do not repeat these dishes: " + priorNames.joined(separator: ", "))
        }
        lines.append("Use as many on-hand ingredients as possible. Keep it a real, common dish.")
        return lines.joined(separator: "\n")
    }
    #endif
}

#if canImport(FoundationModels)
/// 가이드 생성 스키마 — FoundationModels가 이 구조를 채우도록 강제한다(자유 텍스트 파싱 없음).
@available(iOS 26.0, *)
@Generable
struct GeneratedRecipe {
    @Guide(description: "Dish name in English") var nameEN: String
    @Guide(description: "Dish name in Korean") var nameKO: String
    @Guide(description: "Total minutes, 5-120") var minutes: Int
    @Guide(description: "3-8 ingredient names in English, lowercase") var ingredientsEN: [String]
    @Guide(description: "Same ingredients in Korean, same order") var ingredientsKO: [String]
    @Guide(description: "4-6 short cooking steps in English") var stepsEN: [String]
    @Guide(description: "Same steps in Korean") var stepsKO: [String]
}
#endif

// MARK: - 2차: 클라우드 프록시(Supabase Edge Function)

/// 클라우드 생성 — Supabase Edge Function `recipe-generate` 경유(키는 서버 secrets).
/// **동의 없으면 절대 호출 안 됨**(`AIConsent.cloudEnabled` 게이트). 재료 외부 전송은 Apple 5.1.2(i) 대상.
struct CloudProxyRecipeSource: RecipeSuggesting {
    let sourceID = "cloud-proxy"

    /// 세션 액세스 토큰 공급 — 기본은 Supabase 세션(익명 포함). 테스트·대체 주입 가능.
    var accessTokenProvider: () async -> String? = { await AuthStore.currentAccessToken() }
    /// 응답 타임아웃(초).
    var timeout: TimeInterval = 8

    /// 동의가 켜져 있으면 후보(네트워크·토큰 부재는 호출 실패로 판정 → 엔진 폴백).
    var isAvailable: Bool { AIConsent.cloudEnabled }

    func suggest(_ request: RecipeGenerationRequest) async throws -> [Recipe] {
        guard AIConsent.cloudEnabled else { throw RecipeEngineError.sourceUnavailable(sourceID) }
        guard let token = await accessTokenProvider() else { throw RecipeEngineError.sourceUnavailable(sourceID) }

        let url = AuthStore.supabaseURL.appendingPathComponent("functions/v1/recipe-generate")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = timeout
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue(AuthStore.anonKey, forHTTPHeaderField: "apikey")
        req.httpBody = try Self.encodeBody(request)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw RecipeEngineError.badResponse(sourceID) }
        // 429/503/그 외 비 200 → throw(엔진 폴백). 타임아웃은 URLSession이 throw.
        guard http.statusCode == 200 else { throw RecipeEngineError.httpStatus(http.statusCode) }

        let recipes = try Self.decode(data, allergenIDs: request.preferences.allergenIDs)
        guard !recipes.isEmpty else { throw RecipeEngineError.emptyResult(sourceID) }
        return recipes
    }

    // MARK: 순수 인코딩/디코딩(테스트 가능)

    /// 요청 바디 — `{"locale","count","ingredients":[{id,name}],"preferences":{cuisines,allergies,disliked,favorites}}`.
    struct RequestBody: Encodable, Equatable {
        struct Ing: Encodable, Equatable { var id: String?; var name: String }
        struct Prefs: Encodable, Equatable {
            var cuisines: [String]; var allergies: [String]
            var disliked: [String]; var favorites: [String]
        }
        var locale: String
        var count: Int
        var ingredients: [Ing]
        var preferences: Prefs
    }

    static func makeBody(_ request: RecipeGenerationRequest, lexicon: IngredientLexicon = .shared) -> RequestBody {
        let ings = request.ingredients.prefix(12).map { ing -> RequestBody.Ing in
            let id = ing.canonicalID ?? lexicon.canonicalID(for: ing.name)
            let name = id.flatMap { lexicon.entry(id: $0)?.displayName } ?? ing.name
            return RequestBody.Ing(id: id, name: name)
        }
        let p = request.preferences
        return RequestBody(locale: request.locale, count: request.count,
                           ingredients: Array(ings),
                           preferences: .init(cuisines: p.cuisines, allergies: p.allergies,
                                              disliked: p.disliked, favorites: p.favorites))
    }

    static func encodeBody(_ request: RecipeGenerationRequest) throws -> Data {
        try JSONEncoder().encode(makeBody(request))
    }

    private struct ResponseBody: Decodable { var recipes: [Recipe] }

    /// 응답 200 바디 → [Recipe]. origin "ai" 강제, 빈 ref 역조회 보강, 알레르겐 폐기.
    /// `recipes` 키가 없는 오류 JSON은 throw(엔진 폴백).
    static func decode(_ data: Data, allergenIDs: Set<String>,
                       lexicon: IngredientLexicon = .shared) throws -> [Recipe] {
        let body = try JSONDecoder().decode(ResponseBody.self, from: data)
        return body.recipes.compactMap { sanitize($0, allergenIDs: allergenIDs, lexicon: lexicon) }
    }

    /// 서버 레시피 보정 — origin "ai" 강제, ref가 빈 항목만 canonicalID 역조회 보강, 알레르겐 포함 시 nil.
    static func sanitize(_ recipe: Recipe, allergenIDs: Set<String>,
                         lexicon: IngredientLexicon = .shared) -> Recipe? {
        var r = recipe
        r.origin = "ai"
        r.ingredients = r.ingredients.map { item in
            var it = item
            if it.ref == nil { it.ref = lexicon.canonicalID(for: it.en) }
            return it
        }
        if DraftRecipe.containsAllergen(r.ingredients, allergenIDs: allergenIDs, lexicon: lexicon) { return nil }
        return r
    }
}

// MARK: - 엔진

enum RecipeEngineError: Error, Equatable {
    case sourceUnavailable(String)
    case emptyResult(String)
    case badResponse(String)
    case httpStatus(Int)
}

/// 소스 우선순위대로 시도, 첫 성공(비어있지 않음)을 채택. 모두 실패하면 빈 배열(호출부가 조용히 무시).
struct RecipeEngine {
    var sources: [RecipeSuggesting]

    func recipes(for request: RecipeGenerationRequest) async -> [Recipe] {
        for source in sources where source.isAvailable {
            do {
                let result = try await source.suggest(request)
                if !result.isEmpty { return result }
            } catch {
                continue   // 다음 소스로 폴백
            }
        }
        return []
    }

    /// 표준 구성 — 온디바이스(무동의) → 클라우드(동의 게이트). 시드는 상시 랭킹 풀이라 엔진에서 제외.
    static let standard = RecipeEngine(sources: [
        OnDeviceModelRecipeSource(),
        CloudProxyRecipeSource(),
    ])
}
