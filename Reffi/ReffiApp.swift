import SwiftUI

@main
struct ReffiApp: App {
    @State private var store = FridgeStore()
    @State private var profile = ProfileStore()
    @State private var auth = AuthStore()

    /// 온보딩 1회 완료 플래그 — 계정과 무관한 기기 로컬 상태.
    @AppStorage("onboarding.done") private var onboardingDone = false

    init() {
        #if DEBUG
        ReffiFontCheck.dump()
        // 스크린샷·QA용 — 온보딩 처음부터 다시.
        if ProcessInfo.processInfo.arguments.contains("-resetOnboarding") {
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
        } else if ProcessInfo.processInfo.arguments.contains("-onboarding") {
            OnboardingView(onFinish: { onboardingDone = true })
        } else {
            gated
        }
        #else
        gated
        #endif
    }

    /// 진입 게이트 — 온보딩(1회) → 로그인(세션/게스트 없으면) → 메인.
    @ViewBuilder private var gated: some View {
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
