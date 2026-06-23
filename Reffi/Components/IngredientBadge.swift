import SwiftUI
import PhosphorSwift

/// 재료 뱃지(§13) — 실루엣이 정착해 모핑되는 형태. 캡슐이 아니라 **종이 둥근 사각**(`PaperRect`),
/// 재료명 **왼쪽에 인디케이터 바**(둥근 직사각, 신선도색). 탭 = 활성/비활성 토글.
struct IngredientBadge: View {
    let ingredient: Ingredient
    var isDisabled: Bool = false
    var seed: Int = 0
    var onTap: () -> Void = {}

    var body: some View {
        let f = ingredient.freshness
        Button(action: onTap) {
            HStack(spacing: ReffiSpace.s2) {
                // 좌측 인디케이터 바 — 둥근 직사각, 신선도색.
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .fill(isDisabled ? ReffiColor.muted : f.dark)
                    .frame(width: 5, height: 17)
                Text(ingredient.name)
                    .font(.custom("Pretendard-SemiBold", size: 15, relativeTo: .subheadline))
                    .tracking(-0.15)
                    .foregroundStyle(isDisabled ? ReffiColor.muted : ReffiColor.ink)
                    .lineLimit(1)
                Text(ingredient.dDayText)
                    .font(.reffiNum(12, relativeTo: .caption2))
                    .foregroundStyle(isDisabled ? ReffiColor.muted : f.dark)
            }
            .padding(.leading, ReffiSpace.s3)
            .padding(.trailing, ReffiSpace.s3 + 2)
            .padding(.vertical, ReffiSpace.s2 + 2)
            .background { surface(disabled: isDisabled) }
            .opacity(isDisabled ? 0.72 : 1)
        }
        .buttonStyle(.paperPress)
        .accessibilityLabel("\(ingredient.name) \(ingredient.dDayText)")
        .accessibilityValue(isDisabled ? "비활성" : "사용")
        .accessibilityAddTraits(isDisabled ? [] : [.isSelected])
    }

    private func surface(disabled: Bool) -> some View {
        let shape = PaperRect(cornerRadius: ReffiRadius.md, seed: seed)
        return shape
            .fill(disabled ? ReffiColor.sub.opacity(0.7) : ReffiColor.oklch(0.99, 0.006, 90))
            .paperEdge(shape, tint: ReffiColor.ink.opacity(disabled ? 0.05 : 0.08))
            .reffiShadow1()
    }
}

/// 추가 뱃지 — 점선 종이 사각의 ＋. `AddIngredientSheet`로.
struct AddBadge: View {
    var seed: Int = 1
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: ReffiSpace.s1) {
                ReffiIcon.add.reffi(15, .bold)
                Text("Add")
                    .font(.custom("Pretendard-SemiBold", size: 15, relativeTo: .subheadline))
            }
            .foregroundStyle(ReffiColor.ink2)
            .padding(.horizontal, ReffiSpace.s3 + 2)
            .padding(.vertical, ReffiSpace.s2 + 2)
            .background {
                let shape = PaperRect(cornerRadius: ReffiRadius.md, seed: seed)
                shape.stroke(ReffiColor.muted.opacity(0.7),
                             style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
            }
        }
        .buttonStyle(.paperPress)
        .accessibilityLabel("재료 추가")
    }
}
