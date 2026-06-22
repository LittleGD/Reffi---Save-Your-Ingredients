import SwiftUI

/// 카드 스택의 한 장 — 영수증 한 조각(§8.3 애너토미).
/// 톱니 가장자리(`ReceiptShape`) + 신선도 색 종이 + 인쇄 그레인.
/// 보이는 띠 상단에 카테고리 · [아이콘] 이름 · D-N, 하단에 점선 + 미니 바코드.
/// 면 색은 신선도 연속 램프, 글자색은 면 휘도에 따라 흰색/ink 적응.
struct IngredientCardView: View {
    let ingredient: Ingredient

    private let toothH: CGFloat = 6

    var body: some View {
        let category = IngredientCategory(raw: ingredient.category)
        let white = ReffiColor.freshnessPrefersWhiteText(daysLeft: ingredient.daysLeft)
        let fg = ReffiColor.ink                          // 식품명·D-N·아이콘: 항상 검정 잉크
        let fg2 = white ? Color.white : ReffiColor.ink2  // 카테고리(보조): 어두운 면 흰색
        let shape = ReceiptShape(toothHeight: toothH)

        return VStack(alignment: .leading, spacing: Space.s1) {
            // 카테고리 — 영수증 모노스페이스 대문자
            Text(category.label.uppercased())
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .tracking(1)
                .foregroundStyle(fg2)

            HStack(alignment: .center, spacing: Space.s3) {
                CategoryStamp(category: category, size: 46)

                HStack(alignment: .firstTextBaseline) {
                    Text(ingredient.name)
                        .reffiText(ReffiType.subhead)
                        .foregroundStyle(fg)

                    Spacer(minLength: Space.s4)

                    Text(ingredient.countdownLabel)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(fg)
                }
            }
        }
        .padding(.horizontal, Space.s5)
        .padding(.top, Space.s4 + toothH)
        .padding(.bottom, Space.s3 + toothH)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .background(ReffiColor.freshnessFill(daysLeft: ingredient.daysLeft), in: shape)
        .paperGrain(shape)
        .reffiStackShadow()
    }
}
