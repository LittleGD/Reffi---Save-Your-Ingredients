import SwiftUI

@main
struct ReffiApp: App {
    @State private var store = FridgeStore()

    init() {
        #if DEBUG
        ReffiFontCheck.dump()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(store)
                .tint(ReffiColor.blue)
        }
    }
}
