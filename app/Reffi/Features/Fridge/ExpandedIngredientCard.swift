import SwiftUI
import PhosphorSwift

/// 펼친(Wallet) 상태의 카드 — 신선도 색 종이 한 장을 "영수증"으로.
/// 톱니 가장자리 + 인쇄 그레인 + 점선 구분선 + 모노스페이스 라벨(점선 리더) + 바코드 + 신선도 잉크 스탬프.
/// 헤더는 접힌 `IngredientCardView`와 같은 시작 구성이라 matchedGeometry 모핑이 매끄럽다.
struct ExpandedIngredientCard: View {
    let ingredient: Ingredient
    var onEdit: () -> Void = {}

    private let toothH: CGFloat = 6

    /// 영수증 일련번호 — 이름+구매일에서 유도(장식용, 안정적).
    private var receiptNo: String {
        let a = ingredient.name.unicodeScalars.reduce(7) { $0 &* 31 &+ Int($1.value) }
        let b = Int(ingredient.addedDate.timeIntervalSince1970) % 10000
        return String(format: "No. %04d-%04d", abs(a) % 10000, abs(b))
    }

    var body: some View {
        let category = IngredientCategory(raw: ingredient.category)
        let white = ReffiColor.freshnessPrefersWhiteText(daysLeft: ingredient.daysLeft)
        let fg2 = white ? Color.white : ReffiColor.ink2            // 보조 라벨
        let line = white ? Color.white.opacity(0.32) : ReffiColor.ink.opacity(0.20)
        let shape = ReceiptShape(toothHeight: toothH)

        return VStack(alignment: .leading, spacing: 0) {
            header(category, fg2: fg2)

            dashed(line)

            VStack(spacing: 0) {
                row("Purchased", dateText(ingredient.addedDate), fg2: fg2, line: line)
                row("Where", show(ingredient.purchasePlace), fg2: fg2, line: line)
                row("Quantity", show(ingredient.quantity), fg2: fg2, line: line)
                row("Expires", "\(dateText(ingredient.expiryDate)) · \(ingredient.countdownLabel)", fg2: fg2, line: line)
                row("Storage", show(ingredient.storage), fg2: fg2, line: line)
            }
            .padding(.horizontal, Space.s5)
            .padding(.vertical, Space.s2)

            dashed(line)

            footer(fg2: fg2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, toothH)
        .padding(.bottom, toothH)
        .background(ReffiColor.freshnessFill(daysLeft: ingredient.daysLeft), in: shape)
        .paperGrain(shape)
        .reffiStackShadow()
    }

    // MARK: 헤더 — 카테고리(가게 라벨) · [아이콘] 이름 + 편집
    private func header(_ category: IngredientCategory, fg2: Color) -> some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            HStack {
                Text(category.label.uppercased())
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(fg2)
                Spacer()
                Button(action: onEdit) {
                    ReffiIcon.edit.reffi(18, .bold)
                        .foregroundStyle(ReffiColor.ink)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(ReffiPressStyle())
                .accessibilityLabel("Edit item")
            }

            HStack(alignment: .center, spacing: Space.s3) {
                CategoryStamp(category: category, size: 56)
                Text(ingredient.name)
                    .reffiText(ReffiType.heading)
                    .foregroundStyle(ReffiColor.ink)
                Spacer(minLength: Space.s4)
                Text(ingredient.countdownLabel)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(ReffiColor.ink)
            }
        }
        .padding(.horizontal, Space.s5)
        .padding(.top, Space.s4)
        .padding(.bottom, Space.s3)
    }

    // MARK: 상세 행 — 라벨(대문자 모노) · · · · 값(모노)
    private func row(_ label: String, _ value: String, fg2: Color, line: Color) -> some View {
        HStack(alignment: .bottom, spacing: Space.s2) {
            Text(label.uppercased())
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundStyle(fg2)
                .fixedSize()
            ReceiptRule()
                .stroke(line, style: StrokeStyle(lineWidth: 1, dash: [1, 3]))
                .frame(height: 1)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 4)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundStyle(ReffiColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .layoutPriority(1)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, Space.s2)
    }

    // MARK: 푸터 — 일련번호 + 태그라인
    private func footer(fg2: Color) -> some View {
        VStack(spacing: Space.s2) {
            Text(receiptNo)
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .tracking(1)
                .foregroundStyle(fg2)
            Text("REFFI · KEEP IT FRESH")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(fg2)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Space.s2)
        .padding(.bottom, Space.s2)
    }

    private func dashed(_ line: Color) -> some View {
        ReceiptRule()
            .stroke(line, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            .frame(height: 1)
            .padding(.horizontal, Space.s5)
    }

    private func show(_ s: String) -> String { s.isEmpty ? "—" : s }
    private func dateText(_ d: Date) -> String { d.formatted(date: .abbreviated, time: .omitted) }
}
