import SwiftUI
import PhosphorSwift

/// 아직 비어 있는 탭 — 1차 빌드에서 홈 외 탭은 자리만. 캔버스 위 아이콘+제목+설명.
struct PlaceholderScreen: View {
    let icon: Ph
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: ReffiSpace.s4) {
            icon.reffi(48)
                .foregroundStyle(ReffiColor.blue)
            Text(title)
                .reffiType(.heading)
                .foregroundStyle(ReffiColor.ink)
            Text(message)
                .reffiType(.body)
                .foregroundStyle(ReffiColor.ink2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
        }
        .padding(ReffiSpace.s7)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ReffiColor.canvas.ignoresSafeArea())
    }
}
