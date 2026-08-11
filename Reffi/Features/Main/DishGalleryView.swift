import SwiftUI

/// 검증/미리보기용 — 시드 레시피 전체를 요리 아이콘 그리드로. 런치 인자 `-dishGallery`로 표시
/// (`-glyphGallery` 선례). 라벨은 한글명이라 원형이 같은 요리끼리 실제로 구분되는지 눈으로 대조된다.
///
/// 스크롤 화면이라 스크린샷은 첫 판밖에 못 담는다 — 80개 전수 대조는 오프스크린 콘택트 시트
/// (`DishContactSheetTests`)가 맡는다.
struct DishGalleryView: View {
    private let columns = [GridItem(.adaptive(minimum: 74), spacing: 10)]
    private let recipes = RecipeCatalog.loadSeed()
    /// `-dishGallery.archetype YES` — 라벨을 요리명 대신 **원형 이름**으로(클러스터 분포 확인용).
    private let showArchetype = UserDefaults.standard.bool(forKey: "dishGallery.archetype")

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(recipes) { recipe in
                    let look = DishGlyphCatalog.look(for: recipe)
                    VStack(spacing: 3) {
                        DishSilhouette(look: look)
                            .frame(width: 70, height: 70)
                            .background(ReffiColor.paper,
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        Text(verbatim: showArchetype ? look.archetype.koreanLabel
                                                     : (recipe.name.ko ?? recipe.name.en))
                            .reffiType(.metaText)
                            .foregroundStyle(ReffiColor.ink2)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .padding(16)
        }
        .background(ReffiColor.canvas.ignoresSafeArea())
    }
}
