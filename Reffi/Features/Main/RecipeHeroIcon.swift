import SwiftUI

/// 레시피 대표 아이콘의 **정체** — 완성된 요리로 그릴지(`DishSilhouette` §13.4), 재료로 그릴지
/// (`PaperSilhouette` §13.3). 두 일러스트 시스템이 공존하므로 어느 쪽인지는 **모델이 정하고
/// 뷰는 switch로 렌더만 한다** — 뷰마다 조건을 다시 쓰면 같은 레시피가 표면마다 다른 그림이 된다
/// (축약 티켓의 히어로와 펼침 티켓의 아이콘이 갈리는 식).
enum RecipeHeroIcon: Equatable {
    /// 요리 그림 — 원형 + 변주(`DishGlyphCatalog`).
    case dish(DishLook)
    /// 재료 그림 — 요리형 글리프(김밥 등) 또는 첫 비상비 재료(`FoodGlyph`).
    case food(FoodGlyph)
}

extension Recipe {

    /// 티켓 히어로 아이콘 — **요리 정체성 카탈로그 우선, 커스텀 요리명은 큐레이션 표, 최후엔 재료**.
    ///
    /// ① **시드 매핑 표**(`DishGlyphCatalog.table`) — 손으로 배정한 80종의 정본 요리 그림.
    /// ② **요리형 글리프 큐레이션 표**(`FoodGlyph.dishKeywords`) — 김밥처럼 *그려 둔 요리 그림이 있는* 이름.
    ///    카탈로그의 이름 추론(③)보다 **앞서야** 한다: 추론은 원형만 맞히고 색·고명은 id 해시로 흔들어
    ///    커스텀 "김밥"이 아무 색 롤이 된다 — 손으로 그린 김밥이 있는데 짐작으로 덮을 이유가 없다.
    /// ③ **카탈로그 이름 추론** — 이름이 요리를 지목할 때만("된장찌개" → 뚝배기, "새우 파스타" → 접시).
    /// ④ **재료 글리프**(`glyph`) — 이름이 아무 요리도 지목하지 않을 때. cuisine 기본값만 보고
    ///    "한식이니 찌개"라고 단정하느니, 실제로 들어가는 재료를 보여주는 편이 정직하다.
    ///
    /// 축약 티켓은 아이콘 + 메뉴명뿐이라(§13.5) 이 값이 곧 메뉴 식별자다 — 재료에서 파생하면
    /// 비빔밥이 시금치 잎으로, 김밥이 김 시트로 뜬다.
    var heroIcon: RecipeHeroIcon {
        if let curated = DishGlyphCatalog.curatedLook(id: id) { return .dish(curated) }
        if let dish = Self.dishGlyph(for: name) { return .food(dish) }
        if let named = DishGlyphCatalog.nameMatchedLook(for: self) { return .dish(named) }
        return .food(glyph)
    }
}

/// 대표 아이콘 렌더 — 정체는 `Recipe.heroIcon`이 정하고 여기선 그리기만 한다.
/// 크기는 호출부가 `.frame`으로 준다(둘 다 `Canvas`라 어느 크기에서도 같은 그림).
/// 두 실루엣 모두 `accessibilityHidden` 장식이라 읽히는 정보는 옆·아래의 메뉴명이 맡는다.
struct RecipeHeroIconView: View {
    let icon: RecipeHeroIcon

    var body: some View {
        switch icon {
        case .dish(let look):
            DishSilhouette(look: look)
        case .food(let glyph):
            // `fresh:`는 색에 쓰이지 않는 시그니처 유지용 인자다 — 색은 신선도 코딩과 분리(§13.3)라
            // 티켓 글리프는 재료의 남은 기한과 무관하게 항상 같은 톤으로 그려야 한다.
            PaperSilhouette(glyph: glyph, fresh: .fresh)
        }
    }
}
