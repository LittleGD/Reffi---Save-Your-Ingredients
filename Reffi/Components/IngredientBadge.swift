import SwiftUI
import PhosphorSwift

/// 재료 뱃지(§13) — 실루엣이 정착해 모핑되는 형태. 캡슐이 아니라 **종이 둥근 사각**(`PaperRect`),
/// 재료명 **왼쪽에 인디케이터 바**(둥근 직사각, 신선도색). 탭 = Ate/Tossed 판정 묻기.
/// 히트 영역은 최소 44pt(§7.3), 시각은 그대로.
struct IngredientBadge: View {
    let ingredient: Ingredient
    var seed: Int = 0
    var onTap: () -> Void = {}

    var body: some View {
        let f = ingredient.freshness
        Button(action: onTap) {
            HStack(spacing: ReffiSpace.s2 + 2) {
                // 신선도 그룹(좌측) — 인디케이터 바 + 남은 기간(D-N)을 하나로 묶는다.
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(f.dark)
                        .frame(width: 4, height: 14)
                    Text(verbatim: ingredient.dDayText)
                        .font(.reffiNum(12, relativeTo: .caption2))
                        .foregroundStyle(f.dark)
                }
                Text(verbatim: ingredient.name)
                    .reffiType(.badgeLabel)
                    .foregroundStyle(ReffiColor.ink)
                    .lineLimit(1)
            }
            .padding(.leading, ReffiSpace.s3)
            .padding(.trailing, ReffiSpace.s3 + 2)
            .padding(.vertical, ReffiSpace.s2 + 2)
            .background { surface }
            .frame(minHeight: 44)              // §7.3 최소 터치 타깃
            .contentShape(Rectangle())
        }
        .buttonStyle(.paperPress)
        .accessibilityLabel(Text("\(ingredient.name), \(ingredient.dDayText)"))
        .accessibilityHint(Text("Decide: eaten or tossed?"))
    }

    private var surface: some View {
        let shape = PaperRect(cornerRadius: ReffiRadius.md, seed: seed)
        return shape
            .fill(ReffiColor.paper)
            .paperEdge(shape, tint: ReffiColor.ink.opacity(0.08))
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
                    .reffiType(.badgeLabel)
            }
            .foregroundStyle(ReffiColor.ink2)
            .padding(.horizontal, ReffiSpace.s3 + 2)
            .padding(.vertical, ReffiSpace.s2 + 2)
            .background {
                let shape = PaperRect(cornerRadius: ReffiRadius.md, seed: seed)
                shape.stroke(ReffiColor.muted.opacity(0.7),
                             style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
            }
            .frame(minHeight: 44)              // §7.3 최소 터치 타깃
            .contentShape(Rectangle())
        }
        .buttonStyle(.paperPress)
        .accessibilityLabel(Text("Add ingredients"))
    }
}
