import SwiftUI
import PhosphorSwift

/// 펼친(Wallet) 상태의 카드 — 신선도 색 면 한 장 안에 헤더 + 상세 정보를 함께 담는다.
/// 헤더는 접힌 `IngredientCardView`와 같은 레이아웃이라 matchedGeometry 모핑이 매끄럽다.
/// 기본 글자(이름·값·D-N)는 검정, 보조 글자(카테고리·라벨)는 어두운 면이면 흰색으로 적응.
struct ExpandedIngredientCard: View {
    let ingredient: Ingredient
    var onEdit: () -> Void = {}

    var body: some View {
        let category = IngredientCategory(raw: ingredient.category)
        let white = ReffiColor.freshnessPrefersWhiteText(daysLeft: ingredient.daysLeft)
        let fg2 = white ? Color.white : ReffiColor.ink2         // 보조: 빨강~노랑 흰색, 초록 검정
        let line = white ? Color.white.opacity(0.22) : ReffiColor.ink.opacity(0.10)

        return VStack(alignment: .leading, spacing: 0) {
            header(category, fg2: fg2)

            Rectangle()
                .fill(line)
                .frame(height: 1)
                .padding(.horizontal, Space.s5)

            VStack(spacing: 0) {
                row("Purchased", dateText(ingredient.addedDate), fg2: fg2)
                divider(line)
                row("Where", show(ingredient.purchasePlace), fg2: fg2)
                divider(line)
                row("Quantity", show(ingredient.quantity), fg2: fg2)
                divider(line)
                row("Expires", "\(dateText(ingredient.expiryDate)) · \(ingredient.countdownLabel)", fg2: fg2)
                divider(line)
                row("Storage", show(ingredient.storage), fg2: fg2)
            }
            .padding(.horizontal, Space.s5)
            .padding(.vertical, Space.s2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ReffiColor.freshnessFill(daysLeft: ingredient.daysLeft))
        .clipShape(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
        .reffiStackShadow()
    }

    // MARK: 헤더 — IngredientCardView와 동일 구성(카테고리 · [아이콘] 이름 · D-N)
    private func header(_ category: IngredientCategory, fg2: Color) -> some View {
        VStack(alignment: .leading, spacing: Space.s1) {
            HStack(spacing: Space.s2) {
                Text(category.label)
                    .reffiText(ReffiType.caption)
                    .foregroundStyle(fg2)
                Spacer()
                // 편집 — 카드 오른쪽 위 펜슬
                Button(action: onEdit) {
                    ReffiIcon.edit.reffi(18, .bold)
                        .foregroundStyle(ReffiColor.ink)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(ReffiPressStyle())
                .accessibilityLabel("Edit item")
            }

            HStack(alignment: .center, spacing: Space.s2) {
                CategoryIcon(category: category)
                    .foregroundStyle(ReffiColor.ink)

                HStack(alignment: .firstTextBaseline) {
                    Text(ingredient.name)
                        .reffiText(ReffiType.subhead)
                        .foregroundStyle(ReffiColor.ink)

                    Spacer(minLength: Space.s4)

                    // D-N — subhead, 자간 0 + tabular (음수 자간 어색함 방지).
                    Text(ingredient.countdownLabel)
                        .font(ReffiType.font(ReffiType.subhead))
                        .tracking(0)
                        .monospacedDigit()
                        .foregroundStyle(ReffiColor.ink)
                }
            }
        }
        .padding(.horizontal, Space.s5)
        .padding(.top, Space.s4)
        .padding(.bottom, Space.s4)
    }

    private func row(_ label: String, _ value: String, fg2: Color) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .reffiText(ReffiType.caption)
                .foregroundStyle(fg2)
            Spacer(minLength: Space.s4)
            Text(value)
                .reffiText(ReffiType.body)
                .num()
                .foregroundStyle(ReffiColor.ink)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, Space.s4)
    }

    private func divider(_ line: Color) -> some View {
        Rectangle().fill(line).frame(height: 1)
    }

    private func show(_ s: String) -> String { s.isEmpty ? "—" : s }
    private func dateText(_ d: Date) -> String { d.formatted(date: .abbreviated, time: .omitted) }
}
