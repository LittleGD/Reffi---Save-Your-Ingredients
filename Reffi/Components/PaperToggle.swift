import SwiftUI

/// 종이컷 토글(§13.5) — 스톡 `Toggle`의 캡슐 스위치를 손으로 자른 종이로 재질만 바꾼 `ToggleStyle`.
/// 트랙은 `PaperRect(cornerRadius: .pill)`이 pill 스케일에서 스스로 라우팅하는 `PaperCutRect` 8각 필
/// (§13.1 "완벽한 캡슐 금지"), 손잡이는 `PaperBlob(sides: 9)` 종이 조각 — 둘 다 새로 만들지 않고
/// 앱이 이미 쓰는 프리미티브를 그대로 부른다.
///
/// **접근성은 스타일이 아니라 `Toggle` 자신이 책임진다.** `makeBody`는 트랙·손잡이만 그리고
/// 라벨·트레잇·값(On/Off)에는 손대지 않는다 — 커스텀 `ButtonStyle`/`ToggleStyle`이 시각만 바꾸고
/// 시맨틱은 그대로 유지하는 SwiftUI의 계약 그대로다. VoiceOver 더블탭은 화면 탭용 `onTapGesture`
/// (손가락 전용 제스처)를 거치지 않고 `isOn` 바인딩에 직접 닿으므로, 이 제스처가 없어도 스위치는
/// 보조기술에서 항상 켜고 끌 수 있다.
struct PaperToggleStyle: ToggleStyle {
    /// 종이 시드 — 한 화면에 토글이 여럿 서도(현재 프로필 셋) 트랙·손잡이 결이 서로 다르게
    /// 갈리도록 호출부가 인스턴스마다 다른 값을 준다(§13.1 확립 규칙, `IngredientBadge`/`AddBadge`가
    /// 시드 기본값을 0/1로 가르는 것과 같은 문법). 손잡이는 `seed &+ 5`로 트랙과 다른 지터를 받는다
    /// (`PaperButtonLabel`이 면 시드와 그레인 시드를 오프셋으로 가르는 것과 같은 이유).
    var seed: Int = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // 스톡 iOS 스위치 실측(51×31 · 손잡이 27 · 인셋 2) — 재질만 종이로 갈고 폼은 낯설게 하지 않는다
    // (스펙: "≈ stock toggle footprint"). 히트 영역은 아래에서 §7.3 하한까지 투명하게 넓힌다.
    private let trackWidth: CGFloat = 51
    private let trackHeight: CGFloat = 31
    private let knobSize: CGFloat = 27
    private let inset: CGFloat = 2

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: ReffiSpace.s3) {
            configuration.label
            Spacer(minLength: ReffiSpace.s4)
            track(configuration)
        }
    }

    private func track(_ configuration: Configuration) -> some View {
        let shape = PaperRect(cornerRadius: ReffiRadius.pill, seed: seed)
        return ZStack(alignment: configuration.isOn ? .trailing : .leading) {
            shape
                // OFF 트랙은 `sub`가 아니라 `subRaised`다(§2.8·42차) — 이 토글 셋은 전부 프로필
                // 영수증 카드 위에 살고, sub(다크 .32)는 receipt(.335) 위에서 1.06으로 사라져
                // 스위치가 "빈 윤곽선"으로 읽혔다. subRaised(다크 .41)는 카드 위 1.36.
                .fill(configuration.isOn ? ReffiColor.blue : ReffiColor.subRaised)
                .overlay(PaperGrain(seed: UInt64(bitPattern: Int64(seed)) &+ 5, strength: 0.5).clipShape(shape))
                // 켬(파랑)·꺼짐(sub) 둘 다 "채운 면"이라 흰 톤 단면 하나로 통일한다 —
                // `PaperButtonLabel`이 primary/secondary를 가리지 않고 `paperEdgeOnFill`을 쓰는 것과 같다.
                .paperEdge(shape, tint: ReffiColor.paperEdgeOnFill)
                .compositingGroup()
            knob
                .padding(inset)
        }
        .frame(width: trackWidth, height: trackHeight)
        .frame(minWidth: ReffiChrome.tapMin, minHeight: ReffiChrome.tapMin)   // §7.3 히트 하한
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(ReffiMotion.gated(ReffiMotion.standard, reduce: reduceMotion)) {
                configuration.isOn.toggle()
            }
        }
    }

    /// 손잡이 — 종이 한 조각(`paper` 면 + 그레인 + 잉크 단면, `PaperDayChip`의 조용한 날 칩과 같은 조합)
    /// + 얕은 뜬 그림자(§6.2 "떠 있는 요소" 예외 — 트랙 위를 미끄러지는 조각이라 `PaperIconButton`
    /// 블롭과 같은 근거로 허용한다).
    private var knob: some View {
        let shape = PaperBlob(sides: 9, seed: seed &+ 5)
        return ZStack {
            shape.fill(ReffiColor.paper)
            PaperGrain(seed: UInt64(bitPattern: Int64(seed)) &+ 13, strength: 0.5).clipShape(shape)
        }
        .paperEdge(shape)
        .compositingGroup()
        .frame(width: knobSize, height: knobSize)
        .reffiShadow1()
    }
}
