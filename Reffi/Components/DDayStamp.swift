import SwiftUI
import PhosphorSwift

/// D-day 도장 — 기울여 찍은 **종이컷 8각 각인** + 글자(영수증 "START" 스탬프 느낌, §13.1). 색은 신선도색.
///
/// 냉장고·프로필·이력·온보딩 네 피처가 함께 쓰는 프리미티브다.
///
/// **스톡 `RoundedRectangle`로 되돌리지 마라.** 이 앱의 면은 전부 손으로 오린 종이인데 도장만
/// 애플의 연속 곡률(`style: .continuous`) 사각이라, 변이 자로 잰 듯 곧고 코너가 매끈해서 바로 옆
/// `PaperRect` 뱃지·`ReceiptShape` 카드와 **재질이 갈렸다** — 종이 위에 iOS 컨트롤 한 조각이 얹힌
/// 인상이다. 콜사이트가 13곳·5화면이라 §13.1("완벽한 원·사각 금지")이 앱에서 가장 자주 반복되는
/// 조각에서 깨지고 있었고, 오너가 지적한 "각진 페이퍼컷과 둥근 디자인이 규칙 없이 섞여 있다"의
/// 절반이 여기서 나왔다.
struct DDayStamp: View {
    let text: String
    let color: Color
    var size: CGFloat = 13
    /// Dynamic Type 스케일 곡선(42차) — `Font.reffiStamp`가 처음부터 받던 인자인데 여기서 전달을
    /// 막고 있었다. 기본 `.subheadline`은 소형 도장(10~17)에 맞는 곡선이고, 온보딩 "Start"(46)처럼
    /// **화면의 주인공급 도장은 `.largeTitle`을 명시**해야 한다 — subheadline 곡선은 AX 구간에서
    /// 훨씬 가파르게 자라, 46pt 도장이 display(34, largeTitle 곡선) 타이틀을 추월한다.
    var relativeTo: Font.TextStyle = .subheadline
    /// 올캡으로 찍을 것인가 — **크롬 단어 전용**이다(FROZEN·DAY 12·Start). 그 라벨들은 영문 원문이
    /// 이미 도장 문법으로 쓰여 있어 올캡이 시각 문법이고, 한국어에선 `.uppercased()`가 no-op이라 무해하다.
    /// 반대로 **번역되는 데이터 라벨은 반드시 `false`**다(§3.5, `GlyphStamp` 주석의 그 원칙): 남은 일수는
    /// `Ingredient.dDayText`가 "3d"·"Today"로 내는 값인데 올캡을 씌우면 영문에서 "3D"(3차원)로 읽히고
    /// "TODAY"는 이 앱이 아무 데서도 쓰지 않는 표기가 된다.
    var caps: Bool = true
    /// 보조기술이 읽을 문구 — 도장은 자리를 아끼려 줄인 표기(3d)라 소리로는 뜻이 서지 않는다.
    /// nil이면 보이는 글자를 그대로 읽는다(FROZEN처럼 축약이 아닌 크롬 단어).
    var accessibilityLabel: String?
    /// 각인 다이(die)의 시드. 여기에 **라벨 글자 수**(아래 `stampDie` 호출)와 **`size`**(`stampDie` 안)를
    /// 섞어 실제 다이를 뽑는다 —
    /// 한 카드에 도장이 둘 이상 서는 자리(냉장고 카드의 FROZEN + D-day)에서 호출부가 시드를 갈라
    /// 주지 않아도 두 다이가 갈리게 하기 위해서다. 글자 수만으로는 부족하다: 한국어에서 "냉동"과
    /// "3일"은 둘 다 두 글자라 같은 시드로 무너진다 — 그 쌍은 언제나 `size`가 다르므로(12/17 · 11/14)
    /// 두 축을 함께 섞어야 어느 언어에서도 갈린다.
    ///
    /// 날짜가 흘러 "3d" → "2d"가 되어도 글자 수와 `size`가 그대로라 **가위 자국은 제자리다**
    /// (§13.10 칩이 세운 "값이 변해도 윤곽은 고정" 규약 — 같은 조각이 매 렌더 다른 모양이면
    /// 애니메이션이 흔들린다). 같은 크기·같은 길이의 도장 둘이 실제로 나란히 서는 자리가 생기면
    /// 그때 호출부가 이 값을 갈라 준다.
    var seed: Int = 0

    var body: some View {
        Text(caps ? text.uppercased() : text)
            .font(.reffiStamp(size, relativeTo: relativeTo))
            .monospacedDigit()          // §3.4 — 자릿수가 바뀌어도 도장 폭이 흔들리지 않게
            .tracking(size * 0.06)
            .foregroundStyle(color)
            .padding(.horizontal, size * 0.7)
            .padding(.vertical, size * 0.32)
            .stampDie(size: size, color: color, seed: seed &+ text.count)
            .rotationEffect(.degrees(-7))
            .accessibilityLabel(accessibilityLabel ?? text)
    }
}

/// 글리프 도장 — `DDayStamp`와 **같은 각인 문법**(기울여 찍은 종이컷 8각 외곽선 + 잉크 한 색)에 글자 대신
/// 아이콘을 넣은 형제. 획 두께·잘림·기울기 계수를 위 도장과 같은 식(`stampDie`)에서 뽑아 두 도장이
/// 같은 손에서 찍힌 것으로 보이게 한다.
///
/// 글자가 아니라 글리프인 이유: "담김" 같은 상태를 도장 라벨로 쓰면 번역·올캡 문제가 따라오고(§3.5,
/// 한국어에서 `.uppercased()`는 무동작이라 올캡이라는 시각 문법이 사라진다), 담김은 체크 한 글리프로
/// 끝나는 상태라 도장 안이 글리프여도 뜻이 상하지 않는다.
struct GlyphStamp: View {
    let icon: Ph
    let color: Color
    var size: CGFloat = 13
    /// 각인 다이의 시드 — `DDayStamp`와 같은 규약. 이쪽은 라벨이 없어 섞을 글자 수도 없다.
    var seed: Int = 0

