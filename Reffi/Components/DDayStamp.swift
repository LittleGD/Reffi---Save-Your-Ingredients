import SwiftUI
import PhosphorSwift

/// D-day 도장 — 기울어진 둥근 사각 외곽선 + 글자(영수증 "START" 스탬프 느낌, §13). 색은 신선도색.
///
/// 냉장고·프로필·이력·온보딩 네 피처가 함께 쓰는 프리미티브다.
struct DDayStamp: View {
    let text: String
    let color: Color
    var size: CGFloat = 13

    var body: some View {
        Text(text.uppercased())
            .font(.reffiStamp(size))
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
            .accessibilityLabel(text)
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
