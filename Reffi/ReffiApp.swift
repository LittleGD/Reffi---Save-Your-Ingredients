import SwiftUI

@main
struct ReffiApp: App {
    @State private var store: FridgeStore
    @State private var profile: ProfileStore
    @State private var auth: AuthStore
    @Environment(\.scenePhase) private var scenePhase

    init() {
        NotificationPresenter.shared.install()   // 포그라운드에서도 알림 배너 표시
        DataOwner.migrateIfNeeded()
        _store = State(initialValue: FridgeStore())
        _profile = State(initialValue: ProfileStore())
        _auth = State(initialValue: AuthStore())
        #if DEBUG
        ReffiFontCheck.dump()
        // 스크린샷·QA용 — 온보딩 처음부터 다시(-onboarding은 초기화 + 정상 게이트 진입.
        // 화면을 강제 고정하지 않으므로 완료 시 로그인→메인으로 자연히 흐른다).
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-resetOnboarding") || args.contains("-onboarding") {
            UserDefaults.standard.removeObject(forKey: "onboarding.done")
        }
        // 스크린샷·QA용 — 온보딩을 건너뛰고 곧장 게이트 통과(컨테이너가 새로 생성된 설치 직후에도
        // 결정적으로 메인까지 도달하게). -resetOnboarding/-onboarding과 상충하지 않도록 별도 플래그.
        if args.contains("-skipOnboarding") {
            UserDefaults.standard.set(true, forKey: "onboarding.done")
        }
        // UI 테스트용(38차) — 언어 선택을 강제로 system으로 되돌린다. 언어 전환 테스트가 AppStorage를
        // 실제로 바꾸므로, 같은 스위트의 다음 테스트가 영어 문자열 단언에서 깨지지 않게 하는
        // 방어선이다(테스트 본문의 UI 되돌리기가 실패해도 이 플래그가 캐스케이드를 막는다).
        if args.contains("-resetLanguage") {
            UserDefaults.standard.removeObject(forKey: AppLanguage.key)
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
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
                // 컬러 스킴은 시스템 설정을 따른다 — 시맨틱 토큰이 전부 적응형(ReffiColor.dynamic)이라
                // 라이트/다크 어느 쪽으로도 팔레트가 스스로 뒤집힌다.
                // 알림은 앞으로 30일 치만 등록되므로, 포그라운드 복귀 때마다 창을 앞으로 민다
                // (스토어 변이 없이 오래 방치해도 그 이후 재료를 놓치지 않게).
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active:
                        ExpiryNotifier.reschedule(for: store.ingredients)
                        store.promoteUrgent()   // 포그라운드 정렬 — 알림이 가리키는 임박 재료를 작업대로 승격
                        Analytics.shared.sceneDidBecomeActive()   // 세션 판정(30분 규칙) + 밀린 큐 업로드
                    case .background:
                        Analytics.shared.sceneDidEnterBackground()   // 세션 길이 기록 + 유예 안 업로드
                    default:
                        break
                    }
                }
        }
    }

    @ViewBuilder private var rootContent: some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-privacyView") {
            PrivacyView()
        } else if ProcessInfo.processInfo.arguments.contains("-glyphGallery") {
            GlyphGalleryView()
        } else if ProcessInfo.processInfo.arguments.contains("-dishGallery") {
            DishGalleryView()
        } else if ProcessInfo.processInfo.arguments.contains("-titleClipLab") {
            TitleClipLabView()
        } else if ProcessInfo.processInfo.arguments.contains("-shareCardPreview") {
            ShareCardPreviewView()
        } else if ProcessInfo.processInfo.arguments.contains("-myRecipesPreview") {
            // QA·스크린샷용 — 커스텀 레시피 목록/편집 종이화 검증(-shareCardPreview 선례).
            MyRecipesView().onAppear { seedPreviewRecipes() }
        } else if ProcessInfo.processInfo.arguments.contains("-glyphMetrics") {
            GlyphMetricsView()
        } else if ProcessInfo.processInfo.arguments.contains("-buttonGallery") {
            ButtonGalleryView()

        } else {
            RootGateView()
        }
        #else
        RootGateView()
        #endif
    }

    #if DEBUG
    /// `-myRecipesPreview` 표본 — 커스텀 레시피는 사용자가 만든 것뿐이라 QA 설치엔 항상 비어 있다.
    /// 시드 앞쪽 다섯 개를 커스텀으로 복제해 목록을 채운다(문구 하드코딩 금지 — 이름·재료를
    /// 전부 번들 시드에서 가져온다). 새 UUID를 받으므로 요리 아이콘은 매핑 표가 아니라
    /// **폴백 경로**가 그린다 — 실제 커스텀 레시피와 같은 조건이다.
    @MainActor private func seedPreviewRecipes() {
        guard store.userRecipes.isEmpty else { return }
        for r in RecipeCatalog.loadSeed().prefix(5).reversed() {
            store.addUserRecipe(.userRecipe(name: r.displayName,
                                            ingredientNames: r.ingredients.map(\.displayName),
                                            minutes: r.minutes))
        }
    }
    #endif
}

