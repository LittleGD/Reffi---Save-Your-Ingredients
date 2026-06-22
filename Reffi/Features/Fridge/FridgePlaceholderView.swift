import SwiftUI
import PhosphorSwift

struct FridgePlaceholderView: View {
    var body: some View {
        PlaceholderScreen(
            icon: ReffiIcon.fridge,
            title: "Fridge",
            message: "Browse and manage all your ingredients by category — coming soon."
        )
    }
}
