import SwiftUI
import SwiftData

/// 냉장고 탭 — 전체 재료 카드 스택(§8). 마감 임박 오름차순, 위에서부터 먹는 순서.
struct FridgeView: View {
    @Query(sort: \Ingredient.expiryDate, order: .forward)
    private var ingredients: [Ingredient]

    /// 카드 겹침(§8.2): 보이는 띠 ~50pt.
    private let overlap: CGFloat = -54

    var body: some View {
        ZStack {
            ReffiColor.canvas.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Space.s5) {
                    header

                    if ingredients.isEmpty {
                        emptyState
                    } else {
                        cardStack
                    }
                }
                .padding(.horizontal, Space.s4)
                .padding(.top, Space.s5)
                .padding(.bottom, Space.s7)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.s1) {
            Text("Fridge")
                .reffiText(ReffiType.heading)
                .foregroundStyle(ReffiColor.ink)
            Text("Eat from the top")
                .reffiText(ReffiType.caption)
                .foregroundStyle(ReffiColor.ink2)
        }
    }

    private var cardStack: some View {
        VStack(spacing: overlap) {
            ForEach(Array(ingredients.enumerated()), id: \.element.persistentModelID) { index, item in
                IngredientCardView(ingredient: item)
                    // §8.2 인접 카드 미세 명도 단차로 깊이감 (한 칸씩 약 3% 어둡게 교차)
                    .brightness(index.isMultiple(of: 2) ? 0 : -0.03)
                    .zIndex(Double(ingredients.count - index))
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            Text("Nothing here yet")
                .reffiText(ReffiType.subhead)
                .foregroundStyle(ReffiColor.ink)
            Text("Scan a receipt and fresh items stack up automatically")
                .reffiText(ReffiType.body)
                .foregroundStyle(ReffiColor.ink2)
        }
        .padding(Space.s5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ReffiColor.neutral200)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
    }
}

#Preview {
    FridgeView()
        .modelContainer(for: Ingredient.self, inMemory: true)
}