/// 진입 게이트 — 저장된 기기 자료 복원 → 온보딩(기기당 1회) → 메인.
/// App이 아닌 View에 두어 @AppStorage 변경이 확실히 리렌더를 트리거하게 한다.
/// 로컬 데이터 소유자 키 — RootGateView(대조·기록)와 ProfileView(계정삭제 시 해제)가 공유한다.
enum DataOwner {
    /// 마지막으로 이 기기 로컬 데이터를 소유한 정식(비익명) 서버 user id.
    static let key = "data.ownerUserID"
    private static let migratedKey = "data.ownerUserID.migrated.v2"

    /// 1회성 마이그레이션 — `accountUserID`(비익명 전용) 도입 전 버전은 익명 uuid도 소유자로
    /// 기록했다. 그 기록이 남으면 익명 게스트로 쓰던 기존 설치가 가입하는 순간 '다른 계정'으로
    /// 오인돼 로컬 데이터가 와이프된다 → 키를 한 번 비워 previous == nil(최초 기록)에서 다시
    /// 시작한다. 부작용은 마이그레이션 경계에서 계정 전환 와이프 1회를 건너뛸 수 있다는 것뿐.
    static func migrateIfNeeded() {
        let d = UserDefaults.standard
        guard !d.bool(forKey: migratedKey) else { return }
        d.removeObject(forKey: key)
        d.set(true, forKey: migratedKey)
    }

    static func scope(_ owner: String?) -> String { owner ?? "guest" }

    /// With sign-in removed, expiration of a legacy session must not hide this device's stock.
    static func localOwner(authenticated: String?, stored: String?, preserveSavedOwner: Bool = true) -> String? {
        authenticated ?? (preserveSavedOwner ? stored : nil)
    }

    @MainActor static func storageURL() -> URL {
        storageURL(owner: UserDefaults.standard.string(forKey: key))
    }

    @MainActor static func storageURL(owner: String?) -> URL {
        // 서버 사용자 ID는 UUID다. 경로로 전달된 값은 마지막 요소로만 사용한다.
        let name = scope(owner).replacingOccurrences(of: "/", with: "_")
        return FridgeStore.storeURL.deletingLastPathComponent()
            .appendingPathComponent("fridge-\(name).json")
    }

}

