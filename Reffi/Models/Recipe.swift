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
    /// 조리 단계 — 화면에 그리는 경로는 없다(티켓은 단서까지, 조리법은 영상). 시드 JSON과 이미 저장된
    /// 커스텀 레시피가 이 키를 갖고 있어 **디코드 호환**을 위해 유지한다. 지우면 기존 데이터가 깨진다.
    var steps: LocalizedSteps
    /// 사용자 커스텀 여부 — 커스텀만 편집·삭제 가능(시드 생략 시 nil = false).
    var isUser: Bool?
    /// 공급 출처. AI 생성 기능이 제거되기 전에 저장한 기기에는 origin "ai"가 박힌 사용자 레시피가
    /// 아직 남아 있다 — 그 레코드가 디코드·재인코드를 왕복해도 값이 사라지지 않도록 필드만 유지한다.
    /// 새로 이 값을 채우는 경로도, 이 값을 읽는 로직도 없다(표시·분기 어디에도 쓰이지 않는다).
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
    /// `steps`는 편집기가 더 이상 입력받지 않아 기본 빈 배열이다(모델 필드는 디코드 호환으로 남아 있다).
    static func userRecipe(name: String, ingredientNames: [String], minutes: Int,
                           steps: [String] = []) -> Recipe {
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
