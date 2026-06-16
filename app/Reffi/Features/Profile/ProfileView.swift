import SwiftUI

/// 마이 탭 — 자리표시자. 이후 설정·통계 등으로 채운다.
struct ProfileView: View {
    var body: some View {
        ZStack {
            ReffiColor.canvas.ignoresSafeArea()
            VStack(spacing: Space.s3) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 40, weight: .regular))
                    .foregroundStyle(ReffiColor.ink2)
                Text("Me")
                    .reffiText(ReffiType.subhead)
                    .foregroundStyle(ReffiColor.ink)
            }
        }
    }
}

#Preview { ProfileView() }
