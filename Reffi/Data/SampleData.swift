import Foundation

/// 디자인 빌드용 샘플 데이터(영어). 영속화(SwiftData)는 다음 단계.
enum SampleData {

    static let ingredients: [Ingredient] = [
        Ingredient(name: "Soft Tofu", category: "Beans · Tofu",   daysLeft: 0, amount: "½ block left", alternative: .cook,   glyph: .tofu),
        Ingredient(name: "Spinach",   category: "Veg · Leafy",     daysLeft: 1, amount: "1 bunch (80g)", alternative: .freeze, glyph: .leaf),
        Ingredient(name: "Zucchini",  category: "Veg · Squash",    daysLeft: 2, amount: "1 ea",          alternative: .prep,   glyph: .squash),
        Ingredient(name: "Eggs",      category: "Dairy · Eggs",    daysLeft: 3, amount: "4 ea",          alternative: .cook,   glyph: .egg),
        Ingredient(name: "Carrot",    category: "Veg · Root",      daysLeft: 6, amount: "2 ea",          alternative: .prep,   glyph: .root),
        Ingredient(name: "Lemon",     category: "Fruit · Citrus",  daysLeft: 7, amount: "3 ea",          alternative: .share,  glyph: .citrus),
        Ingredient(name: "Apple",     category: "Fruit · Apple",   daysLeft: 9, amount: "2 ea",          alternative: .share,  glyph: .apple),
    ]

    /// 레시피 — 실제 요리. ingredientNames는 캐논 재료명(상비 포함). 매치 분모는 비-상비만.
    static let recipes: [Recipe] = [
        Recipe(name: "Kimchi Stew",          ingredientNames: ["Kimchi", "Soft Tofu", "Green onion", "Garlic"],         minutes: 25, glyph: .tofu),
        Recipe(name: "Doenjang Stew",        ingredientNames: ["Zucchini", "Soft Tofu", "Doenjang", "Green onion"],     minutes: 20, glyph: .squash),
        Recipe(name: "Sundubu Stew",         ingredientNames: ["Soft Tofu", "Egg", "Green onion", "Garlic"],            minutes: 18, glyph: .tofu),
        Recipe(name: "Egg Fried Rice",       ingredientNames: ["Egg", "Carrot", "Rice", "Green onion", "Soy sauce"],    minutes: 15, glyph: .egg),
        Recipe(name: "Zucchini Pasta",       ingredientNames: ["Zucchini", "Garlic", "Olive oil", "Pasta"],            minutes: 18, glyph: .squash),
        Recipe(name: "Spinach Soup",         ingredientNames: ["Spinach", "Doenjang", "Soft Tofu", "Green onion"],      minutes: 15, glyph: .leaf),
        Recipe(name: "Sesame Spinach",       ingredientNames: ["Spinach", "Sesame oil", "Garlic", "Salt"],             minutes: 10, glyph: .leaf),
        Recipe(name: "Steamed Eggs",         ingredientNames: ["Egg", "Green onion", "Salt", "Water"],                 minutes: 12, glyph: .egg),
        Recipe(name: "Apple Carrot Salad",   ingredientNames: ["Apple", "Carrot", "Lemon", "Olive oil"],               minutes: 10, glyph: .apple),
    ]
}
