import SwiftUI

/// 검증/미리보기용 — 모든 `FoodGlyph` 실루엣을 한 화면 그리드로. 런치 인자 `-glyphGallery`로 표시.
/// `-glyphGallery.wilted YES`를 함께 주면 **전 타일을 `.urgent`로 못 박아** 같은 인자 없이 찍은
/// 기본 컨택트 시트와 A/B로 겹쳐 볼 수 있다(기본은 fresh/soon/urgent를 3주기로 섞어 보여준다).
struct GlyphGalleryView: View {
    // 53종을 스크롤 그리드로 — 컴팩트 타일(전 글리프를 자가 검증).
    private let columns = [GridItem(.adaptive(minimum: 74), spacing: 10)]
    private let freshes: [Freshness] = [.fresh, .soon, .urgent]
    private let forceWilted = UserDefaults.standard.bool(forKey: "glyphGallery.wilted")

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Array(FoodGlyph.allCases.enumerated()), id: \.offset) { i, glyph in
                    VStack(spacing: 3) {
                        PaperSilhouette(glyph: glyph,
                                        fresh: forceWilted ? .urgent : freshes[i % freshes.count])
                            .frame(width: 70, height: 70)
                            .background(ReffiColor.paper,
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        Text(verbatim: glyph.rawValue)
                            .reffiType(.metaText)
                            .foregroundStyle(ReffiColor.ink2)
                    }
                }
            }
            .padding(16)
        }
        .background(ReffiColor.canvas.ignoresSafeArea())
    }
}