    var body: some View {
        icon.reffi(size * 0.72, .bold)
            .foregroundStyle(color)
            .padding(size * 0.32)
            .stampDie(size: size, color: color, seed: seed)
            .rotationEffect(.degrees(-7))
    }
}

fileprivate extension View {
    /// 도장 각인 한 벌 — 종이컷 8각 외곽선을 **두 번** 찍는다. 두 도장(`DDayStamp`·`GlyphStamp`)이
    /// 같은 다이에서 나오도록 잉크·잘림·시드 규약을 한 곳에 둔다(예전엔 같은 두 줄이 파일 안에
    /// 두 벌 있었고, 그런 자리는 결국 한쪽만 튜닝돼 갈린다).
    ///
    /// **왜 `PaperCutRect`가 아니라 형제인 `PaperChipCut`인가.** 도장은 다이로 찍는 것이라 같은
    /// 크기의 도장 둘은 **글자가 달라도 같은 모서리**를 가져야 한다("두 도장이 같은 손에서 찍힌
    /// 것으로 보이게 한다"는 이 파일의 원래 계약). 그런데 `PaperCutRect`의 잘림은
    /// `min(높이 32%, 폭 12%)`라 **폭에 걸린다** — 도장의 높이는 `size`가 정하지만 폭은 라벨 길이가
    /// 정하므로, 한 카드에 나란히 서는 "FROZEN"과 "3d"가 서로 다른 깊이로 잘린다(size 12에서
    /// 각각 ≈6.7pt · ≈4.1pt). `PaperChipCut`은 잘림을 **짧은 변의 26%**로 두므로 폭과 무관하게
    /// `size`만 따라간다 = 한 다이. 지터 하한(0.8pt)이 있어 10pt 소형 도장에서도 손맛이 남는 것도
    /// 이쪽이다 — 반지름 기반 프리미티브(`PaperRect`)는 이 크기에서 변 휨이 0.65pt로 눌려 3x에서도
    /// 지각되지 않는다.
    ///
    /// 칩(`PaperDayChip`)과 형태 계열이 겹치는 것은 **의도다**. 이 앱의 소형 면은 전부 종이컷 8각이고
    /// (§13.1), 도장을 갈라 세우는 것은 셰이프가 아니라 면이 없다는 것(외곽선만) · −7° 기울기 ·
    /// 모노 올캡 잉크다. 구분을 사려고 셰이프 계열을 하나 더 만드는 것은 오너가 지적한 "규칙 없이
    /// 섞임"을 늘리는 쪽이다.
    ///
    /// **왜 두 번 찍는가.** 한 번만 그으면 굵기가 완벽히 일정한 벡터 선이라, 윤곽이 손으로 잘렸어도
    /// **잉크는 여전히 기계**다. 실제 고무도장은 손 압력이 한쪽으로 쏠려 반대쪽에 옅은 두 번째 자국을
    /// 남긴다. 오프셋을 `size`가 아니라 **획 두께**에 매단 이유: 번짐의 폭은 조각의 크기가 아니라 잉크
    /// 양이 정한다. 최대치인 46pt 도장에서도 1.5pt 안쪽이라, `.stroke`가 이미 프레임 밖으로 내보내는
    /// 획 절반(2.8pt)을 넘지 않는다 = 부모의 `.clipped()`에 새로 잘릴 일이 없다.
    ///
    /// **파선으로 흐트러뜨리지 마라.** 이 앱에서 파선은 이미 뜻이 있다(`AddBadge` = 더할 자리 ·
    /// `PaperDayChip`의 미래 칸 = 아직 오려 내지 않은 종이). 도장 테두리를 파선으로 만들면 각인이
    /// 아니라 "빈 자리"로 읽힌다.
    func stampDie(size: CGFloat, color: Color, seed: Int) -> some View {
        // 다이 시드에 `size`를 여기서 섞는다 — 호출부 둘이 같은 식을 따로 적으면 한쪽만 튜닝돼 갈린다.
        // `isFinite` 가드가 붙는 이유는 `Int(CGFloat.nan)`이 트랩이기 때문이다: 도장은 5화면 13곳이
        // 공유하는 조각이라, 크기 계산이 어디선가 NaN을 흘리면 화면이 깨지는 대신 앱이 죽는다.
        let die = PaperChipCut(seed: seed &+ Int(size.isFinite ? min(max(size, 0), 999) : 0))
        let ink = max(1.6, size * 0.12)
        return overlay {
            ZStack {
                // 2차 압인 — 본 획보다 얇고 옅게, 잉크 양에 비례해 어긋난 자리에.
                die.stroke(color.opacity(0.3),
                           style: StrokeStyle(lineWidth: ink * 0.55, lineJoin: .round))
                    .offset(x: ink * 0.28, y: -ink * 0.2)
                // 본 획 — 이음매가 `.miter`면 8각 꼭짓점이 바늘처럼 뾰족해져 가위가 아니라 벡터로 읽힌다.
                die.stroke(color, style: StrokeStyle(lineWidth: ink, lineJoin: .round))
            }
        }
    }
}
