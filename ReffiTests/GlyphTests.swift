import Testing
import Foundation
@testable import Reffi

/// FoodGlyph — 52종 확장(각진 컷페이퍼) 후 카테고리 라벨 파생·케이스 목록·톨러런트 디코드 가드.
/// 재료명→글리프 라우팅(`match`)은 1순위 정본 사전이 결정하므로, 사전 글리프 값 재배정
/// 이후에 그쪽에서 검증한다(이 스위트는 enum 자체의 결정론적 계약만 지킨다).
struct GlyphTests {

    @Test func caseCountIs52() {
        // 35종 + v2 신규 17종(eggplant·sweetPotato·ginger·seaweed·grape·watermelon·pineapple·mango·
        // sausage·bacon·crab·squid·clam·yogurt·butter·honey·dumpling).
        #expect(FoodGlyph.allCases.count == 52)
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
