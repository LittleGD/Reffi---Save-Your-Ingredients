import Testing
import Foundation
@testable import Reffi

/// FoodGlyph — 53종 확장(각진 컷페이퍼) 후 카테고리 라벨 파생·케이스 목록·톨러런트 디코드 가드.
/// 재료명→글리프 라우팅(`match`)은 1순위 정본 사전이 결정하므로, 사전 글리프 값 재배정
/// 이후에 그쪽에서 검증한다(이 스위트는 enum 자체의 결정론적 계약만 지킨다).
struct GlyphTests {

    @Test func caseCountIs53() {
        // 35종 + v2 신규 17종(eggplant·sweetPotato·ginger·seaweed·grape·watermelon·pineapple·mango·
        // sausage·bacon·crab·squid·clam·yogurt·butter·honey·dumpling) + v3 요리형 1종(gimbap).
        #expect(FoodGlyph.allCases.count == 53)
    }

    @Test func everyGlyphHasCategoryLabel() {
        for g in FoodGlyph.allCases {
            #expect(!g.categoryLabel.isEmpty)
        }
    }

    @Test func newGlyphsMapToExpectedCategory() {
        // 곡류 2종·저장식품 2종은 신규 라벨(Grain·Pantry — Localizable.xcstrings en+ko).
        #expect(FoodGlyph.rice.categoryLabel == "Grain")
        #expect(FoodGlyph.noodles.categoryLabel == "Grain")
        #expect(FoodGlyph.corn.categoryLabel == "Grain")
        #expect(FoodGlyph.sauceBottle.categoryLabel == "Pantry")
        #expect(FoodGlyph.can.categoryLabel == "Pantry")
        // 신규 채소·과일은 기존 라벨로 편입.
        #expect(FoodGlyph.cucumber.categoryLabel == "Veg")
        #expect(FoodGlyph.pea.categoryLabel == "Veg")
        #expect(FoodGlyph.cabbage.categoryLabel == "Veg")
        #expect(FoodGlyph.chili.categoryLabel == "Veg")
        #expect(FoodGlyph.pumpkin.categoryLabel == "Veg")
        #expect(FoodGlyph.avocado.categoryLabel == "Fruit")
        #expect(FoodGlyph.banana.categoryLabel == "Fruit")
    }

    @Test func v2GlyphsMapToExpectedCategory() {
        // v2 신규 17종 카테고리 파생(전부 기존 라벨로 편입 — 신규 카테고리 없음).
        for g in [FoodGlyph.eggplant, .sweetPotato, .ginger, .seaweed] {
            #expect(g.categoryLabel == "Veg")
        }
        for g in [FoodGlyph.grape, .watermelon, .pineapple, .mango] {
            #expect(g.categoryLabel == "Fruit")
        }
        #expect(FoodGlyph.sausage.categoryLabel == "Meat")
        #expect(FoodGlyph.bacon.categoryLabel == "Meat")
        for g in [FoodGlyph.crab, .squid, .clam] {
            #expect(g.categoryLabel == "Seafood")
        }
        #expect(FoodGlyph.yogurt.categoryLabel == "Dairy")
        #expect(FoodGlyph.butter.categoryLabel == "Dairy")
        #expect(FoodGlyph.honey.categoryLabel == "Pantry")
        #expect(FoodGlyph.dumpling.categoryLabel == "Other")
    }

    @Test func categoryLabelsUnchangedForExisting() {
        // 라벨 추가일 뿐 기존 의미 변화 없음(회귀 가드).
        #expect(FoodGlyph.tomato.categoryLabel == "Veg")
        #expect(FoodGlyph.apple.categoryLabel == "Fruit")
        #expect(FoodGlyph.meat.categoryLabel == "Meat")
        #expect(FoodGlyph.fish.categoryLabel == "Seafood")
        #expect(FoodGlyph.milk.categoryLabel == "Dairy")
        #expect(FoodGlyph.generic.categoryLabel == "Other")
    }

