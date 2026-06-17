import SwiftUI
import PhosphorSwift

/// 이미지-포워드 레시피 카드(방향 B) — 큰 색면 일러스트가 주인공.
/// 임박재료 칩(신선도색)·시간만 최소 노출, 하단 솔리드 띠에 이름 + 매치. 드래그 스탬프 포함.
struct SwipeCardView: View {
    let result: RecipeRecommender.Result
    var drag: CGSize = .zero
    var isTop: Bool = false

    var body: some View {
        let r = result.recipe
        ZStack {
            FoodPalette.heroTint(r.glyph)

            FoodHeroMotif(glyph: r.glyph)
                .padding(.horizontal, ReffiSpace.s5)
                .padding(.top, ReffiSpace.s6)
                .padding(.bottom, 92)

            // 상단: 임박 칩 + 시간
            VStack {
                HStack(alignment: .top) {
                    if let urgent = result.used.first {
                        FreshnessChip(ingredient: urgent)
                    }
                    Spacer()
                    HStack(spacing: ReffiSpace.s1) {
                        ReffiIcon.time.reffi(14)
                        Text("\(r.minutes)분").font(.reffiNum(14, relativeTo: .caption))
                    }
                    .foregroundStyle(ReffiColor.ink2)
                    .padding(.horizontal, ReffiSpace.s3)
                    .padding(.vertical, ReffiSpace.s1)
                    .background(ReffiColor.canvas.opacity(0.92), in: Capsule())
                }
                Spacer()
            }
            .padding(ReffiSpace.s4)

            // 하단 솔리드 정보 띠
            VStack {
                Spacer()
                bottomStrip(r)
            }

            stamps
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(0.72, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: ReffiRadius.xl, style: .continuous))
        .reffiShadow1()
    }

    private func bottomStrip(_ r: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(r.name)
                .reffiType(.heading)
                .foregroundStyle(ReffiColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            HStack(spacing: ReffiSpace.s2) {
                if result.urgentUsedCount > 0 {
                    metaText("오늘 쓸 재료 \(result.urgentUsedCount)개", ReffiColor.urgentDark)
                } else {
                    metaText("임박 재료 \(result.used.count)개", ReffiColor.ink2)
                }
                Text("·").foregroundStyle(ReffiColor.muted)
                metaText("보유 \(result.used.count)/\(result.total)", ReffiColor.ink2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ReffiSpace.s5)
        .background(ReffiColor.canvas)
    }

    private func metaText(_ t: String, _ color: Color) -> some View {
        Text(t).font(.reffiNum(14, relativeTo: .caption)).foregroundStyle(color)
    }

    private var stamps: some View {
        ZStack {
            stamp("자세히", ReffiIcon.go, ReffiColor.blue, leading: true,
                  opacity: Double(max(0, min(1, drag.width / 80))))
            stamp("넘기기", ReffiIcon.close, ReffiColor.muted, leading: false,
                  opacity: Double(max(0, min(1, -drag.width / 80))))
        }
    }

    private func stamp(_ text: String, _ icon: Ph, _ color: Color, leading: Bool, opacity: Double) -> some View {
        HStack(spacing: ReffiSpace.s1) {
            if leading { icon.reffi(20, .bold) }
            Text(text).reffiType(.heading)
            if !leading { icon.reffi(20, .bold) }
        }
        .foregroundStyle(color)
        .rotationEffect(.degrees(leading ? -10 : 10))
        .padding(ReffiSpace.s6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: leading ? .topLeading : .topTrailing)
        .opacity(opacity)
        .allowsHitTesting(false)
    }
}
