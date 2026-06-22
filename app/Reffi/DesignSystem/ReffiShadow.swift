import SwiftUI

/// 엘리베이션 (§6) — 기본은 그림자 없음. 떠 있는 요소와 카드 스택에서만.
/// 이중 그림자(낮은 블러 10% + 높은 블러 5%), ink 틴트, ≤10%.
enum ReffiShadow {
    /// 떠 있는 요소(모달·드롭다운·토스트·바텀시트).
    struct Floating: ViewModifier {
        func body(content: Content) -> some View {
            content
                .shadow(color: ReffiColor.ink.opacity(0.10), radius: 1.5, x: 0, y: 1)
                .shadow(color: ReffiColor.ink.opacity(0.05), radius: 12, x: 0, y: 10)
        }
    }

    /// 카드 스택 전용 — 위쪽으로 드리워 카드 경계를 만든다(§6.3).
    /// 파스텔 면이 크림 캔버스와 명도차가 작아 경계를 그림자로 만든다.
    struct Stack: ViewModifier {
        func body(content: Content) -> some View {
            content
                .shadow(color: ReffiColor.ink.opacity(0.10), radius: 3, x: 0, y: -2)
                .shadow(color: ReffiColor.ink.opacity(0.05), radius: 10, x: 0, y: -8)
        }
    }
}

extension View {
    func reffiFloatingShadow() -> some View { modifier(ReffiShadow.Floating()) }
    func reffiStackShadow() -> some View { modifier(ReffiShadow.Stack()) }
}
