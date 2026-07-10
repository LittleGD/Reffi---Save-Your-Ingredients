import Foundation

/// 음식 모티프 종류 — 종이컷 실루엣(`PaperSilhouette`)이 이 값으로 단일 쉐입을 그린다.
enum FoodGlyph: String, Codable, CaseIterable {
    // 채소·과일
    case leaf, root, squash, onion, tomato, pepper, mushroom, broccoli, potato, garlic
    case apple, citrus, berry
    // 단백질
    case egg, tofu, meat, poultry, fish, shrimp
    // 유제품·기타
    case milk, cheese, bread
    case generic

    /// 톨러런트 디코드 — 미지의 rawValue(향후 케이스 추가·데이터 오염)가 필드 하나로 끝나게
    /// .generic으로 폴백한다. strict하게 두면 글리프 하나가 스냅샷 전체를 격리시킨다.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = FoodGlyph(rawValue: raw) ?? .generic
    }

    /// 재료명 → 글리프. 1순위 정본 재료 사전(`IngredientLexicon`), 2순위 레거시 키워드 폴백.
    /// 한 글자 키워드("배"·"파"·"무")는 정확 일치만 — "배추"→과일, "파프리카"→양파 같은 오분류를 막는다.
    static func match(_ name: String) -> FoodGlyph {
        if let g = IngredientLexicon.shared.glyph(for: name) { return g }
        let n = name.lowercased()
        func has(_ ks: [String]) -> Bool { ks.contains { $0.count > 1 ? n.contains($0) : n == $0 } }
        switch true {
        case has(["tofu", "두부"]):                                              return .tofu
        case has(["egg", "계란", "달걀"]):                                        return .egg
        case has(["beef", "pork", "steak", "bacon", "ham", "meat", "소고기", "쇠고기", "돼지", "고기", "삼겹", "스테이크"]): return .meat
        case has(["chicken", "drumstick", "poultry", "wing", "닭", "치킨"]):       return .poultry
        case has(["shrimp", "prawn", "새우"]):                                    return .shrimp
        case has(["fish", "salmon", "tuna", "mackerel", "cod", "생선", "연어", "고등어", "참치", "회"]): return .fish
        case has(["milk", "cream", "yogurt", "yoghurt", "우유", "크림", "요거트", "요구르트"]): return .milk
        case has(["cheese", "butter", "치즈", "버터"]):                            return .cheese
        case has(["bread", "toast", "bun", "baguette", "빵", "식빵", "토스트"]):    return .bread
        case has(["onion", "scallion", "leek", "양파", "대파", "쪽파", "파"]):      return .onion
        case has(["garlic", "마늘"]):                                            return .garlic
        case has(["tomato", "토마토"]):                                          return .tomato
        case has(["pepper", "paprika", "bell", "chili", "피망", "파프리카", "고추"]): return .pepper
        case has(["mushroom", "shiitake", "버섯"]):                              return .mushroom
        case has(["broccoli", "cauliflower", "브로콜리", "콜리"]):                 return .broccoli
        case has(["potato", "감자"]):                                            return .potato
        case has(["zucchini", "squash", "courgette", "cucumber", "eggplant", "애호박", "호박", "오이", "가지"]): return .squash
        case has(["carrot", "radish", "당근", "무"]):                            return .root
        case has(["apple", "pear", "peach", "사과", "배", "복숭아"]):              return .apple
        case has(["lemon", "lime", "orange", "citrus", "mandarin", "레몬", "라임", "오렌지", "귤", "감귤"]): return .citrus
        case has(["berry", "strawberry", "blueberry", "grape", "베리", "딸기", "블루베리", "포도"]): return .berry
        case has(["spinach", "lettuce", "cabbage", "kale", "greens", "herb", "leaf", "시금치", "상추", "배추", "양배추", "나물", "잎"]): return .leaf
        default:                                                                return .generic
        }
    }
}

