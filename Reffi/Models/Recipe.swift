import Foundation

/// 레시피 — 번들 시드(recipes-seed.json)·사용자 커스텀·(향후) AI 생성이 모두 이 한 모델로 흐른다.
/// **코드에 레시피를 하드코딩하지 않는다**(프로젝트 규칙) — 데이터는 항상 번들/영속화/생성 소스에서 온다.
/// 이름·단계는 영-한 이중언어(en 필수, ko 선택) — 표시 시점에 로케일로 고른다.
struct Recipe: Identifiable, Codable, Equatable {

    /// 재료 한 줄 — `ref`는 정본 재료 사전(`IngredientLexicon`)의 canonical ID.
    /// ref가 있으면 매칭은 ID 동일성으로만(부분문자열 오탐 원천 차단), 없으면 표기 정규화 비교.
    struct Item: Codable, Equatable {
        var ref: String?
        var en: String
        var ko: String?

        /// 로케일 표시명.
        var displayName: String { Recipe.isKorean ? (ko ?? en) : en }
    }

    var id: String                 // 시드는 슬러그("beef-bulgogi"), 커스텀·AI는 UUID 문자열
    var name: LocalizedName
    var cuisine: String?
    var minutes: Int
    var ingredients: [Item]
    var steps: LocalizedSteps
    /// 사용자 커스텀 여부 — 커스텀만 편집·삭제 가능(시드 생략 시 nil = false).
    var isUser: Bool?
    /// 공급 출처 — AI 생성이면 "ai". 시드/레거시/커스텀은 nil(Codable-안전: 키 없으면 nil).
    /// 기본값 nil이라 기존 memberwise 호출·시드 로더·userRecipe 팩토리는 불변으로 컴파일된다.
    var origin: String? = nil

    struct LocalizedName: Codable, Equatable {
        var en: String
        var ko: String?
    }

    struct LocalizedSteps: Codable, Equatable {
        var en: [String]
        var ko: [String]?
    }

    static var isKorean: Bool {
        Locale.current.language.languageCode?.identifier == "ko"
    }

    // MARK: - 표시 접근자

    var displayName: String { Self.isKorean ? (name.ko ?? name.en) : name.en }
    var displaySteps: [String] {
        if Self.isKorean, let ko = steps.ko, !ko.isEmpty { return ko }
        return steps.en
    }
    var isUserRecipe: Bool { isUser ?? false }
    /// AI 생성 레시피 여부 — 배지·필터 배선용(후속 UI 에이전트).
    var isAI: Bool { origin == "ai" }

    /// 히어로 대표 모티프 — 첫 번째 비상비 재료의 글리프에서 파생.
    var glyph: FoodGlyph {
        for item in ingredients {
            let key = item.ref ?? item.en
            if IngredientLexicon.shared.isStaple(key) { continue }
            let g = FoodGlyph.match(item.displayName)
            if g != .generic { return g }
        }
        return .generic
    }

    /// 커스텀 레시피 생성 편의 — 현재 로케일 표기를 en 슬롯에 담는다(en은 필수 캐논).
    static func userRecipe(name: String, ingredientNames: [String], minutes: Int,
                           steps: [String]) -> Recipe {
        Recipe(id: UUID().uuidString,
               name: LocalizedName(en: name, ko: nil),
               cuisine: nil,
               minutes: minutes,
               ingredients: ingredientNames.map { raw in
                   let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                   return Item(ref: IngredientLexicon.shared.canonicalID(for: trimmed),
                               en: trimmed, ko: nil)
               },
               steps: LocalizedSteps(en: steps, ko: nil),
               isUser: true)
    }
}
