import SwiftUI
import PhosphorSwift

/// 종이컷 아이콘 버튼(§13.5) — 첨부 레퍼런스(Tossed/Ate) 폼: **손으로 자른 종이 9각형**(`PaperBlob`) 면 +
/// 가운데 채운 아이콘 + 아래 라벨. 솔리드(흰 아이콘) / 소프트 틴트(dark 아이콘). 통통 프레스.
struct PaperIconButton: View {
    typealias Intent = PaperIconLabel.Intent

    let icon: Ph
    var label: LocalizedStringKey? = nil
    var intent: Intent = .primary
    var size: CGFloat = 88
    var seed: Int = 0
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            PaperIconLabel(icon: icon, label: label, intent: intent, size: size, seed: seed)
        }
        .buttonStyle(.paperPress)
        .accessibilityLabel(label.map { Text($0) } ?? Text(verbatim: ""))
    }
}

/// `PaperIconButton`의 비주얼(블롭+아이콘+라벨)만 떼어낸 뷰 — `Button`이 아닌 다른 탭 컨트롤(예: `ShareLink`)에
/// 같은 종이컷 표면을 씌우고 싶을 때 재사용한다. `PaperIconButton`은 이 뷰를 `Button`으로 감싼 것과 같다.
struct PaperIconLabel: View {
    enum Intent { case primary, soft, fresh, soon, urgent, neutral }

    let icon: Ph
    var label: LocalizedStringKey? = nil
    var intent: Intent = .primary
    var size: CGFloat = 88
    var seed: Int = 0

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
                // 라벨은 블롭의 형제라 위 `frame(width:height:)` 밖에 있다 — 폭을 블롭에 묶지 않으면
                // 긴 라벨(또는 큰 글자)이 버튼 고유 폭을 밀어, 버튼 여러 개가 선 행이 부모를 넘긴다
                // (판정 커버 3버튼에서 실측: 88 블롭인데 행 고유 폭이 296까지 벌어졌다).
                Text(label)
                    .reffiType(.badgeLabel)
                    .foregroundStyle(ReffiColor.ink)
                    .frame(maxWidth: size)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }
}
