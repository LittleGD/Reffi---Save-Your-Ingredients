import SwiftUI
import PhosphorSwift

/// 재료 추가 탭 — 자리표시자. 이후 단계에서 영수증 스캔/수동 입력으로 채운다.
struct AddView: View {
    var body: some View {
        ZStack {
            ReffiColor.canvas.ignoresSafeArea()
            VStack(spacing: Space.s3) {
                ReffiIcon.receipt.reffi(40)
                    .foregroundStyle(ReffiColor.blue)
                Text("Add by scanning a receipt")
                    .reffiText(ReffiType.subhead)
                    .foregroundStyle(ReffiColor.ink)
                Text("Coming soon")
                    .reffiText(ReffiType.caption)
                    .foregroundStyle(ReffiColor.ink2)
            }
        }
    }
}

#Preview { AddView() }
