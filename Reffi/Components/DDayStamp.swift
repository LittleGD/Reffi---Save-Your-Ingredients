import SwiftUI
import PhosphorSwift

/// D-day 도장 — 기울어진 둥근 사각 외곽선 + 글자(영수증 "START" 스탬프 느낌, §13). 색은 신선도색.
///
/// 냉장고·프로필·이력·온보딩 네 피처가 함께 쓰는 프리미티브다.
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

    var body: some View {
        Text(caps ? text.uppercased() : text)
            .font(.reffiStamp(size, relativeTo: relativeTo))
            .monospacedDigit()          // §3.4 — 자릿수가 바뀌어도 도장 폭이 흔들리지 않게
            .tracking(size * 0.06)
            .foregroundStyle(color)
            .padding(.horizontal, size * 0.7)
            .padding(.vertical, size * 0.32)
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.46, style: .continuous)
                    .stroke(color, lineWidth: max(1.6, size * 0.12))
            }
            .rotationEffect(.degrees(-7))
            .accessibilityLabel(accessibilityLabel ?? text)
    }
}

/// 글리프 도장 — `DDayStamp`와 **같은 각인 문법**(기울어진 둥근 사각 외곽선 + 잉크 한 색)에 글자 대신
/// 아이콘을 넣은 형제. 획 두께·코너·기울기 계수를 위 도장과 같은 식에서 뽑아 두 도장이 같은 손에서
/// 찍힌 것으로 보이게 한다.
///
/// 글자가 아니라 글리프인 이유: "담김" 같은 상태를 도장 라벨로 쓰면 번역·올캡 문제가 따라오고(§3.5,
/// 한국어에서 `.uppercased()`는 무동작이라 올캡이라는 시각 문법이 사라진다), 담김은 체크 한 글리프로
/// 끝나는 상태라 도장 안이 글리프여도 뜻이 상하지 않는다.
struct GlyphStamp: View {
    let icon: Ph
    let color: Color
    var size: CGFloat = 13

    var body: some View {
        icon.reffi(size * 0.72, .bold)
            .foregroundStyle(color)
            .padding(size * 0.32)
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.46, style: .continuous)
                    .stroke(color, lineWidth: max(1.6, size * 0.12))
            }
            .rotationEffect(.degrees(-7))
    }
}
