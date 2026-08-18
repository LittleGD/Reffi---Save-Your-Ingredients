import Foundation

/// 샘플 데이터 — 첫 실행 온보딩의 "샘플로 둘러보기"와 프리뷰가 쓴다.
/// 실제 사용자 데이터는 `FridgeStore`가 JSON으로 영속화하며, 샘플은 명시적 선택으로만 로드된다.
/// 레시피는 여기 없다 — 번들 `recipes-seed.json`이 정본(레시피 하드코딩 금지 규칙).
///
/// **콘텐츠는 코드에 없다**: 재료 이름·글리프·카테고리는 전부 정본 사전(`ingredient-lexicon.json`)에서
/// 캐논 ID로 끌어온다(온보딩 `heroTicket()`이 먼저 쓴 패턴). 코드에 남는 건 데모 연출용 숫자뿐 —
/// 남은 일수·수량·구매처·보관. 이렇게 해야 한국어 기기에서 샘플 냉장고가 영문으로 새지 않고,
/// 카테고리도 실제 등록 경로와 같은 `glyph.categoryLabel`(카탈로그 등록 키)로 떨어진다.
enum SampleData {

    /// 데모 재고 한 줄의 연출값 — 무엇인지(id)는 사전이, 어떤 상태인지는 여기가 정한다.
    private struct Stock {
        var id: String                  // ingredient-lexicon.json 캐논 ID
        var daysLeft: Int
        var quantity: Quantity
        var place: String
        var storage: StorageLocation = .fridge
        var boughtDaysAgo: Int
    }

    /// 데모 이력 한 줄 — 최신이 앞.
    private struct Past {
        var id: String
        var daysAgo: Int
        var wasted: Bool
    }

    private static let stock: [Stock] = [
        Stock(id: "beef",       daysLeft: 0,  quantity: Quantity(value: 300, unit: .gram),  place: "Costco",         boughtDaysAgo: 2),
        Stock(id: "spinach",    daysLeft: 1,  quantity: Quantity(value: 1, unit: .bunch),   place: "Emart",          boughtDaysAgo: 3),
        Stock(id: "salmon",     daysLeft: 1,  quantity: Quantity(value: 1, unit: .piece),   place: "Costco",         boughtDaysAgo: 1),
        Stock(id: "dumpling",   daysLeft: 30, quantity: Quantity(value: 1, unit: .pack),    place: "Costco",         storage: .freezer, boughtDaysAgo: 10),
        Stock(id: "mushroom",   daysLeft: 2,  quantity: Quantity(value: 1, unit: .pack),    place: "Emart",          boughtDaysAgo: 2),
        Stock(id: "egg",        daysLeft: 2,  quantity: Quantity(value: 4, unit: .piece),   place: "Emart",          boughtDaysAgo: 4),
        Stock(id: "tomato",     daysLeft: 3,  quantity: Quantity(value: 3, unit: .piece),   place: "Hanaro Mart",    storage: .room,   boughtDaysAgo: 3),
        Stock(id: "onion",      daysLeft: 4,  quantity: Quantity(value: 2, unit: .piece),   place: "Emart",          storage: .pantry, boughtDaysAgo: 5),
        Stock(id: "cheese",     daysLeft: 5,  quantity: Quantity(value: 1, unit: .block),   place: "Costco",         boughtDaysAgo: 6),
        Stock(id: "broccoli",   daysLeft: 6,  quantity: Quantity(value: 1, unit: .piece),   place: "Emart",          boughtDaysAgo: 4),
        Stock(id: "milk",       daysLeft: 6,  quantity: Quantity(value: 1, unit: .liter),   place: "GS25",           boughtDaysAgo: 3),
        Stock(id: "carrot",     daysLeft: 8,  quantity: Quantity(value: 2, unit: .piece),   place: "Emart",          boughtDaysAgo: 5),
        Stock(id: "bread",      daysLeft: 9,  quantity: Quantity(value: 0.5, unit: .block), place: "Paris Baguette", storage: .pantry, boughtDaysAgo: 2),
    ]

    /// 소비/버림 이력(데모) — History·낭비율용. 최신이 앞.
    private static let past: [Past] = [
        // egg는 **오늘**(daysAgo 0) — 주간 히어로가 어떤 주 시작 관례(월요일/일요일)에서도 빈 주가
        // 되지 않게 하는 고정점이다. 전부 daysAgo ≥ 1이면 주 첫날(예: 일요일 시작 로케일의 일요일)에
        // 이번 주 창이 통째로 비어, 히어로가 빈 상태로 떨어지고 그 상태를 전제한 QA·UI 테스트가
        // 요일에 따라 갈린다(실측: ReffiFlowUITests 히어로 반영 테스트가 일요일에만 실패했다).
        Past(id: "egg",        daysAgo: 0,  wasted: false),
        Past(id: "strawberry", daysAgo: 2,  wasted: true),
        Past(id: "yogurt",     daysAgo: 3,  wasted: false),
        Past(id: "banana",     daysAgo: 4,  wasted: false),
        Past(id: "cilantro",   daysAgo: 5,  wasted: true),
        Past(id: "cheese",     daysAgo: 7,  wasted: false),
        Past(id: "spinach",    daysAgo: 9,  wasted: true),
        Past(id: "bread",      daysAgo: 11, wasted: false),
        Past(id: "pork-belly", daysAgo: 13, wasted: false),
        Past(id: "milk",       daysAgo: 16, wasted: true),
        Past(id: "lettuce",    daysAgo: 20, wasted: true),
        Past(id: "apple",      daysAgo: 24, wasted: false),
    ]

    static let ingredients: [Ingredient] = stock.compactMap { s in
        guard let e = IngredientLexicon.shared.entry(id: s.id) else { return nil }
        let glyph = FoodGlyph(rawValue: e.glyph) ?? .generic
        return Ingredient(name: e.displayName,
                          category: glyph.categoryLabel,
                          expiresAt: Ingredient.day(offset: s.daysLeft),
                          quantity: s.quantity,
                          glyph: glyph,
                          place: s.place,
                          storage: s.storage,
                          purchasedAt: Ingredient.day(offset: -s.boughtDaysAgo),
                          canonicalID: e.id)
    }

    static let history: [RemovalLog] = past.compactMap { p in
        guard let e = IngredientLexicon.shared.entry(id: p.id) else { return nil }
        return RemovalLog(name: e.displayName,
                          glyph: FoodGlyph(rawValue: e.glyph) ?? .generic,
                          canonicalID: e.id,
                          removedAt: Ingredient.day(offset: -p.daysAgo),
                          wasted: p.wasted)
    }

    /// 사전에서 조립된 줄 수의 기대값 — 캐논 ID 오타가 조용히 줄을 지우지 않게 테스트가 본다.
    static let expectedIngredientCount = stock.count
    static let expectedHistoryCount = past.count
}
