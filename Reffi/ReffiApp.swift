import SwiftUI

@main
struct ReffiApp: App {
    @State private var store = FridgeStore()
    @State private var profile = ProfileStore()
    @State private var auth = AuthStore()

    init() {
        #if DEBUG
        ReffiFontCheck.dump()
        // 스크린샷·QA용 — 온보딩 처음부터 다시(-onboarding은 초기화 + 정상 게이트 진입.
        // 화면을 강제 고정하지 않으므로 완료 시 로그인→메인으로 자연히 흐른다).
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-resetOnboarding") || args.contains("-onboarding") {
            UserDefaults.standard.removeObject(forKey: "onboarding.done")
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            rootContent
                .environment(store)
                .environment(profile)
                .environment(auth)
                .tint(ReffiColor.blue)
        }
    }

    @ViewBuilder private var rootContent: some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-glyphGallery") {
            GlyphGalleryView()
        } else if ProcessInfo.processInfo.arguments.contains("-buttonGallery") {
            ButtonGalleryView()
        } else if ProcessInfo.processInfo.arguments.contains("-authView") {
            AuthView()
        } else {
            RootGateView()
        }
        #else
        RootGateView()
        #endif
    }
}

/// 진입 게이트 — 온보딩(기기당 1회) → 로그인(세션/게스트 없으면) → 메인.
/// App이 아닌 View에 두어 @AppStorage 변경이 확실히 리렌더를 트리거하게 한다.
private struct RootGateView: View {
    @Environment(AuthStore.self) private var auth
    @AppStorage("onboarding.done") private var onboardingDone = false

    var body: some View {
        if auth.restoring {
            splash
        } else if !onboardingDone {
            OnboardingView(onFinish: { onboardingDone = true })
        } else if !auth.isSignedIn {
            AuthView()
                .transition(.opacity)
        } else {
            RootTabView()
                .transition(.opacity)
        }
    }

    /// 세션 복원 동안의 정적 스플래시 — 런치 스크린과 같은 크림 + 워드마크(깜빡임 방지).
    private var splash: some View {
        ZStack {
            ReffiColor.canvas.ignoresSafeArea()
            Text("Reffi").reffiType(.display).foregroundStyle(ReffiColor.blueDark)
        }
    }
}
