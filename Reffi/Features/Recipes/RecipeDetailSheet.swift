import SwiftUI
import PhosphorSwift

/// Recipe detail — half-sheet from a tap or a right-swipe. The single hub where you Start cooking.
struct RecipeDetailSheet: View {
    let result: RecipeRecommender.Result
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let r = result.recipe
        ScrollView {
            VStack(alignment: .leading, spacing: ReffiSpace.s5) {
                ZStack {
                    (result.used.first?.freshness ?? .fresh).face(depth: 0)
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
                        Text("\(r.minutes) min").font(.reffiNum(15, relativeTo: .title3))
                    }
                    .foregroundStyle(ReffiColor.ink2)
                }

                section("Ingredients you'll use") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: ReffiSpace.s2) {
                            ForEach(result.used) { FreshnessChip(ingredient: $0) }
                        }
                    }
                }

                if !result.missing.isEmpty {
                    section("You're missing") {
                        Text(result.missing.joined(separator: "  ·  "))
                            .reffiType(.body)
                            .foregroundStyle(ReffiColor.ink2)
                    }
                }

                PaperButton(title: "Start cooking", fullWidth: true) { dismiss() }
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