private struct RootGateView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(FridgeStore.self) private var store
    @Environment(ProfileStore.self) private var profile
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dataReady = false
    @State private var dataError = false
    @State private var splashReady = false
    @State private var splashCycle = 0
    @AppStorage("onboarding.done") private var onboardingDone = false
    /// 앱 내 언어 선택(38차) — App이 아닌 여기(View)에 둬 `@AppStorage` 변경이 확실히 리렌더를
    /// 트리거하게 한다(위 `onboardingDone`과 같은 이유, 파일 상단 주석 참고).
    @AppStorage(AppLanguage.key) private var languageRaw = AppLanguage.system.rawValue

    var body: some View {
        ZStack {
            if showingSplash {
                splash
                    // 준비가 끝나면 스플래시 표면이 위로 빠져 다음 화면을 드러낸다.
                    .transition(.move(edge: .top))
                    .zIndex(1)
            } else {
                destination
            }
        }
        .animation(ReffiMotion.gated(ReffiMotion.splashExit, reduce: reduceMotion),
                   value: showingSplash)
            // `LocalizedStringKey` 문자열(대부분의 버튼·행 라벨)은 이 오버라이드로 곧바로 반영된다.
            // `String(localized:)`로 이미 굳힌 값은 그대로다 — `AppLanguage.applyAppleLanguagesOverride()`가
            // 다음 실행을 위해 별도로 처리한다(정직한 경계는 `AppLanguage.swift` 문서 참고).
            .environment(\.locale, AppLanguage.resolve(stored: languageRaw).resolvedLocale)
            .onChange(of: auth.accountUserID, initial: true) { _, _ in reconcileDataOwner() }
            .onChange(of: auth.restoring) { _, _ in reconcileDataOwner() }
            .onChange(of: auth.retainsLocalDataOwner) { _, _ in reconcileDataOwner() }
            .paperDialog(isPresented: $dataError, title: "Couldn't switch accounts",
                         message: "Your saved data is still on this device. Try again to open this account.",
                         seed: 2, backdropDismisses: false,
                         primary: PaperDialogAction("Try again") { reconcileDataOwner() })

    }

    private var showingSplash: Bool {
        auth.restoring || !dataReady || !splashReady
    }

    @ViewBuilder private var destination: some View {
        if !onboardingDone {
            OnboardingView(onFinish: { onboardingDone = true })
                .analyticsScreen(.onboarding)
        } else {
            // 신규 계정을 만들지 않고 저장된 기기 자료로 바로 진입한다.
            RootTabView()
                .task { if !auth.isSignedIn { await auth.continueAsGuest() } }
        }
    }

    /// 전환 실패 중에는 이전 계정의 화면을 새 계정에 노출하지 않는다.
    private func reconcileDataOwner() {
        guard !auth.restoring else { return }
        if dataReady || splashReady { splashCycle += 1 }
        dataReady = false
        splashReady = false
        let previous = UserDefaults.standard.string(forKey: DataOwner.key)
        let newID = DataOwner.localOwner(authenticated: auth.accountUserID, stored: previous,
                                        preserveSavedOwner: auth.retainsLocalDataOwner)
        guard previous != newID else { dataReady = true; return }
        do {
            let transferredGuest = try store.switchAccount(to: newID, inheritGuest: previous == nil && newID != nil)
            profile.switchAccount(to: newID, inheritGuest: transferredGuest)
            UserDefaults.standard.set(newID, forKey: DataOwner.key)
            dataReady = true
        } catch {
            dataError = true
        }
    }

    /// 세션 복원 스플래시 — 로고가 하단에서 튀어 올라 중앙에 안착한 뒤 화면이 위로 빠진다.
    private var splash: some View {
        ReffiSplashView { splashReady = true }
            .id(splashCycle)
    }
}

/// 앱 첫 화면의 로고 진입 모션. 데이터 로딩이 짧아도 로고의 안착을 먼저 보여준다.
private struct ReffiSplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var logoVisible = false
    let onSettled: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ReffiColor.canvas.ignoresSafeArea()
                ReffiLogo(height: 94)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .offset(y: logoVisible ? 0 : proxy.size.height * 0.72)
                    .scaleEffect(logoVisible ? 1 : 0.96)
            }
        }
        .onAppear {
            withAnimation(ReffiMotion.gated(ReffiMotion.splashLogo, reduce: reduceMotion)) {
                logoVisible = true
            }
        }
        .task {
            guard !reduceMotion else {
                onSettled()
                return
            }

            try? await Task.sleep(for: .milliseconds(620))
            guard !Task.isCancelled else { return }
            onSettled()
        }
    }
}
