import SwiftUI

/// 선택 가능한 종이 칩 — 선택 시 Blue 면+화이트, 미선택은 sub 면+ink(§2.6).
/// 면은 §13.1 종이컷 8각형(`PaperCutRect`)이다 — 완벽한 캡슐은 행동 표면에서 금지다.
/// 칩 비주얼은 작게 유지하되 히트 영역은 44pt 확보(§7.3).
struct SelectableChip: View {
    let text: String
    let selected: Bool
    var fullWidth: Bool = true   // 행 균등 분배(D-N 행)용. 그리드/플로우에선 false로 자연 폭.
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(ReffiTextRole.caption.font)
                .tracking(ReffiTextRole.caption.tracking)
                .foregroundStyle(selected ? .white : ReffiColor.ink)
                .lineLimit(1)
                .padding(.horizontal, ReffiSpace.s3)
                .padding(.vertical, ReffiSpace.s2)
                .frame(maxWidth: fullWidth ? .infinity : nil)
                .background(selected ? ReffiColor.blue : ReffiColor.sub, in: PaperCutRect(seed: 1))
                .frame(minHeight: 44)          // §7.3 터치 타깃 — 비주얼은 종이 칩, 히트는 44
                .contentShape(Rectangle())
        }
        .buttonStyle(.reffiPress)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
