import SwiftUI

/// 절취선(점선 룰) — 영수증·오더 티켓의 뜯는 선. 앱 전역의 유일한 점선 구분 어휘다(보더 금지 §6.1).
///
/// 오래도록 컴포넌트가 없어 여섯 곳이 각자 구현했고 잉크 농도가 0.14·0.16·0.22 세 값으로 갈렸다
/// (그중 0.14는 "Fridge 상세와 동일"이라 적힌 주석과 어긋난 복사 드리프트였다). 두 굵기만 남긴다.
struct ReffiRule: View {
    enum Style {
        /// 영수증 카드의 기본 절취선 — 얇고 촘촘(ink 16% · dash 3/3). 헤더 아래·구역 마감처럼
        /// 카드를 조용히 나눌 때.
        case receipt
        /// 오더 티켓 계열의 굵은 절취선 — 실제로 뜯는 선처럼 읽힌다(ink 22% · dash 4/4).
        /// 티켓 본문의 섹션 구분·편집 시트의 필드 구분·드롭다운 행 구분.
        case ticket
    }

    let style: Style

    init(_ style: Style = .receipt) { self.style = style }

    private var ink: Double { style == .ticket ? 0.22 : 0.16 }
    private var dash: [CGFloat] { style == .ticket ? [4, 4] : [3, 3] }

    var body: some View {
        HLine()
            .stroke(ReffiColor.ink.opacity(ink), style: StrokeStyle(lineWidth: 1, dash: dash))
            .frame(height: 1)
    }
}
