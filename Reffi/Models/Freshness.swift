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
}
