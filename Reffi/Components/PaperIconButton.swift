import SwiftUI
import PhosphorSwift

/// 종이컷 아이콘 버튼(§13.5) — 첨부 레퍼런스(Tossed/Ate) 폼: **손으로 자른 종이 9각형**(`PaperBlob`) 면 +
/// 가운데 채운 아이콘 + 아래 라벨. 솔리드(흰 아이콘) / 소프트 틴트(dark 아이콘). 통통 프레스.
struct PaperIconButton: View {
    typealias Intent = PaperIconLabel.Intent
    typealias Placement = PaperIconLabel.Placement

    let icon: Ph
    var label: LocalizedStringKey? = nil
    var intent: Intent = .primary
    var size: CGFloat = 88
    var seed: Int = 0
    var placement: Placement = .below
    var capsLabelWidth: Bool = true
    let action: () -> Void

    var body: some View {
        // 라벨이 없으면 빈 문자열을 **강제 주입하지 않는다**(42차) — 빈 라벨은 SwiftUI가 내용에서
        // 이름을 유도할 길까지 막아 "이름 없는 버튼"을 만든다(`CoverHeader.closeHint`와 같은 처세).
        if let label {
            Button(action: action) { content }
                .buttonStyle(.paperPress)
                .accessibilityLabel(Text(label))
        } else {
            Button(action: action) { content }
                .buttonStyle(.paperPress)
        }
    }

    @ViewBuilder
    private var content: some View {
        let visual = PaperIconLabel(icon: icon, label: label, intent: intent, size: size, seed: seed,
                                    placement: placement, capsLabelWidth: capsLabelWidth)
        if placement == .trailing {
            // 행 폼은 폭을 다 쓴다 — 블롭과 라벨 사이 빈 자리까지 눌리게 해야 큰 글자에서 한 행이
            // 통째로 타깃이 된다(§7.3). 블롭 아래 라벨 폼은 지금의 타깃 그대로 둔다.
            visual.contentShape(Rectangle())
        } else {
            visual
        }
    }
}

/// `PaperIconButton`의 비주얼(블롭+아이콘+라벨)만 떼어낸 뷰 — `Button`이 아닌 다른 탭 컨트롤(예: `ShareLink`)에
/// 같은 종이컷 표면을 씌우고 싶을 때 재사용한다. `PaperIconButton`은 이 뷰를 `Button`으로 감싼 것과 같다.
struct PaperIconLabel: View {
    enum Intent { case primary, soft, fresh, soon, urgent, neutral }
    /// 라벨이 서는 자리 — `.below`(기본: 블롭 아래 가운데) / `.trailing`(블롭 오른쪽, 행 폼).
    /// 행 폼은 버튼을 세로로 쌓는 배치에서만 쓴다 — 라벨이 가로로 자유로워져 큰 글자에서도
    /// 줄바꿈으로 살아난다(판정 커버의 `ViewThatFits` 폴백).
    enum Placement { case below, trailing }

    let icon: Ph
    var label: LocalizedStringKey? = nil
    var intent: Intent = .primary
    var size: CGFloat = 88
    var seed: Int = 0
    var placement: Placement = .below
    /// 종이 카드 위에 앉는 블롭인가(§2.8·42차) — `.neutral` 면이 부모에 따라 갈린다
    /// (`sub`는 캔버스 전용, 카드 위에선 다크에서 1.04로 사라져 `subRaised`).
    var onCard: Bool = false
    /// 라벨 폭을 블롭 폭에 묶을 것인가(`.below` 전용). 기본은 묶는다 — 긴 라벨이 버튼 고유 폭을 밀어
    /// 버튼 여러 개가 선 행이 부모를 넘기는 것을 막는 방어다(아래 주석의 실측 296).
    /// **`ViewThatFits` 후보로 세울 때만 푼다**: 후보가 들어가는지는 그 후보의 *고유 폭*으로 재는데,
    /// 캡이 그 폭을 늘 블롭 폭으로 되돌려 "안 들어간다"는 사실 자체를 감춘다(= 폴백이 영영 안 뜬다).
    /// 캡을 푼 채 고른 후보는 이미 들어간다고 판정된 것이라 넘칠 수 없다.
    var capsLabelWidth: Bool = true

