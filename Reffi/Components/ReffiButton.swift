import SwiftUI
import PhosphorSwift

// 와이드 1차 CTA는 PaperButton(§13.5)으로 통일. 이전 ReffiButton(둥근 사각)은 제거됨.

/// 보조 액션 — 면 없는 텍스트+아이콘 버튼(캔버스 위 색은 dark, §2.6).
struct QuietButton: View {
    let title: LocalizedStringKey
    var icon: Ph?
    var tint: Color = ReffiColor.blueDark
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: ReffiSpace.s1) {
                if let icon { icon.reffi(16, .bold) }
                Text(title)
                    .font(ReffiTextRole.caption.font)
                    .tracking(ReffiTextRole.caption.tracking)
            }
            .foregroundStyle(tint)
            .padding(.vertical, ReffiSpace.s2)
            .padding(.horizontal, ReffiSpace.s2)
            .frame(minHeight: 44)   // §7.3 터치 타깃
            .contentShape(Rectangle())
        }
        .buttonStyle(.reffiPress)
    }
}
