import SwiftUI

/// 카드 스택의 한 장 (§8.3 애너토미).
/// 보이는 띠 상단에 카테고리 · 이름 · D-N. 면 색은 신선도 main, 글자는 ink.
struct IngredientCardView: View {
    let ingredient: Ingredient

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s1) {
            // 카테고리 — Caption, neutral-700 솔리드(불투명도 X)
            Text(ingredient.category)
                .reffiText(ReffiType.caption)
                .foregroundStyle(ReffiColor.ink2)

            HStack(alignment: .firstTextBaseline) {
                // 이름 — Subhead
                Text(ingredient.name)
                    .reffiText(ReffiType.subhead)
                    .foregroundStyle(ReffiColor.ink)

                Spacer(minLength: Space.s4)

                // D-N — Subhead, tabular
                Text(ingredient.countdownLabel)
                    .reffiText(ReffiType.subhead)
                    .num()
                    .foregroundStyle(ReffiColor.ink)
            }
        }
        .padding(.horizontal, Space.s5)
        .padding(.top, Space.s4)
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
        .background(ingredient.freshness.color)
        .clipShape(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
        .reffiStackShadow()
    }
}
