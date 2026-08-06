import Testing
import Foundation
@testable import Reffi

/// SampleData 불변식 — 선언된 글리프가 `FoodGlyph.match(name)`과 어긋나면 그 항목의 매칭 키가
/// 사전 표제어와 다른 축으로 갈라진다("Strawberries"가 사전 "strawberry"와 다른 키를 받아 To buy
/// 픽커에서 체크가 안 붙고 중복 줄이 생기던 사고, `ingredient-lexicon.json`의 복수형 별칭으로 해소).
/// 손입력 오타(바나나 `.apple`, 요거트 `.milk`)의 재발 방지책도 이 테스트다 — 사전이 바뀌어도,
/// SampleData 표기가 바뀌어도 여기서 즉시 드러난다.
struct SampleDataTests {

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
}
