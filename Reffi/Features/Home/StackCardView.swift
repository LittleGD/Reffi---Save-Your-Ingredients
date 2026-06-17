import SwiftUI

/// 카드 스택의 접힌 띠(§8.3) — 카테고리 + 이름 + D-N. 디자인은 CardStyle로 전환.
/// 분리는 색이 아니라 면 대비 + 아주 옅은 그림자(라벨에 드롭섀도 금지).
struct StackCardView: View {
    let ingredient: Ingredient
    var style: CardStyle = .current
    var depth: Int = 0
    var height: CGFloat = 96
    var onTap: () -> Void = {}

    var body: some View {
        let f = ingredient.freshness
        Button(action: onTap) {
            HStack(spacing: 0) {
                if style.usesRail {
                    f.main.frame(width: 5)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(ingredient.category)
                        .reffiType(.caption)
                        .foregroundStyle(ReffiColor.ink2)
                    HStack(alignment: .firstTextBaseline, spacing: ReffiSpace.s3) {
                        Text(ingredient.name)
                            .reffiType(.subhead)
                            .foregroundStyle(ReffiColor.ink)
                        Spacer(minLength: ReffiSpace.s2)
                        dayView(f)
                    }
                }
                .padding(.leading, style.usesRail ? ReffiSpace.s4 : ReffiSpace.s5)
                .padding(.trailing, ReffiSpace.s5)
                .padding(.top, ReffiSpace.s4)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, minHeight: height, alignment: .topLeading)
            .background(style.surface(f, depth: depth))
            .clipShape(RoundedRectangle(cornerRadius: ReffiRadius.xl, style: .continuous))
            .modifier(CardLift(style: style))
            .contentShape(RoundedRectangle(cornerRadius: ReffiRadius.xl, style: .continuous))
        }
        .buttonStyle(.reffiPress)
        .accessibilityLabel("\(ingredient.category) \(ingredient.name), \(ingredient.dDayText)")
    }

    @ViewBuilder private func dayView(_ f: Freshness) -> some View {
        if style.dayAsBadge {
            Text(ingredient.dDayText)
                .font(.reffiNum(15, relativeTo: .subheadline))
                .foregroundStyle(.white)
                .padding(.horizontal, ReffiSpace.s2)
                .padding(.vertical, 3)
                .background(f.dark, in: Capsule())
        } else {
            Text(ingredient.dDayText)
                .font(.reffiNum(18, relativeTo: .title3))
                .foregroundStyle(style.dayColor(f))
        }
    }
}