    private var fill: Color {
        switch intent {
        case .primary: ReffiColor.blue
        case .soft:    ReffiColor.urgentLight     // 블러시(Tossed)
        case .fresh:   ReffiColor.fresh
        case .soon:    ReffiColor.soon
        case .urgent:  ReffiColor.urgent
        case .neutral: onCard ? ReffiColor.subRaised : ReffiColor.sub
        }
    }
    /// 솔리드(딥)면 `onAccent`(흰) 아이콘, 그 외 파스텔/틴트면 dark 아이콘(§2.6).
    private var iconColor: Color {
        switch intent {
        case .primary: ReffiColor.onAccent
        case .soft:    ReffiColor.urgentDark
        case .fresh:   ReffiColor.freshDark
        case .soon:    ReffiColor.soonDark
        case .urgent:  ReffiColor.ink
        case .neutral: ReffiColor.ink2
        }
    }

    var body: some View {
        switch placement {
        case .below:
            VStack(spacing: ReffiSpace.s2) {
                blob
                if let label {
                    // 라벨은 블롭의 형제라 위 `frame(width:height:)` 밖에 있다 — 폭을 블롭에 묶지 않으면
                    // 긴 라벨(또는 큰 글자)이 버튼 고유 폭을 밀어, 버튼 여러 개가 선 행이 부모를 넘긴다
                    // (판정 커버 3버튼에서 실측: 88 블롭인데 행 고유 폭이 296까지 벌어졌다).
                    Text(label)
                        .reffiType(.badgeLabel)
                        .foregroundStyle(ReffiColor.ink)
                        .frame(maxWidth: capsLabelWidth ? size : nil)
                        .lineLimit(1)
                        .minimumScaleFactor(ReffiShrink.fit)
                }
            }
        case .trailing:
            HStack(spacing: ReffiSpace.s4) {
                blob
                if let label {
                    // 세로 스택 안의 한 행이라 폭 경쟁 상대가 없다 — 줄 수를 막지 않는다.
                    Text(label)
                        .reffiType(.badgeLabel)
                        .foregroundStyle(ReffiColor.ink)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var blob: some View {
        ZStack {
            let shape = PaperBlob(sides: 9, seed: seed)
            shape.fill(fill)                                              // 솔리드(그라데이션 없음)
            // 시드는 `bitPattern`으로 넘긴다 — `UInt64(음수)`는 트랩이다. 지금 콜사이트는 전부 0~5
            // 리터럴이라 안 터지지만, 시드를 인덱스·해시에서 뽑는 자리가 하나 생기는 순간 판정 커버가
            // 죽는다. 비음수에서는 두 변환의 값이 같아 지금 렌더는 한 픽셀도 바뀌지 않는다
            // (`PaperDayChip`·`PaperToggle`이 이미 쓰는 관용구).
            PaperGrain(seed: UInt64(bitPattern: Int64(seed)) &+ 3, strength: 0.5)
                .clipShape(shape)                                         // 종이 질감(옅게)
            icon.reffi(size * 0.42, .fill).foregroundStyle(iconColor)
        }
        .frame(width: size, height: size)
        // **여기에 `.compositingGroup()`을 손으로 달지 마라.** `reffiShadow*` 토큰이 그림자 앞에서
        // 이미 묶는다(`ReffiElevation.GroupedShadow`) — SwiftUI의 `.shadow`가 자식 프리미티브마다
        // 따로 드리우는 문제는 42차에 콜사이트가 아니라 토큰이 지도록 옮겼다. 블롭의 면·그레인·
        // 아이콘이 저마다 번짐을 얻는 그 결함은 이 자리에 **없다**. 그레인의 `.overlay` 블렌드가
        // 그룹 안에 갇히는 것도 같은 묶음 덕이다. 여기에 그룹을 하나 더 얹으면 무해하지만, 규칙이
        // 다시 콜사이트로 새어 나온다.
        .reffiShadow1()
    }
}
