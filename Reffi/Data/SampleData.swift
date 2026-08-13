import Foundation

/// 샘플 데이터(영어) — 첫 실행 온보딩의 "샘플로 둘러보기"와 프리뷰가 쓴다.
/// 실제 사용자 데이터는 `FridgeStore`가 JSON으로 영속화하며, 샘플은 명시적 선택으로만 로드된다.
/// 레시피는 여기 없다 — 번들 `recipes-seed.json`이 정본(레시피 하드코딩 금지 규칙).
enum SampleData {

    static let ingredients: [Ingredient] = [
        Ingredient(name: "Beef",     category: "Meat · Beef",     daysLeft: 0, quantity: Quantity(value: 300, unit: .gram),  glyph: .meat,     place: "Costco",      boughtDaysAgo: 2),
        Ingredient(name: "Spinach",  category: "Veg · Leafy",     daysLeft: 1, quantity: Quantity(value: 1, unit: .bunch),   glyph: .leaf,     place: "Emart",       boughtDaysAgo: 3),
        Ingredient(name: "Salmon",   category: "Seafood · Fish",  daysLeft: 1, quantity: Quantity(value: 1, unit: .piece),   glyph: .fish,     place: "Costco",      boughtDaysAgo: 1),
        Ingredient(name: "Dumplings", category: "Frozen · Mandu", daysLeft: 30, quantity: Quantity(value: 1, unit: .pack),  glyph: .dumpling, place: "Costco",      storage: .freezer, boughtDaysAgo: 10),
        Ingredient(name: "Mushroom", category: "Veg · Fungi",     daysLeft: 2, quantity: Quantity(value: 1, unit: .pack),    glyph: .mushroom, place: "Emart",       boughtDaysAgo: 2),
        Ingredient(name: "Eggs",     category: "Dairy · Eggs",    daysLeft: 2, quantity: Quantity(value: 4, unit: .piece),   glyph: .egg,      place: "Emart",       boughtDaysAgo: 4),
        Ingredient(name: "Tomato",   category: "Veg · Fruit",     daysLeft: 3, quantity: Quantity(value: 3, unit: .piece),   glyph: .tomato,   place: "Hanaro Mart", storage: .room,   boughtDaysAgo: 3),
        Ingredient(name: "Onion",    category: "Veg · Allium",    daysLeft: 4, quantity: Quantity(value: 2, unit: .piece),   glyph: .onion,    place: "Emart",       storage: .pantry, boughtDaysAgo: 5),
        Ingredient(name: "Cheese",   category: "Dairy · Cheese",  daysLeft: 5, quantity: Quantity(value: 1, unit: .block),   glyph: .cheese,   place: "Costco",      boughtDaysAgo: 6),
        Ingredient(name: "Broccoli", category: "Veg · Floret",    daysLeft: 6, quantity: Quantity(value: 1, unit: .piece),   glyph: .broccoli, place: "Emart",       boughtDaysAgo: 4),
        Ingredient(name: "Milk",     category: "Dairy · Milk",    daysLeft: 6, quantity: Quantity(value: 1, unit: .liter),   glyph: .milk,     place: "GS25",        boughtDaysAgo: 3),
        Ingredient(name: "Carrot",   category: "Veg · Root",      daysLeft: 8, quantity: Quantity(value: 2, unit: .piece),   glyph: .root,     place: "Emart",       boughtDaysAgo: 5),
        Ingredient(name: "Bread",    category: "Bakery · Loaf",   daysLeft: 9, quantity: Quantity(value: 0.5, unit: .block), glyph: .bread,    place: "Paris Baguette", storage: .pantry, boughtDaysAgo: 2),
    ]

    /// 소비/버림 이력(데모) — History·낭비율용. 최신이 앞.
    static let history: [RemovalLog] = [
        RemovalLog(name: "Eggs",         glyph: .egg,      daysAgo: 1,  wasted: false),
        RemovalLog(name: "Strawberries", glyph: .berry,    daysAgo: 2,  wasted: true),
        RemovalLog(name: "Yogurt",       glyph: .yogurt,   daysAgo: 3,  wasted: false),
        RemovalLog(name: "Banana",       glyph: .banana,   daysAgo: 4,  wasted: false),
        RemovalLog(name: "Cilantro",     glyph: .leaf,     daysAgo: 5,  wasted: true),
        RemovalLog(name: "Cheese",       glyph: .cheese,   daysAgo: 7,  wasted: false),
        RemovalLog(name: "Spinach",      glyph: .leaf,     daysAgo: 9,  wasted: true),
        RemovalLog(name: "Bread",        glyph: .bread,    daysAgo: 11, wasted: false),
        RemovalLog(name: "Pork belly",   glyph: .meat,     daysAgo: 13, wasted: false),
        RemovalLog(name: "Milk",         glyph: .milk,     daysAgo: 16, wasted: true),
        RemovalLog(name: "Lettuce",      glyph: .leaf,     daysAgo: 20, wasted: true),
        RemovalLog(name: "Apple",        glyph: .apple,    daysAgo: 24, wasted: false),
    ]
}
