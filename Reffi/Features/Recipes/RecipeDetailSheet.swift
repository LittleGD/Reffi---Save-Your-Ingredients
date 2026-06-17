import SwiftUI
import PhosphorSwift

/// 레시피 상세 — 카드 탭 시 바텀시트. 임박재료 소비/부족재료/조리시간.
struct RecipeDetailSheet: View {
    let result: RecipeRecommender.Result
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let r = result.recipe
        ScrollView {
            VStack(alignment: .leading, spacing: ReffiSpace.s5) {
                ZStack {
                    FoodPalette.heroTint(r.glyph)
                    FoodHeroMotif(glyph: r.glyph).padding(ReffiSpace.s5)
                }
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: ReffiRadius.xl, style: .continuous))

                HStack(alignment: .firstTextBaseline) {
                    Text(r.name)
                        .reffiType(.heading)
                        .foregroundStyle(ReffiColor.ink)
                    Spacer()
                    HStack(spacing: ReffiSpace.s1) {
                        ReffiIcon.time.reffi(15)
                        Text("\(r.minutes)분").font(.reffiNum(15, relativeTo: .title3))
                    }
                    .foregroundStyle(ReffiColor.ink2)
                }

                section("이 레시피로 소비할 재료") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: ReffiSpace.s2) {
                            ForEach(result.used) { FreshnessChip(ingredient: $0) }
                        }
                    }
                }

                if !result.missing.isEmpty {
                    section("부족한 재료") {
                        Text(result.missing.joined(separator: "  ·  "))
                            .reffiType(.body)
                            .foregroundStyle(ReffiColor.ink2)
                    }
                }

                ReffiButton(title: "조리 시작", icon: ReffiIcon.cook, fullWidth: true) { dismiss() }
                    .padding(.top, ReffiSpace.s2)
            }
            .padding(ReffiSpace.s5)
        }
        .background(ReffiColor.canvas)
        .presentationDragIndicator(.visible)
        .presentationDetents([.medium, .large])
    }

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s2) {
            Text(title)
                .reffiType(.caption)
                .foregroundStyle(ReffiColor.ink2)
            content()
        }
    }
}
