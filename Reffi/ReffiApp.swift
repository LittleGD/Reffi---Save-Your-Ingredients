import SwiftUI

@main
struct ReffiApp: App {
    @State private var store = FridgeStore()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        NotificationPresenter.shared.install()   // 포그라운드에서도 알림 배너 표시
        #if DEBUG
        ReffiFontCheck.dump()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            rootContent
                .environment(store)
                .tint(ReffiColor.blue)
                // 다크 토큰이 정의되기 전까지 라이트 고정 — 고정 크림 팔레트와
                // 적응형 머티리얼(글래스)이 다크에서 어긋나는 중간 상태를 막는다.
                .preferredColorScheme(.light)
                // 알림은 앞으로 30일 치만 등록되므로, 포그라운드 복귀 때마다 창을 앞으로 민다
                // (스토어 변이 없이 오래 방치해도 그 이후 재료를 놓치지 않게).
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { ExpiryNotifier.reschedule(for: store.ingredients) }
                }
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
