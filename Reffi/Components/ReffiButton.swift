import SwiftUI
import PhosphorSwift

/// 기본 버튼 — 둥근 모서리 사각형(§4.2 버튼 = radius-md). 특수(필·원형)는 별도.
/// 기본 Blue main + white(§2.6). pressed = scale(0.97)(§7.2). 터치 타깃 ≥44pt(§7.3).
struct ReffiButton: View {
    let title: String
    var icon: Ph? = ReffiIcon.cook
    var fill: Color = ReffiColor.blue
    var foreground: Color = .white
    var fullWidth: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(ReffiTextRole.subhead.font)
                .tracking(ReffiTextRole.subhead.tracking)
                .foregroundStyle(foreground)
                .frame(maxWidth: fullWidth ? .infinity : nil)
                .padding(.horizontal, ReffiSpace.s5)
                .padding(.vertical, ReffiSpace.s3 + 2)
                .background {
                    let shape = PaperCutRect()   // 종이컷 8각형(솔리드 + 종이 질감, §13)
                    shape.fill(fill)
                        .overlay(PaperGrain(seed: 5).clipShape(shape))
                        .paperEdge(shape, tint: .white.opacity(0.14))
                }
        }
        .buttonStyle(.paperPress)
    }
}

/// 보조 액션 — 면 없는 텍스트+아이콘 버튼(캔버스 위 색은 dark, §2.6).
struct QuietButton: View {
    let title: String
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
            .contentShape(Rectangle())
        }
        .buttonStyle(.reffiPress)
    }
}
