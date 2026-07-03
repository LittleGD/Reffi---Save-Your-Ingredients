import SwiftUI
import PhosphorSwift

/// 종이컷 아이콘 버튼(§13.5) — 첨부 레퍼런스(Tossed/Ate) 폼: **손으로 자른 종이 9각형**(`PaperBlob`) 면 +
/// 가운데 채운 아이콘 + 아래 라벨. 솔리드(흰 아이콘) / 소프트 틴트(dark 아이콘). 통통 프레스.
struct PaperIconButton: View {
    enum Intent { case primary, soft, fresh, soon, urgent, neutral }

    let icon: Ph
    var label: LocalizedStringKey? = nil
    var intent: Intent = .primary
    var size: CGFloat = 88
    var seed: Int = 0
    let action: () -> Void

    private var fill: Color {
        switch intent {
        case .primary: ReffiColor.blue
        case .soft:    ReffiColor.urgentLight     // 블러시(Tossed)
        case .fresh:   ReffiColor.fresh
        case .soon:    ReffiColor.soon
        case .urgent:  ReffiColor.urgent
        case .neutral: ReffiColor.sub
        }
    }
    /// 솔리드(딥)면 흰 아이콘, 그 외 파스텔/틴트면 dark 아이콘(§2.6).
    private var iconColor: Color {
        switch intent {
        case .primary: .white
        case .soft:    ReffiColor.urgentDark
        case .fresh:   ReffiColor.freshDark
        case .soon:    ReffiColor.soonDark
        case .urgent:  ReffiColor.ink
        case .neutral: ReffiColor.ink2
        }
    }
    var body: some View {
        Button(action: action) {
            VStack(spacing: ReffiSpace.s2) {
                ZStack {
                    let shape = PaperBlob(sides: 9, seed: seed)
                    shape.fill(fill)                                              // 솔리드(그라데이션 없음)
                    PaperGrain(seed: UInt64(seed) &+ 3, strength: 0.5).clipShape(shape)  // 종이 질감(옅게)
                    icon.reffi(size * 0.42, .fill).foregroundStyle(iconColor)
                }
                .frame(width: size, height: size)
                .reffiShadow1()
                if let label {
                    Text(label)
                        .font(.custom("Pretendard-SemiBold", size: 15, relativeTo: .subheadline))
                        .foregroundStyle(ReffiColor.ink)
                }
            }
        }
        .buttonStyle(.paperPress)
        .accessibilityLabel(label.map { Text($0) } ?? Text(verbatim: ""))
    }
}
