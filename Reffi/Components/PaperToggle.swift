import SwiftUI

/// 종이컷 토글(§13.5) — 스톡 `Toggle`의 캡슐 스위치를 손으로 자른 종이로 재질만 바꾼 `ToggleStyle`.
/// 트랙은 `PaperRect(cornerRadius: .pill)`이 pill 스케일에서 스스로 라우팅하는 `PaperCutRect` 8각
/// (§13.1 "완벽한 캡슐 금지"), 손잡이는 `PaperBlob(sides: 9)` 종이 조각 — 둘 다 새로 만들지 않고
/// 앱이 이미 쓰는 프리미티브를 그대로 부른다.
///
/// **상태는 채움이 지고 실루엣은 재단선이 진다(41차 대비 수정).** 34차는 켬/꺼짐을 둘 다 "채운 면"
/// (`blue` / `sub`)으로 두고 손잡이를 `paper`로 얹었는데, 종이 램프끼리는 밝기로 대비를 만들 수 없어
/// 꺼짐이 실측 **라이트 1.20:1 · 다크 1.04:1**이었다(§2.6 비텍스트 3:1 미달, 다크에선 스위치가 사실상
/// 안 보였다). 밝기를 더 벌리는 대신 §13.10이 요일 칩에서 쓴 수를 그대로 쓴다 — **범주를 바꾼다**:
/// 슬롯은 양 상태 모두 `paperCut` 재단선으로 **항상 오려져 있고**, 상태는 그 안이 **채워졌는가**로만
/// 말한다(켬 = `blue` 면 + 그레인 / 꺼짐 = 면 없는 빈 슬롯). 손잡이도 면색이 아니라 같은 재단선이
/// 실루엣을 진다. 자세한 실측·근거는 §13.5.
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

    /// 슬롯 — 양 상태 공통 `paperCut` 재단선 + **켬일 때만** 채우는 `blue` 면.
    /// 꺼짐에서 면을 아예 빼는 것이 이 수정의 핵심이다: 옛 `sub` 면은 카드 위에서 실측 라이트 1.18 ·
    /// 다크 1.06이라 **보이지도 않으면서** 손잡이의 대비만 잡아먹고 있었다 — 빼도 잃는 것이 없고,
    /// 대신 "채움 = 켬"이라는 읽기를 얻는다.
    private func track(_ configuration: Configuration) -> some View {
        let shape = PaperRect(cornerRadius: ReffiRadius.pill, seed: seed)
        return ZStack(alignment: configuration.isOn ? .trailing : .leading) {
            shape
                .fill(configuration.isOn ? ReffiColor.blue : .clear)
                .overlay(
                    PaperGrain(seed: UInt64(bitPattern: Int64(seed)) &+ 5, strength: 0.5)
                        .clipShape(shape)
                        .opacity(configuration.isOn ? 1 : 0)   // 면이 없으면 결도 없다(빈 슬롯엔 종이가 없다)
                )
                // 재단선이 §13.1의 재질 헤어라인(`paperEdgeOnFill`) 자리를 대신한다 — 양 상태에서
                // 실루엣을 지는 선이 둘일 이유가 없고, 켬에서도 슬롯 윤곽은 카드와 갈려야 한다
                // (blue 면 대 카드는 다크 실측 2.59:1이라 파랑만으로는 못 선다).
                .paperEdge(shape, tint: ReffiColor.paperCut)
                .compositingGroup()
            knob(isOn: configuration.isOn)
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

    /// 손잡이 — 종이 한 조각(면 + 그레인 + `paperCut` 재단선) + 얕은 뜬 그림자(§6.2 "떠 있는 요소"
    /// 예외 — 트랙 위를 미끄러지는 조각이라 `PaperIconButton` 블롭과 같은 근거로 허용한다).
    ///
    /// **면색은 앉은 자리가 정한다** — 켬에서는 `blue` 채도 면 위에 앉으므로 §2.2의 확립 규칙대로
    /// `onAccent`(양 모드 고정 흰색)다. 34차의 `paper`는 다크에서 웜 차콜로 뒤집혀 파랑 위 실측
    /// **2.63:1**이었고(손잡이가 조각이 아니라 파랑에 뚫린 구멍으로 읽혔다), `blue`의 다크 L 상한
    /// .565가 바로 "흰 콘텐츠로 4.5:1"에서 나온 값이라 흰색이 이 면의 정답이다(§2.7). 꺼짐에서는
    /// 채도 면이 없고 카드 위에 그냥 앉으므로 종이 그대로 `paper`이고, 실루엣은 재단선이 진다.
    private func knob(isOn: Bool) -> some View {
        let shape = PaperBlob(sides: 9, seed: seed &+ 5)
        return ZStack {
            shape.fill(isOn ? ReffiColor.onAccent : ReffiColor.paper)
            PaperGrain(seed: UInt64(bitPattern: Int64(seed)) &+ 13, strength: 0.5).clipShape(shape)
        }
        .paperEdge(shape, tint: ReffiColor.paperCut)
        .compositingGroup()
        .frame(width: knobSize, height: knobSize)
        .reffiShadow1()
    }
}
