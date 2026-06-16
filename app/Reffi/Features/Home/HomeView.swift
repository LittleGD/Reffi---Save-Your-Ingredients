import SwiftUI
import SwiftData

/// Home tab — the "what to cook" dashboard.
/// Shows AI recipe picks built from the real fridge, filtered by category, as a Tinder-style deck.
struct HomeView: View {
    @Query(sort: \Ingredient.expiryDate, order: .forward)
    private var ingredients: [Ingredient]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedCategory: FoodCategory = .all
    @State private var toast: String?

    private var recommendations: [RecipeSuggestion] {
        RecipeSuggestion.recommend(from: ingredients, category: selectedCategory)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ReffiColor.canvas.ignoresSafeArea()

            VStack(alignment: .leading, spacing: Space.s4) {
                header
                CategorySelector(selected: $selectedCategory)
                RecipeDeckView(
                    suggestions: recommendations,
                    onCook: cook,
                    onPass: { _ in }
                )
            }
            .padding(.horizontal, Space.s4)
            .padding(.top, Space.s5)
            .padding(.bottom, Space.s5)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            if let toast {
                toastView(toast)
                    .padding(.bottom, Space.s4)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // Brand moment — Story Script display (§3.1).
    private var header: some View {
        Text("What to cook?")
            .reffiText(ReffiType.display)
            .foregroundStyle(ReffiColor.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func toastView(_ text: String) -> some View {
        Text(text)
            .reffiText(ReffiType.caption)
            .foregroundStyle(.white)
            .padding(.horizontal, Space.s4)
            .padding(.vertical, Space.s3)
            .background(ReffiColor.ink)
            .clipShape(Capsule())
            .reffiFloatingShadow()
    }

    /// Cook chosen → confirmation toast. (Ingredient consumption persistence is a later step.)
    private func cook(_ recipe: RecipeSuggestion) {
        showToast("Cooking ‘\(recipe.title)’ today. Enjoy!")
    }

    private func showToast(_ text: String) {
        withAnimation(reduceMotion ? nil : ReffiMotion.easeOut) { toast = text }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(reduceMotion ? nil : ReffiMotion.easeIn) { toast = nil }
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(for: Ingredient.self, inMemory: true)
}
