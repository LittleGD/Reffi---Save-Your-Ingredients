import SwiftUI

/// 검증/미리보기용 — 모든 `FoodGlyph` 실루엣을 한 화면 그리드로. 런치 인자 `-glyphGallery`로 표시.
struct GlyphGalleryView: View {
    // 53종을 스크롤 그리드로 — 컴팩트 타일(전 글리프를 자가 검증).
    private let columns = [GridItem(.adaptive(minimum: 74), spacing: 10)]
    private let freshes: [Freshness] = [.fresh, .soon, .urgent]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Array(FoodGlyph.allCases.enumerated()), id: \.offset) { i, glyph in
                    VStack(spacing: 3) {
                        PaperSilhouette(glyph: glyph, fresh: freshes[i % freshes.count])
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
