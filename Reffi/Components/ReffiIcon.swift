import SwiftUI
import PhosphorSwift

/// Phosphor(MIT) 아이콘 단일 진입점. 모두 SVG 라인, currentColor 상속(§5).
/// 케이스명이 바뀌면 이 파일만 고친다. 색 채운 아이콘 박스 금지(§5).
enum ReffiIcon {
    // 네비
    static var home: Ph { .house }
    static var fridge: Ph { .snowflake }   // 냉장고 = 냉기 메타포(Phosphor에 냉장고 직접 아이콘 없음)
    static var add: Ph { .plus }
    static var profile: Ph { .user }

    // 콘텐츠
    static var recipe: Ph { .cookingPot }
    static var cook: Ph { .bowlSteam }
    static var ate: Ph { .bowlSteam }
    static var toss: Ph { .trash }
    static var ai: Ph { .sparkle }
    static var go: Ph { .arrowRight }
    static var chevron: Ph { .caretRight }
    static var time: Ph { .clock }
    static var countdown: Ph { .clockCountdown }
    static var undo: Ph { .arrowCounterClockwise }

    // 재료 추가 시트
    static var receipt: Ph { .receipt }
    static var camera: Ph { .camera }
    static var barcode: Ph { .barcode }
    static var manual: Ph { .pencilSimple }
    static var close: Ph { .x }

    /// 대안액션별 아이콘.
    static func action(_ a: AlternativeAction) -> Ph {
        switch a {
        case .freeze: .snowflake
        case .prep:   .knife
        case .share:  .handHeart
        case .cook:   .bowlSteam
        }
    }
}

extension Ph {
    /// Reffi 표준 아이콘 렌더 — 템플릿 틴트(§5 currentColor) + 정사각 사이즈.
    /// 색은 호출부에서 `.foregroundStyle(...)`로 준다(파스텔 면 위 ink / Blue 면 위 white).
    func reffi(_ size: CGFloat, _ weight: Ph.IconWeight = .regular) -> some View {
        self.weight(weight)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}
