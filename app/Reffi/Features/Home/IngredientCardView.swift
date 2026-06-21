import SwiftUI

/// 카드 스택의 한 장 (§8.3 애너토미).
/// 보이는 띠 상단에 카테고리 · [아이콘] 이름 · D-N.
/// 면 색은 신선도 연속 램프, 글자색은 면 휘도에 따라 흰색/ink 적응.
struct IngredientCardView: View {
    let ingredient: Ingredient

    var body: some View {
        let category = IngredientCategory(raw: ingredient.category)
        let white = ReffiColor.freshnessPrefersWhiteText(daysLeft: ingredient.daysLeft)
        let fg = ReffiColor.ink                          // 식품명·D-N·아이콘: 항상 검정
        let fg2 = white ? Color.white : ReffiColor.ink2  // 카테고리(보조): 빨강~노랑 흰색, 초록 검정
        return VStack(alignment: .leading, spacing: Space.s1) {
            // 카테고리 — Caption
            Text(category.label)
                .reffiText(ReffiType.caption)
                .foregroundStyle(fg2)

            HStack(alignment: .center, spacing: Space.s2) {
                // 카테고리 아이콘 — 디자이너 에셋 우선, 없으면 Phosphor 폴백(§5).
                CategoryIcon(category: category)
                    .foregroundStyle(fg)

                // 이름 · D-N — Subhead, 한 베이스라인 공유
                HStack(alignment: .firstTextBaseline) {
                    Text(ingredient.name)
                        .reffiText(ReffiType.subhead)
                        .foregroundStyle(fg)

                    Spacer(minLength: Space.s4)

                    countdown(ingredient.countdownLabel).foregroundStyle(fg)
                }
            }
        }
        .padding(.horizontal, Space.s5)
        .padding(.top, Space.s4)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .background(ReffiColor.freshnessFill(daysLeft: ingredient.daysLeft))
        .clipShape(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
        .reffiStackShadow()
    }

    /// D-N 라벨 — subhead의 음수 자간(-0.18pt)이 "D-14"에서 어색해 자간 0으로 두고 tabular 숫자.
    @ViewBuilder
    func countdown(_ text: String) -> some View {
        Text(text)
            .font(ReffiType.font(ReffiType.subhead))
            .tracking(0)
            .monospacedDigit()
    }
}
