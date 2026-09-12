import SwiftUI

/// Figma에서 내보낸 Reffi 워드마크. 높이만 지정해 모든 노출 위치에서 비율을 유지한다.
struct ReffiLogo: View {
    let height: CGFloat

    var body: some View {
        Image("ReffiLogo")
            .resizable()
            .scaledToFit()
            .frame(width: height * 187 / 94, height: height)
            .accessibilityLabel(Text(verbatim: "Reffi"))
    }
}
