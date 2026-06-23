import SwiftUI

/// 종이컷 버튼 — 와이드 1차 CTA(§13). 모서리 잘린 길쭉한 **8각형**(`PaperCutRect`) **솔리드** 면 +
/// **종이 질감**(`PaperGrain`) + 통통 프레스(`paperPress`). 아이콘·그라데이션 없음(텍스트만).
struct PaperButton: View {
    enum Kind { case primary, secondary }

    let title: String
    var kind: Kind = .primary
    var fullWidth: Bool = true
    var seed: Int = 0
    let action: () -> Void

    private var fill: Color { kind == .primary ? ReffiColor.blue : ReffiColor.sub }
    private var foreground: Color { kind == .primary ? .white : ReffiColor.ink }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(ReffiTextRole.subhead.font)
                .tracking(ReffiTextRole.subhead.tracking)
                .foregroundStyle(foreground)
                .frame(maxWidth: fullWidth ? .infinity : nil)
                .padding(.horizontal, ReffiSpace.s5)
                .padding(.vertical, ReffiSpace.s4)
                .background { surface }
        }
        .buttonStyle(.paperPress)
    }

    private var surface: some View {
        let shape = PaperCutRect(seed: seed)   // 아이콘 버튼(9각형)과 같은 종이컷 8각형 계열
        return shape.fill(fill)                // 솔리드(그라데이션 없음)
            .overlay(PaperGrain(seed: UInt64(seed) &+ 11).clipShape(shape))   // 종이 질감
            .paperEdge(shape, tint: .white.opacity(0.14), width: 1)
            .compositingGroup()
            .reffiShadow1()
    }
}
