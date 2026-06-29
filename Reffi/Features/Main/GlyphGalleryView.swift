import SwiftUI

/// 검증/미리보기용 — 모든 `FoodGlyph` 실루엣을 한 화면 그리드로. 런치 인자 `-glyphGallery`로 표시.
struct GlyphGalleryView: View {
    private let columns = [GridItem(.adaptive(minimum: 92), spacing: 14)]
    private let freshes: [Freshness] = [.fresh, .soon, .urgent]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(Array(FoodGlyph.allCases.enumerated()), id: \.offset) { i, glyph in
                    VStack(spacing: 4) {
                        PaperSilhouette(glyph: glyph, fresh: freshes[i % freshes.count])
                            .frame(width: 88, height: 88)
                            .background(ReffiColor.paper,
                                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        Text("\(glyph)")
                            .font(.custom("Pretendard-Medium", size: 11, relativeTo: .caption2))
                            .foregroundStyle(ReffiColor.ink2)
                    }
                }
            }
            .padding(20)
        }
        .background(ReffiColor.canvas.ignoresSafeArea())
    }
}
