import Foundation

/// 디자인 빌드용 샘플 데이터(영어). 영속화(SwiftData)는 다음 단계.
/// 다양한 재료군(고기·생선·채소·유제품)을 담아 실루엣·추천을 보여준다.
enum SampleData {

    static let ingredients: [Ingredient] = [
        Ingredient(name: "Beef",     category: "Meat · Beef",     daysLeft: 0, amount: "300 g",     alternative: .cook,   glyph: .meat,     place: "Costco",      storage: "Fridge", boughtDaysAgo: 2),
        Ingredient(name: "Spinach",  category: "Veg · Leafy",     daysLeft: 1, amount: "1 bunch",   alternative: .freeze, glyph: .leaf,     place: "Emart",       storage: "Fridge", boughtDaysAgo: 3),
        Ingredient(name: "Salmon",   category: "Seafood · Fish",  daysLeft: 1, amount: "1 fillet",  alternative: .cook,   glyph: .fish,     place: "Costco",      storage: "Fridge", boughtDaysAgo: 1),
        Ingredient(name: "Mushroom", category: "Veg · Fungi",     daysLeft: 2, amount: "1 pack",    alternative: .prep,   glyph: .mushroom, place: "Emart",       storage: "Fridge", boughtDaysAgo: 2),
        Ingredient(name: "Eggs",     category: "Dairy · Eggs",    daysLeft: 2, amount: "4 ea",      alternative: .cook,   glyph: .egg,      place: "Emart",       storage: "Fridge", boughtDaysAgo: 4),
        Ingredient(name: "Tomato",   category: "Veg · Fruit",     daysLeft: 3, amount: "3 ea",      alternative: .prep,   glyph: .tomato,   place: "Hanaro Mart", storage: "Room",   boughtDaysAgo: 3),
        Ingredient(name: "Onion",    category: "Veg · Allium",    daysLeft: 4, amount: "2 ea",      alternative: .prep,   glyph: .onion,    place: "Emart",       storage: "Pantry", boughtDaysAgo: 5),
        Ingredient(name: "Cheese",   category: "Dairy · Cheese",  daysLeft: 5, amount: "1 block",   alternative: .freeze, glyph: .cheese,   place: "Costco",      storage: "Fridge", boughtDaysAgo: 6),
        Ingredient(name: "Broccoli", category: "Veg · Floret",    daysLeft: 6, amount: "1 head",    alternative: .prep,   glyph: .broccoli, place: "Emart",       storage: "Fridge", boughtDaysAgo: 4),
        Ingredient(name: "Milk",     category: "Dairy · Milk",    daysLeft: 6, amount: "1 L",        alternative: .cook,   glyph: .milk,     place: "GS25",        storage: "Fridge", boughtDaysAgo: 3),
        Ingredient(name: "Carrot",   category: "Veg · Root",      daysLeft: 8, amount: "2 ea",      alternative: .prep,   glyph: .root,     place: "Emart",       storage: "Fridge", boughtDaysAgo: 5),
        Ingredient(name: "Bread",    category: "Bakery · Loaf",   daysLeft: 9, amount: "½ loaf",    alternative: .freeze, glyph: .bread,    place: "Paris Baguette", storage: "Pantry", boughtDaysAgo: 2),
    ]

    /// 레시피 — 보유 재료를 폭넓게 쓰는 실제 요리. ingredientNames는 캐논 재료명(상비 포함).
    static let recipes: [Recipe] = [
        Recipe(name: "Beef Bulgogi",      ingredientNames: ["Beef", "Onion", "Garlic", "Soy sauce"],      minutes: 25, glyph: .meat),
        Recipe(name: "Beef & Veg Stew",   ingredientNames: ["Beef", "Carrot", "Onion", "Potato"],         minutes: 40, glyph: .meat),
        Recipe(name: "Salmon with Lemon", ingredientNames: ["Salmon", "Lemon", "Olive oil", "Dill"],      minutes: 18, glyph: .fish),
        Recipe(name: "Mushroom Soup",     ingredientNames: ["Mushroom", "Onion", "Milk", "Butter"],       minutes: 20, glyph: .mushroom),
        Recipe(name: "Spinach Omelette",  ingredientNames: ["Egg", "Spinach", "Cheese", "Milk"],          minutes: 12, glyph: .egg),
        Recipe(name: "Tomato Pasta",      ingredientNames: ["Tomato", "Garlic", "Onion", "Pasta"],        minutes: 18, glyph: .tomato),
        Recipe(name: "Veggie Stir-fry",   ingredientNames: ["Broccoli", "Carrot", "Mushroom", "Garlic"],  minutes: 15, glyph: .broccoli),
        Recipe(name: "Cheese Egg Toast",  ingredientNames: ["Bread", "Cheese", "Egg"],                    minutes: 10, glyph: .bread),
        Recipe(name: "Caprese Salad",     ingredientNames: ["Tomato", "Cheese", "Basil", "Olive oil"],    minutes: 8,  glyph: .tomato),
        Recipe(name: "Egg Fried Rice",    ingredientNames: ["Egg", "Carrot", "Rice", "Green onion"],      minutes: 15, glyph: .egg),
    ]

    /// 소비/버림 이력(데모) — History·낭비율용. 최신이 앞.
    static let history: [RemovalLog] = [
        RemovalLog(name: "Eggs",         glyph: .egg,      daysAgo: 1,  wasted: false),
        RemovalLog(name: "Strawberries", glyph: .berry,    daysAgo: 2,  wasted: true),
        RemovalLog(name: "Yogurt",       glyph: .milk,     daysAgo: 3,  wasted: false),
        RemovalLog(name: "Banana",       glyph: .apple,    daysAgo: 4,  wasted: false),
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
