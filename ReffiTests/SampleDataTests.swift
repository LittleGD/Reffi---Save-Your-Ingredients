import Testing
import Foundation
@testable import Reffi

/// SampleData 불변식 — 데모 재고/이력은 코드 리터럴이 아니라 정본 사전에서 조립된다.
/// ① 캐논 ID 오타가 조용히 줄을 지우지 않는다(개수 고정) ② 선언된 글리프가 `FoodGlyph.match(name)`과
/// 어긋나지 않는다(매칭 키가 사전 표제어와 다른 축으로 갈라지던 사고 방지) ③ 카테고리가 카탈로그에
/// 등록된 전수 집합(`FoodGlyph.categoryOrder`) 안에 있다 — 예전 합성 라벨("Meat · Beef")이 한국어
/// 기기에서 미번역 영문으로 새던 회귀를 여기서 막는다.
struct SampleDataTests {

    @Test func ingredientsAssembleFromLexicon() {
        #expect(SampleData.ingredients.count == SampleData.expectedIngredientCount)
        for ing in SampleData.ingredients {
            #expect(ing.canonicalID != nil, "\(ing.name): 사전 캐논 ID가 비었다")
            #expect(!ing.name.isEmpty)
        }
    }

    @Test func historyAssemblesFromLexicon() {
        #expect(SampleData.history.count == SampleData.expectedHistoryCount)
        for log in SampleData.history {
            #expect(log.canonicalID != nil, "\(log.name): 사전 캐논 ID가 비었다")
        }
    }

    @Test func ingredientGlyphsMatchLexicon() {
        for ing in SampleData.ingredients {
            #expect(ing.glyph == FoodGlyph.match(ing.name),
                    "\(ing.name): declared \(ing.glyph) but FoodGlyph.match(name) resolves to \(FoodGlyph.match(ing.name))")
        }
    }

    @Test func historyGlyphsMatchLexicon() {
        for log in SampleData.history {
            #expect(log.glyph == FoodGlyph.match(log.name),
                    "\(log.name): declared \(log.glyph) but FoodGlyph.match(name) resolves to \(FoodGlyph.match(log.name))")
        }
    }

    /// 카테고리는 표시 문자열이 아니라 카탈로그 키다 — 합성 라벨이 다시 새지 않게 전수 집합으로 고정.
    @Test func categoriesAreCanonicalKeys() {
        for ing in SampleData.ingredients {
            #expect(FoodGlyph.categoryOrder.contains(ing.category),
                    "\(ing.name): category '\(ing.category)'가 FoodGlyph.categoryOrder 밖이다")
            #expect(ing.category == ing.glyph.categoryLabel)
        }
    }
}
