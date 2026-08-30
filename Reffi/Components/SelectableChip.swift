import SwiftUI

/// 선택 가능한 종이 칩 — 선택 시 Blue 면 + `onAccent`, 미선택은 서브 면 + ink(§2.6).
/// 면은 §13.1 종이컷 8각형(`PaperCutRect`)이다 — 완벽한 캡슐은 행동 표면에서 금지다.
/// 칩 비주얼은 작게 유지하되 히트 영역은 44pt 확보(§7.3).
struct SelectableChip: View {
    /// `LocalizedStringKey`인 이유(42차) — `String`으로 받으면 호출부의 `String(localized:)`가
    /// `Bundle.main`(=다음 실행)에서 굳어, 인앱 언어 전환이 취향·가구 칩에 재실행 전까지 안 먹었다.
    /// 키를 그대로 받아 SwiftUI가 `\.locale` 환경으로 리졸브하게 한다(41차 `ReceiptCard.title` 선례).
    let text: LocalizedStringKey
    let selected: Bool
    var fullWidth: Bool = true   // 행 균등 분배(D-N 행)용. 그리드/플로우에선 false로 자연 폭.
    /// 종이 카드(receipt) 위에 앉는 칩인가 — 미선택 면이 `sub`(캔버스 전용)와 `subRaised`(카드 위)로
    /// 갈린다(§2.8·42차). 시트 캔버스 위에 서는 취향 편집 시트는 기본값(false)을 쓴다.
    var onCard: Bool = false
    let action: () -> Void

    var body: some View {
        let shape = PaperCutRect(seed: 1)
        Button(action: action) {
            Text(text)
                .font(ReffiTextRole.caption.font)
                .tracking(ReffiTextRole.caption.tracking)
                .foregroundStyle(selected ? ReffiColor.onAccent : ReffiColor.ink)
                .lineLimit(1)
                .padding(.horizontal, ReffiSpace.s3)
                .padding(.vertical, ReffiSpace.s2)
                .frame(maxWidth: fullWidth ? .infinity : nil)
                .background(selected ? ReffiColor.blue : (onCard ? ReffiColor.subRaised : ReffiColor.sub),
                            in: shape)
                // 채운 면의 흰 톤 단면(§13.1) — 다크에서 그림자가 안 보이는 칩의 마지막 경계.
                // `PaperToggle` 트랙·`PaperButtonLabel`과 같은 문법.
                .paperEdge(shape, tint: ReffiColor.paperEdgeOnFill)
                .frame(minHeight: ReffiChrome.tapMin)   // §7.3 — 비주얼은 종이 칩, 히트는 하한까지
                .contentShape(Rectangle())
        }
        .buttonStyle(.reffiPress)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
