import Foundation

/// 레시피 — 번들 시드(recipes-seed.json)와 사용자 커스텀이 모두 이 한 모델로 흐른다.
/// **코드에 레시피를 하드코딩하지 않는다**(프로젝트 규칙) — 데이터는 항상 번들/영속화 소스에서 온다.
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

    var id: String                 // 시드는 슬러그("beef-bulgogi"), 커스텀은 UUID 문자열
    var name: LocalizedName
    var cuisine: String?
    var minutes: Int
    var ingredients: [Item]
    var steps: LocalizedSteps
    /// 사용자 커스텀 여부 — 커스텀만 편집·삭제 가능(시드 생략 시 nil = false).
    var isUser: Bool?
    /// 공급 출처. 현재 앱에서 이 값을 채우는 경로는 없다 — 제거된 AI 생성 기능이 남긴 영속 데이터
    /// (origin "ai"가 박힌 사용자 레시피)를 그대로 디코드하려고 필드만 유지한다. 지우면 옛 스냅샷의
    /// 해당 레시피가 손실되므로 두되, 표시·분기 로직은 이 값을 읽지 않는다.
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
