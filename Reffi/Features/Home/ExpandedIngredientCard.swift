import SwiftUI
import PhosphorSwift

/// 펼친 "먼저 먹기" 카드 — 가장 급한 재료. 재료 · 소비량 · 제1액션만 노출.
/// 대안액션은 여기서 제거(사용자 요청) → 단일 명확한 CTA로 하이라키를 분명히.
struct ExpandedIngredientCard: View {
    let ingredient: Ingredient
    var style: CardStyle = .current
    var onPrimary: () -> Void = {}

    var body: some View {
        let f = ingredient.freshness
        HStack(spacing: 0) {
            if style.usesRail {
                f.main.frame(width: 6)
            }
            VStack(alignment: .leading, spacing: ReffiSpace.s4) {
                // 넛지
                HStack(spacing: ReffiSpace.s1) {
                    ReffiIcon.countdown.reffi(15, .bold)
                    Text("지금 먼저 먹어요").reffiType(.caption)
                }
                .foregroundStyle(ReffiColor.ink2)

                // 헤더: 카테고리 · 이름 + D-N
                VStack(alignment: .leading, spacing: 2) {
                    Text(ingredient.category)
                        .reffiType(.caption)
                        .foregroundStyle(ReffiColor.ink2)
                    HStack(alignment: .firstTextBaseline, spacing: ReffiSpace.s3) {
                        Text(ingredient.name)
                            .reffiType(.heading)
                            .foregroundStyle(ReffiColor.ink)
                        Spacer(minLength: ReffiSpace.s2)
                        dayBlock(f)
                    }
                }

                // 소비량
                infoRow(label: "소비량", value: ingredient.amount)

                // 제1액션 — 단일 CTA(대안액션 제거)
                ReffiButton(title: "레시피 찾기", icon: ReffiIcon.recipe, fullWidth: true, action: onPrimary)
                    .padding(.top, ReffiSpace.s1)
            }
            .padding(ReffiSpace.s5)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(style.surface(f, depth: 0))
        .clipShape(RoundedRectangle(cornerRadius: ReffiRadius.xl, style: .continuous))
        .modifier(CardLift(style: style))
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: ReffiSpace.s3) {
            Text(label)
                .reffiType(.caption)
                .foregroundStyle(ReffiColor.ink2)
                .frame(width: 44, alignment: .leading)
            Text(value)
                .reffiType(.body)
                .foregroundStyle(ReffiColor.ink)
        }
    }

    @ViewBuilder private func dayBlock(_ f: Freshness) -> some View {
        if style.dayAsBadge {
            VStack(alignment: .trailing, spacing: 4) {
                Text(ingredient.dDayText)
                    .font(.reffiNum(20, relativeTo: .title))
                    .foregroundStyle(.white)
                    .padding(.horizontal, ReffiSpace.s3)
                    .padding(.vertical, 3)
                    .background(f.dark, in: Capsule())
                Text(f.label)
                    .reffiType(.caption)
                    .foregroundStyle(ReffiColor.ink2)
            }
        } else {
            VStack(alignment: .trailing, spacing: 0) {
                Text(ingredient.dDayText)
                    .font(.reffiNum(28, relativeTo: .largeTitle))
                    .foregroundStyle(style.dayColor(f))
                Text(f.label)
                    .reffiType(.caption)
                    .foregroundStyle(ReffiColor.ink2)
            }
        }
    }
}
