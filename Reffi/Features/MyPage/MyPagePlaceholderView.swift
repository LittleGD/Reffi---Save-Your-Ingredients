import SwiftUI
import PhosphorSwift

struct MyPagePlaceholderView: View {
    var body: some View {
        PlaceholderScreen(
            icon: ReffiIcon.profile,
            title: "Profile",
            message: "Your no-waste history and savings report will live here."
        )
    }
}