    @Test func tolerantDecodeKeepsNewCasesAndFallsBack() throws {
        // 신규 rawValue는 그대로 디코드되고, 미지 값은 .generic으로 폴백(스냅샷 격리 방지).
        func decode(_ raw: String) throws -> FoodGlyph {
            try JSONDecoder().decode(FoodGlyph.self, from: Data("\"\(raw)\"".utf8))
        }
        #expect(try decode("sauceBottle") == .sauceBottle)
        #expect(try decode("avocado") == .avocado)
        #expect(try decode("eggplant") == .eggplant)
        #expect(try decode("watermelon") == .watermelon)
        #expect(try decode("dumpling") == .dumpling)
        #expect(try decode("someFutureGlyph") == .generic)
    }
}

/// 요리형 글리프(v3 gimbap) — **메뉴 정체성 > 재료 구성** 우선순위 계약.
/// 축약 티켓(146pt)은 아이콘 + 메뉴명뿐이라(§13.5) 대표 글리프가 곧 메뉴 식별자다 —
/// 재료에서 파생하면 "김밥"이 첫 재료(김)의 시트 글리프로 그려져 메뉴를 못 읽는다.
struct DishGlyphTests {

    @Test func gimbapRecipeUsesDishGlyphNotFirstIngredient() {
        // 사용자 커스텀 "김밥"(첫 비상비 재료 = 김) — 재료 폴백이면 .seaweed가 나오던 자리.
        let recipe = Recipe.userRecipe(name: "김밥", ingredientNames: ["김", "밥", "계란", "당근"],
                                       minutes: 30, steps: ["재료를 올리고 만다."])
        #expect(recipe.glyph == .gimbap)
    }

    @Test func dishTableDoesNotLeakIntoOtherRecipes() {
        // 표는 큐레이션 — 등재되지 않은 레시피는 재료 폴백 그대로여야 한다(회귀 가드).
        let eggRoll = Recipe.userRecipe(name: "계란말이", ingredientNames: ["계란", "대파"],
                                        minutes: 10, steps: ["말아 부친다."])
        #expect(eggRoll.glyph == .egg)
    }

    @Test func dishGlyphReadsBothLocaleSlots() {
        // 글리프는 시각 정체성이라 로케일로 그림이 바뀌면 안 된다 — 시드(en 서술형 + ko)와
        // 커스텀(현재 로케일 표기가 en 슬롯) 양쪽 표기가 모두 같은 모티프로 붙어야 한다.
        #expect(Recipe.dishGlyph(for: .init(en: "Gimbap (Seaweed Rice Rolls)", ko: "김밥")) == .gimbap)
        #expect(Recipe.dishGlyph(for: .init(en: "김밥", ko: nil)) == .gimbap)
        #expect(Recipe.dishGlyph(for: .init(en: " Kimbap ", ko: nil)) == .gimbap)   // 트림·소문자
        #expect(Recipe.dishGlyph(for: .init(en: "Beef Bulgogi", ko: "소불고기")) == nil)
    }

    @Test func gimbapMatchesAsIngredientNameButSheetsStaySeaweed() {
        #expect(FoodGlyph.match("김밥") == .gimbap)
        #expect(FoodGlyph.match("참치김밥") == .gimbap)      // 파생 표기도 같은 모티프
        // 아래 둘은 **요리 검사가 사전보다 먼저**여야만 통과한다(순서 회귀 가드):
        // 사전은 부분 문자열 매칭이라 "gimbap"→김(en "gim"), "참치김밥"→참치(tuna)로 조기 반환된다.
        #expect(FoodGlyph.match("gimbap") == .gimbap)
        #expect(FoodGlyph.match("Kimbap") == .gimbap)      // 대소문자 무관
    }

    @Test func gimbapSheetsFallBackToIngredientPath() {
        // 끝이 '김'이면 김밥에 **쓰는** 김 시트 — 가드가 요리 경로에서 빼고 사전이 .seaweed로 잡는다.
        #expect(FoodGlyph.match("김밥김") == .seaweed)
        #expect(FoodGlyph.match("김") == .seaweed)
        #expect(FoodGlyph.match("미역") == .seaweed)
        // "김밥용 김"은 사전에 없는 표기라 .generic으로 남는다(이번 변경 전과 동일) —
        // 여기서 고정하는 계약은 "롤로 뒤집히지 않는다" 하나다.
        #expect(FoodGlyph.match("김밥용 김") != .gimbap)
    }

    @Test func gimbapCategoryIsGrain() {
        // 요리지만 정체는 밥 — History 도넛에서 Other(잡동사니)로 새지 않게.
        #expect(FoodGlyph.gimbap.categoryLabel == "Grain")
    }
}
