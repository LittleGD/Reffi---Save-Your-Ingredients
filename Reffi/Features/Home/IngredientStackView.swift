import SwiftUI

/// 냉장고 카드 스택 — 맨 위는 항상 "가장 급한" 재료(펼침), 그 아래 지갑형 띠.
/// 정렬은 마감 임박 오름차순으로 고정(§8.1): 탭으로 순서가 바뀌지 않는다.
struct IngredientStackView: View {
    @Environment(FridgeStore.self) private var store
    var style: CardStyle = .current
    var onSelect: (Ingredient) -> Void = { _ in }

    var body: some View {
        let all = store.sorted
        let featured = all.first
        let rest = Array(all.dropFirst())

        VStack(alignment: .leading, spacing: ReffiSpace.s4) {
            HStack(alignment: .firstTextBaseline, spacing: ReffiSpace.s2) {
                Text("냉장고")
                    .reffiType(.subhead)
                    .foregroundStyle(ReffiColor.ink)
                Text("먼저 먹어야 할 순서")
                    .reffiType(.caption)
                    .foregroundStyle(ReffiColor.ink2)
                Spacer()
                Text("\(all.count)개")
                    .font(.reffiNum(14, relativeTo: .caption))
                    .foregroundStyle(ReffiColor.ink2)
            }

            if let featured {
                ExpandedIngredientCard(ingredient: featured, style: style)
            }

            WalletStack(ingredients: rest, style: style, onTap: onSelect)
        }
    }
}

/// 지갑형 스택 — 음수 간격으로 겹치고, 뒤(아래) 카드가 위로 올라온다. 보이는 띠 = 카드 상단.
private struct WalletStack: View {
    let ingredients: [Ingredient]
    var style: CardStyle
    var onTap: (Ingredient) -> Void

    private let collapsedHeight: CGFloat = 96
    private let overlap: CGFloat = 40   // 보이는 띠 = 96 − 40 = 56

    var body: some View {
        VStack(spacing: -overlap) {
            ForEach(Array(ingredients.enumerated()), id: \.element.id) { index, ingredient in
                StackCardView(ingredient: ingredient, style: style,
                              depth: index + 1, height: collapsedHeight) {
                    onTap(ingredient)
                }
                .zIndex(Double(index))
            }
        }
    }
}
