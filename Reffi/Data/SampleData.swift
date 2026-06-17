import Foundation

/// 디자인 빌드용 샘플 데이터. 영속화(SwiftData)는 다음 단계.
enum SampleData {

    static let ingredients: [Ingredient] = [
        Ingredient(name: "연두부", category: "콩 · 두부",     daysLeft: 0, amount: "½모 남음",   alternative: .cook,   glyph: .tofu),
        Ingredient(name: "시금치", category: "채소 · 잎채소",   daysLeft: 1, amount: "한 줌(80g)", alternative: .freeze, glyph: .leaf),
        Ingredient(name: "애호박", category: "채소 · 박과",     daysLeft: 2, amount: "1개",       alternative: .prep,   glyph: .squash),
        Ingredient(name: "달걀",   category: "축산 · 알",       daysLeft: 3, amount: "4개",       alternative: .cook,   glyph: .egg),
        Ingredient(name: "당근",   category: "채소 · 뿌리",     daysLeft: 6, amount: "2개",       alternative: .prep,   glyph: .root),
        Ingredient(name: "레몬",   category: "과일 · 시트러스", daysLeft: 7, amount: "3개",       alternative: .share,  glyph: .citrus),
        Ingredient(name: "부사",   category: "과일 · 사과",     daysLeft: 9, amount: "2개",       alternative: .share,  glyph: .apple),
    ]

    /// 레시피 — ingredientNames는 캐논 재료명(상비 포함). 매치 분모는 비-상비만.
    static let recipes: [Recipe] = [
        Recipe(name: "애호박 두부조림",  ingredientNames: ["애호박", "연두부", "당근", "간장", "다진마늘"],          minutes: 20, glyph: .squash),
        Recipe(name: "시금치 두부무침",  ingredientNames: ["시금치", "연두부", "참기름", "소금", "다진마늘"],        minutes: 15, glyph: .leaf),
        Recipe(name: "당근 달걀 볶음밥", ingredientNames: ["당근", "달걀", "애호박", "밥", "간장", "식용유"],        minutes: 18, glyph: .egg),
        Recipe(name: "사과 당근 샐러드", ingredientNames: ["부사", "당근", "레몬", "올리브유"],                     minutes: 10, glyph: .apple),
        Recipe(name: "시금치 된장국",    ingredientNames: ["시금치", "된장", "물", "대파"],                        minutes: 15, glyph: .leaf),
        Recipe(name: "달걀찜",          ingredientNames: ["달걀", "물", "대파", "소금"],                          minutes: 12, glyph: .egg),
        Recipe(name: "레몬청",          ingredientNames: ["레몬", "설탕"],                                       minutes: 25, glyph: .citrus),
    ]
}
