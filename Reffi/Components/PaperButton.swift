import SwiftUI

/// 종이컷 버튼 — 와이드 1차 CTA(§13). 모서리 잘린 길쭉한 **8각형**(`PaperCutRect`) **솔리드** 면 +
/// **종이 질감**(`PaperGrain`) + 통통 프레스(`paperPress`). 아이콘·그라데이션 없음(텍스트만).
struct PaperButton: View {
    enum Kind { case primary, secondary }

    let title: LocalizedStringKey
    var kind: Kind = .primary
    var fullWidth: Bool = true
    var seed: Int = 0
    let action: () -> Void

    /// `.disabled(_:)`가 걸리면 채도를 빼고(파랑→회색) 투명도를 낮춰 "지금 못 누름"을 보인다(§7 상태).
    /// 걸리지 않은 기존 호출부엔 영향이 없다(enabled=1·1).
    @Environment(\.isEnabled) private var isEnabled

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
        .saturation(isEnabled ? 1 : 0)
        .opacity(isEnabled ? 1 : 0.5)
    }

    private var surface: some View {
        let shape = PaperCutRect(seed: seed)   // 아이콘 버튼(9각형)과 같은 종이컷 8각형 계열
        return shape.fill(fill)                // 솔리드(그라데이션 없음)
            .overlay(PaperGrain(seed: UInt64(seed) &+ 11).clipShape(shape))   // 종이 질감
            .paperEdge(shape, tint: ReffiColor.paperEdgeOnFill, width: 1)
            .compositingGroup()
            .reffiShadow1()
    }
}
