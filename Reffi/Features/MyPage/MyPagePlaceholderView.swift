import SwiftUI
import PhosphorSwift

struct MyPagePlaceholderView: View {
    var body: some View {
        PlaceholderScreen(
            icon: ReffiIcon.profile,
            title: "마이페이지",
            message: "버리지 않고 먹은 기록과 절약 리포트가 여기에 담깁니다."
        )
    }
}