/// 재료 카드의 데이터. 날짜는 **절대 시각이 원본**(`expiresAt`/`purchasedAt`/`frozenAt`) — 남은 일수는
/// 렌더 시점마다 계산해 시간이 흐르면 임박도가 함께 흐른다. 냉동은 `expiresAt`을 덮지 않고
/// `frozenAt + 유예`를 파생 시계(`effectiveDaysLeft`)로 쓴다 — 해동하면 원래 시계로 복귀.
/// 저장(JSON)을 위해 Codable — v1 파일(amount 자유 문자열, alternative 필드)을 안전 마이그레이션한다.
struct Ingredient: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String              // "연두부"
    var category: String          // 글리프에서 파생된 카테고리 라벨
    var canonicalID: String?      // 정본 사전 캐논 ID — 표기 무관 매칭 키. nil = 미해석·사전 밖(스토어가 해석·승격)
    var expiresAt: Date           // 소비기한(자정 기준 일 단위) — 냉동해도 불변(원본)
    var quantity: Quantity        // 수량 — 수치 + 단위(부분 소비·환산 가능)
    var glyph: FoodGlyph
    var place: String             // 구매처(영수증 스캔이 채움). 비면 "—"
    var storage: StorageLocation  // 보관(냉장/냉동/실온) — 냉동은 신선도 시계가 달라진다
    var purchasedAt: Date         // 구매 시점
    var frozenAt: Date?           // 냉동 전환 시점 — 기록되면 재냉동 불가(1회 제한)

    /// 냉동 유예 — 얼리면 이 기간의 **새 D-day**를 받는다(무기한이 아님, §13.6 두 번째 기회 루프).
    static let freezerGraceDays = 14

    init(id: UUID = UUID(), name: String, category: String, expiresAt: Date,
         quantity: Quantity = Quantity(value: 1, unit: .piece),
         glyph: FoodGlyph? = nil, place: String = "",
         storage: StorageLocation = .fridge, purchasedAt: Date? = nil, frozenAt: Date? = nil,
         canonicalID: String? = nil) {
        self.id = id
        self.name = name
        self.category = category
        self.canonicalID = canonicalID
        self.expiresAt = expiresAt
        self.quantity = quantity
        self.glyph = glyph ?? FoodGlyph.match(name)
        self.place = place
        self.storage = storage
        self.purchasedAt = purchasedAt ?? Date()
        self.frozenAt = frozenAt
    }

    /// 상대 일수 편의 생성자(샘플·프리뷰) — 오늘 기준 오프셋을 절대 날짜로 바꿔 저장.
    init(name: String, category: String, daysLeft: Int, quantity: Quantity,
         glyph: FoodGlyph, place: String = "", storage: StorageLocation = .fridge,
         boughtDaysAgo: Int = 3) {
        self.init(name: name, category: category, expiresAt: Self.day(offset: daysLeft),
                  quantity: quantity, glyph: glyph, place: place, storage: storage,
                  purchasedAt: Self.day(offset: -boughtDaysAgo))
    }

    // MARK: - Codable (v1 마이그레이션)

    private enum CodingKeys: String, CodingKey {
        case id, name, category, canonicalID, expiresAt, quantity, glyph, place, storage, purchasedAt, frozenAt
        case amount   // v1 레거시(자유 문자열) — 읽기 전용
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        category = try c.decode(String.self, forKey: .category)
        canonicalID = try c.decodeIfPresent(String.self, forKey: .canonicalID)   // 레거시 파일엔 없음 → nil(로드 시 승격)
        expiresAt = try c.decode(Date.self, forKey: .expiresAt)
        glyph = try c.decode(FoodGlyph.self, forKey: .glyph)
        place = try c.decode(String.self, forKey: .place)
        storage = try c.decodeIfPresent(StorageLocation.self, forKey: .storage) ?? .fridge
        purchasedAt = try c.decode(Date.self, forKey: .purchasedAt)
        frozenAt = try c.decodeIfPresent(Date.self, forKey: .frozenAt)
        if let q = try c.decodeIfPresent(Quantity.self, forKey: .quantity) {
            quantity = q
        } else {
            // v1: amount 자유 문자열("300 g", "½모 남음") → 최선 파싱, 실패 시 1개.
            let legacy = try c.decodeIfPresent(String.self, forKey: .amount) ?? "1"
            quantity = Quantity.parseLegacy(legacy)
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(category, forKey: .category)
        try c.encode(canonicalID, forKey: .canonicalID)   // 항상 기록(nil이면 null) — 해석 결과를 영속화
        try c.encode(expiresAt, forKey: .expiresAt)
        try c.encode(quantity, forKey: .quantity)
        try c.encode(glyph, forKey: .glyph)
        try c.encode(place, forKey: .place)
        try c.encode(storage, forKey: .storage)
        try c.encode(purchasedAt, forKey: .purchasedAt)
        try c.encodeIfPresent(frozenAt, forKey: .frozenAt)
    }

    /// 재료 동일성 키 — 표기(양파/onion) 무관. 캐논 ID가 있으면 그것, 없으면 이름 소문자(사전 밖·미해석).
    /// 중복 판정·쇼핑리스트·재입고 조회의 공통 기준(§개발규칙 — 정규화 키로 저장, 표시만 로케일).
    var matchKey: String { canonicalID ?? name.lowercased() }

    // MARK: - 시간 모델 (asOf 주입 — 테스트에서 자정 경계·타임존 검증 가능)

    /// 두 시각의 달력 일수 차(자정 기준).
    static func days(from: Date, to: Date, calendar cal: Calendar = .current) -> Int {
        cal.dateComponents([.day], from: cal.startOfDay(for: from),
                           to: cal.startOfDay(for: to)).day ?? 0
    }

    /// 원본 소비기한 기준 D-day (음수 = 지남).
    func daysLeft(asOf now: Date) -> Int { Self.days(from: now, to: expiresAt) }
    var daysLeft: Int { daysLeft(asOf: Date()) }

    /// 실효 만료 시각 — 냉동 중(frozenAt 기록)이면 냉동 시점 + 유예, 아니면 원본 소비기한.
    /// 처음부터 냉동 보관으로 산 재료(frozenAt 없음)는 등록 시점의 소비기한을 그대로 쓴다.
    var effectiveExpiresAt: Date {
        if storage == .freezer, let frozenAt {
            return Self.day(offset: Self.freezerGraceDays, from: frozenAt)
        }
        return expiresAt
    }

    /// 실효 D-day — 신선도·정렬·알림·작업대 보충의 공통 기준.
    func effectiveDaysLeft(asOf now: Date) -> Int { Self.days(from: now, to: effectiveExpiresAt) }
    var effectiveDaysLeft: Int { effectiveDaysLeft(asOf: Date()) }

    /// 구매 후 경과 일수.
    var boughtDaysAgo: Int { Self.days(from: purchasedAt, to: Date()) }

    var freshness: Freshness { Freshness(daysLeft: effectiveDaysLeft) }

    var isFrozen: Bool { storage == .freezer }
    /// 냉동 가능 — 이미 냉동이 아니고, 한 번도 얼린 적 없어야(재냉동 금지) 한다.
    var canFreeze: Bool { storage != .freezer && frozenAt == nil }

    /// 남은 일수 라벨(로컬라이즈). 데이터성 숫자(§3.4).
    var dDayText: String {
        switch effectiveDaysLeft {
        case ..<0: String(localized: "Overdue", comment: "D-day label when past the use-by date")
        case 0:    String(localized: "Today", comment: "D-day label when expiring today")
        default:   String(localized: "\(effectiveDaysLeft)d", comment: "D-day shorthand, e.g. 3d")
        }
    }

    var purchasedText: String { purchasedAt.formatted(date: .abbreviated, time: .omitted) }
    var expiresText: String { effectiveExpiresAt.formatted(date: .abbreviated, time: .omitted) }
    var placeText: String { place.isEmpty ? "—" : place }
    var quantityText: String { quantity.text }

    /// 오늘 자정 기준 `offset`일 후의 자정 시각.
    static func day(offset: Int, from date: Date = Date()) -> Date {
        let cal = Calendar.current
        return cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: date)) ?? date
    }
}

extension FoodGlyph {
    /// 거친 카테고리 라벨 — 직접 입력의 자동 카테고리, History 도넛 그룹핑 공용.
    var categoryLabel: String {
        switch self {
        case .leaf, .broccoli, .onion, .garlic, .potato, .root, .squash, .mushroom, .pepper, .tomato: "Veg"
        case .apple, .citrus, .berry: "Fruit"
        case .egg, .milk, .cheese: "Dairy"
        case .meat, .poultry: "Meat"
        case .fish, .shrimp: "Seafood"
        case .tofu: "Protein"
        case .bread: "Bakery"
        case .generic: "Other"
        }
    }
}
