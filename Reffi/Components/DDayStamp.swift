import SwiftUI

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
