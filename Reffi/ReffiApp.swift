import SwiftUI

@main
struct ReffiApp: App {
    @State private var store = FridgeStore()
    @State private var profile = ProfileStore()

    init() {
        #if DEBUG
        ReffiFontCheck.dump()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            rootContent
                .environment(store)
                .environment(profile)
                .tint(ReffiColor.blue)
        }
    }

    @ViewBuilder private var rootContent: some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-glyphGallery") {
            GlyphGalleryView()
        } else if ProcessInfo.processInfo.arguments.contains("-buttonGallery") {
            ButtonGalleryView()
        } else {
            RootTabView()
        }
        #else
        RootTabView()
        #endif
    }
}
