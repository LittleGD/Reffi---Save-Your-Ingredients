import Foundation

/// 가입 완료(또는 신규 프로필 최초 시드) 직후 자동 배정되는 위트 있는 닉네임 — "형용사 + 식재료"
/// 조합(예: "멋쟁이 토마토" / "Dashing Tomato"). 실제 배정·가드 로직(미설정일 때만 덮어쓰기)은
/// `ProfileStore.assignGeneratedNicknameIfUnset`가 갖는다 — 이 타입은 순수 데이터 풀과 무작위
/// 조합만 책임지는 부작용 없는 생성기다.
///
/// 명사 풀은 정본 재료 사전(`IngredientLexicon`, 223개 항목) 중 닉네임으로 자연스러운 채소·과일·
/// 기본 재료만 추려 큐레이션했다(소스·조미료·통조림·물처럼 "○○한 간장" 식으로 어색한 항목은 제외).
/// ko/en 표기는 사전 항목의 1순위 표기(`Entry.names.{en,ko}.first`, `displayName`의 근거와 동일)를
/// 그대로 복사해 앱 다른 화면(레시피·냉장고)의 재료 표기와 갈리지 않게 맞췄다.
/// 런타임에 `IngredientLexicon.shared`를 직접 조회하지 않고 문자열로 고정한 이유:
/// ① 닉네임 자동 생성은 가입 흐름의 일부라 번들 JSON 로드 실패와 무관하게 항상 성공해야 하고,
/// ② 유닛 테스트가 번들 리소스 로드 없이도 결정적으로 검증돼야 하기 때문이다.
///
/// 두 풀 모두 **UI가 그리는 고정 문구가 아니라 무작위 조합의 재료(생성) 데이터**라 xcstrings에
/// 등록하지 않는다 — 생성 "결과"(사용자가 이후 저장·직접 수정하는 닉네임)는 사용자 데이터이지
/// 앱이 노출하는 문자열이 아니다(ProfileView.currentLanguageName의 로케일-파생 데이터 예외와 동일 근거).
enum NicknameGenerator {

    /// 균등 랜덤 "형용사 + 명사" 닉네임. `rng`는 테스트용 시드 주입 포인트 — 실제 호출부는 대개
    /// 시스템 난수를 쓰는 편의 오버로드(`generate(locale:)`)로 충분하다.
    static func generate<R: RandomNumberGenerator>(locale: Locale = .current, using rng: inout R) -> String {
        let useKorean = isKorean(locale)
        let adjective = (useKorean ? adjectivesKo : adjectivesEn).randomElement(using: &rng)!
        let noun = (useKorean ? nounsKo : nounsEn).randomElement(using: &rng)!
        return "\(adjective) \(noun)"
    }

    /// 시스템 난수 편의 오버로드 — 가입·프로필 시드 등 실제 호출부 대부분이 이 시그니처를 쓴다.
    static func generate(locale: Locale = .current) -> String {
        var rng = SystemRandomNumberGenerator()
        return generate(locale: locale, using: &rng)
    }

    /// 로케일 → 한국어 풀 선택 기준 — 앱 전역 ko/en 판별 기준(`Recipe.isKorean`)과 동일하게
    /// 언어코드 "ko" 하나만 본다(지역코드 무시: ko-KR·ko-US 모두 한국어 취급).
    private static func isKorean(_ locale: Locale) -> Bool {
        locale.language.languageCode?.identifier == "ko"
    }

    // MARK: - 형용사 풀(위트 톤 — 귀엽고 유머러스, 부정적 뉘앙스 없음. 각 24개)

    static let adjectivesKo: [String] = [
        "멋쟁이", "명랑한", "새콤한", "씩씩한", "포동포동", "용감한", "수줍은", "든든한",
        "상큼한", "느긋한", "반짝이는", "엉뚱한", "다정한", "쾌활한", "포근한", "야무진",
        "싱그러운", "말랑한", "똑똑한", "재빠른", "유쾌한", "당당한", "차분한", "발랄한",
    ]

    static let adjectivesEn: [String] = [
        "Dashing", "Zesty", "Plucky", "Snazzy", "Mellow", "Jolly", "Spiffy", "Nimble",
        "Chipper", "Breezy", "Sunny", "Perky", "Dapper", "Bubbly", "Sassy", "Cheerful",
        "Jaunty", "Peppy", "Sprightly", "Witty", "Merry", "Plush", "Snug", "Bold",
    ]

    // MARK: - 명사 풀(식재료 — IngredientLexicon 표기 재사용, 친근한 채소·과일·기본 재료. 각 30개)
    //
    // 주의(드리프트 위험): 아래 60개 표기는 `ingredient-lexicon.json`의 1순위 표기를 **손으로 복사한**
    // 두 번째 사본이다 — 위 doc comment의 이유(가입 흐름은 번들 로드 실패와 무관하게 성공해야 하고,
    // 테스트가 리소스 없이 결정적이어야 한다)로 런타임 조회를 하지 않는다. 대신 사전에서 재료 표기를
    // 고치면 여기가 조용히 어긋난다(컴파일도 테스트도 안 깨진다). 사전 표기를 바꾸는 작업은 이 두 풀도
    // 같이 훑는다 — 어긋나면 닉네임만 앱의 다른 화면과 다른 이름을 쓰게 된다.

    static let nounsKo: [String] = [
        "양파", "당근", "감자", "고구마", "토마토", "방울토마토", "오이", "가지",
        "호박", "버섯", "브로콜리", "양배추", "옥수수", "아보카도", "사과", "바나나",
        "포도", "딸기", "블루베리", "레몬", "오렌지", "수박", "망고", "파인애플",
        "계란", "두부", "새우", "밤", "귤", "복숭아",
    ]

    static let nounsEn: [String] = [
        "Onion", "Carrot", "Potato", "Sweet Potato", "Tomato", "Cherry Tomato", "Cucumber", "Eggplant",
        "Pumpkin", "Mushroom", "Broccoli", "Cabbage", "Corn", "Avocado", "Apple", "Banana",
        "Grape", "Strawberry", "Blueberry", "Lemon", "Orange", "Watermelon", "Mango", "Pineapple",
        "Egg", "Tofu", "Shrimp", "Chestnut", "Mandarin", "Peach",
    ]
}
