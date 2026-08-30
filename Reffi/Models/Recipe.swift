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
    /// 요리 한 줄 소개 — 무엇이고 어느 나라 음식인가(조리 티켓 히어로 아래 캡션).
    /// 이름과 **같은 이중언어 구조**를 쓴다: 소개문은 레시피 데이터의 일부라 번역도 시드 JSON이
    /// 들고 있어야 한다(`Localizable.xcstrings`는 UI 문자열용이고, 레시피 80종을 키로 등록하지 않는다).
    /// 옵셔널 + 기본값 nil — 시드에만 있고 **사용자 커스텀 레시피엔 없다**. 구버전 저장 데이터도
    /// 이 키 없이 그대로 디코드된다(필드 추가는 반드시 옵셔널+기본값, `origin`과 같은 규칙).
    var intro: LocalizedName? = nil
    var cuisine: String?
    var minutes: Int
    var ingredients: [Item]
    /// 조리 단계 — 티켓의 "See the cooking details?" 링크가 여는 주방 전표(`KitchenCopySheet`)가
    /// `displaySteps`로 화면에 그린다(1차 경로는 여전히 영상). 시드 JSON과 이미 저장된 커스텀
    /// 레시피가 이 키를 갖고 있으므로 지우면 기존 데이터 디코드가 깨진다.
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

    /// 데이터 표기(레시피명·조리 단계·재료명)의 언어 판별 — **앱 언어 선택(`AppLanguage`)이 정본**이다
    /// (42차·F70). `Locale.current`만 보면 인앱 언어 전환이 크롬(버튼·라벨)만 바꾸고 화면에서 가장
    /// 큰 글자(메뉴명)와 가장 많은 항목(재료명)은 기기 언어로 남아, 스위치가 고장 난 것으로 읽혔다.
    /// `.system`이면 종전대로 기기 로케일. `UserDefaults` 읽기는 CFPreferences 인메모리 캐시라
    /// 리스트 셀 단위 호출에도 실측상 무해하다(행당 ~수백 ns).
    static var isKorean: Bool {
        switch AppLanguage.current {
        case .ko: true
        case .en: false
        case .system: Locale.current.language.languageCode?.identifier == "ko"
        }
    }

    // MARK: - 표시 접근자

    var displayName: String { Self.isKorean ? (name.ko ?? name.en) : name.en }
    /// 로케일 조리 단계(39차 — 33c8861에서 참조 소멸로 삭제됐다가 주방 전표 시트를 위해 되살아났다).
    /// 커스텀 레시피는 편집기가 단계를 더 이상 입력받지 않아 보통 빈 배열이다 — 그 경우 호출부가
    /// 옵트인 링크 자체를 안 그린다(§CookingStepsView).
    var displaySteps: [String] {
        if Self.isKorean, let ko = steps.ko, !ko.isEmpty { return ko }
        return steps.en
    }
    /// 로케일 표시 소개 — **없으면 nil**이고 호출부는 그 자리에 아무것도 그리지 않는다(자리표시 금지).
    /// 공백만 남은 값도 nil로 접는다 — 빈 캡션이 여백만 벌리는 것을 막는다.
    var displayIntro: String? {
        guard let intro else { return nil }
        let text = Self.isKorean ? (intro.ko ?? intro.en) : intro.en
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
    var isUserRecipe: Bool { isUser ?? false }

    /// 히어로 대표 모티프 — ① 요리 이름 큐레이션 표, ② 첫 번째 비상비 재료의 글리프.
    /// **메뉴 정체성 > 재료 구성**이라 이름이 재료보다 앞선다: "김밥"의 정체는 김도 밥도 계란도 아니라
    /// 김밥 그 자체인데, 재료에서 파생하면 첫 재료(김·계란)가 대표로 올라와 티켓 메뉴명 옆
    /// 아이콘(`ReffiDishIcon.ticket`)에서 메뉴를 못 읽는다.
    var glyph: FoodGlyph {
        if let dish = Self.dishGlyph(for: name) { return dish }
        for item in ingredients {
            let key = item.ref ?? item.en
            if IngredientLexicon.shared.isStaple(key) { continue }
            let g = FoodGlyph.match(item.displayName)
            if g != .generic { return g }
        }
        return .generic
    }

    /// 요리 이름 → 전용 글리프. 없으면 nil(재료 폴백으로 넘어간다).
    /// 표는 `FoodGlyph.dishKeywords` **한 곳**에만 둔다 — 진입점이 갈리면 "김밥"이 어디서 들어오느냐에
    /// 따라 그림이 달라진다.
    /// en·ko를 모두 보는 건 글리프가 **시각 정체성**이라 로케일에 따라 그림이 바뀌면 안 되기 때문
    /// (시드는 en이 서술형 "Gimbap (Seaweed Rice Rolls)", 커스텀은 현재 로케일 표기가 en 슬롯).
    static func dishGlyph(for name: LocalizedName) -> FoodGlyph? {
        for slot in [name.en, name.ko].compactMap({ $0 }) {
            if let g = FoodGlyph.dishGlyph(for: slot) { return g }
        }
        return nil
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
