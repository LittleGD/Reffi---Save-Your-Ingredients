import SwiftUI

/// 종이컷 버튼의 **표면(라벨)만** 떼어낸 조각 — `Button`이 아닌 컨트롤(`PhotosPicker`·`ShareLink` 등)에도
/// 같은 CTA 재질을 씌우기 위한 공유 프리미티브다. 호출부는 `.buttonStyle(.paperPress)`를 함께 걸어
/// 종이 프레스까지 맞춘다(선례: `CookingStepsView`의 ShareLink + `PaperIconLabel`).
///
/// 면 규격은 `PaperButton`과 **한 곳**에서 나온다 — 손으로 재조립하면 fill 토큰·질감·그림자가
/// 화면마다 갈려 앱에 secondary CTA가 두 종류로 보인다(감사 R4-2).
struct PaperButtonLabel: View {
    enum Kind { case primary, secondary }

    let title: LocalizedStringKey
    var kind: Kind = .primary
    var fullWidth: Bool = true
    var seed: Int = 0

    private var fill: Color { kind == .primary ? ReffiColor.blue : ReffiColor.sub }
    private var foreground: Color { kind == .primary ? .white : ReffiColor.ink }

    var body: some View {
        Text(title)
            .font(ReffiTextRole.subhead.font)
            .tracking(ReffiTextRole.subhead.tracking)
            .foregroundStyle(foreground)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.horizontal, ReffiSpace.s5)
            .padding(.vertical, ReffiSpace.s4)
            .background { surface }
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

/// 종이컷 버튼 — 와이드 1차 CTA(§13). 모서리 잘린 길쭉한 **8각형**(`PaperCutRect`) **솔리드** 면 +
/// **종이 질감**(`PaperGrain`) + 통통 프레스(`paperPress`). 아이콘·그라데이션 없음(텍스트만).
struct PaperButton: View {
    typealias Kind = PaperButtonLabel.Kind

    let title: LocalizedStringKey
    var kind: Kind = .primary
    var fullWidth: Bool = true
    var seed: Int = 0
    let action: () -> Void

    /// `.disabled(_:)`가 걸리면 투명도만 낮춰 "지금 못 누름"을 보인다(§7.2 disabled = opacity .45, 색 변경 X).
    /// 디밍은 **여기 한 곳**에서만 한다 — 호출부가 `.opacity(...)`를 겹쳐 걸면
    /// `\.isEnabled`가 하위로 전파되며 두 값이 곱해져(0.45 × 0.5 = 0.225) CTA 텍스트가 소실된다.
    /// 걸리지 않은 기존 호출부엔 영향이 없다(enabled = 1).
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            PaperButtonLabel(title: title, kind: kind, fullWidth: fullWidth, seed: seed)
        }
        .buttonStyle(.paperPress)
        .opacity(isEnabled ? 1 : ReffiOpacity.disabled)
    }
}
