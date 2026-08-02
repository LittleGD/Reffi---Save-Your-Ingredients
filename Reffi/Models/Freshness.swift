import SwiftUI

/// 신선도(§2.5) — 남은 일수 → 상태/색. 색은 신선도에만, 항상 색 + 텍스트 라벨을 함께(§1).
enum Freshness {
    case fresh    // D-4+
    case soon     // D-3 ~ D-1
    case urgent   // D-0 / 지남

    init(daysLeft: Int) {
        switch daysLeft {
        case ..<1:  self = .urgent
        case 1...3: self = .soon
        default:    self = .fresh
        }
    }

    /// 파스텔 main — 카드/칩 면. 위 글자는 ink(§2.6).
    var main: Color {
        switch self {
        case .fresh:  ReffiColor.fresh
        case .soon:   ReffiColor.soon
        case .urgent: ReffiColor.urgent
        }
    }

    /// dark — 캔버스 위 색-as-텍스트·점. 비-텍스트 3:1 충족(§2.6).
    var dark: Color {
        switch self {
        case .fresh:  ReffiColor.freshDark
        case .soon:   ReffiColor.soonDark
        case .urgent: ReffiColor.urgentDark
        }
    }

    /// light — 가장 옅은 틴트. 위 ink 텍스트는 AAA(12.6~14.0). 보조 칩·면(§2.6).
    var light: Color {
        switch self {
        case .fresh:  ReffiColor.freshLight
        case .soon:   ReffiColor.soonLight
        case .urgent: ReffiColor.urgentLight
        }
    }

    /// 짧은 상태 라벨(색 단독 의미 금지 → 항상 동반).
    var label: String {
        switch self {
        case .fresh:  "Fresh"
        case .soon:   "Soon"
        case .urgent: "Today"
        }
    }

    /// 면 색의 정본 OKLCH 파라미터(L/C/H) — depth 단차 계산용. 라이트/다크 쌍.
    /// 라이트는 `main` 토큰과 동일, 다크는 스택 면 전용으로 살짝 더 눌러 캔버스와 붙지 않게 한다.
    var faceParams: (light: (L: Double, C: Double, H: Double), dark: (L: Double, C: Double, H: Double)) {
        switch self {
        case .fresh:  ((0.86, 0.120, 136), (0.40, 0.070, 138))
        case .soon:   ((0.85, 0.125, 84),  (0.42, 0.075, 82))
        case .urgent: ((0.75, 0.135, 36),  (0.42, 0.088, 34))
        }
    }

    /// 스택에서 인접 카드 깊이감 — 뒤 카드일수록 캔버스 쪽으로 한 단씩 물러난다(§8.2).
    /// 라이트는 밝은 캔버스라 L을 올려(+1.6%/단, .95 캡), 다크는 어두운 캔버스라 L을 내려
    /// (-1.4%/단, .30 캡) 물러나게 한다 — 다크에서 밝히면 뒤 카드가 오히려 앞으로 튀어나온다.
    func face(depth: Int) -> Color {
        let p = faceParams
        let lightL = min(0.95, p.light.L + Double(depth) * 0.016)
        let darkL  = max(0.30, p.dark.L - Double(depth) * 0.014)
        return ReffiColor.dynamic(light: (lightL, p.light.C, p.light.H),
                                  dark:  (darkL,  p.dark.C,  p.dark.H))
    }
}
