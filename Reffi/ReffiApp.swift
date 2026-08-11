import SwiftUI

@main
struct ReffiApp: App {
    @State private var store = FridgeStore()
    @State private var profile = ProfileStore()
    @State private var auth = AuthStore()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        NotificationPresenter.shared.install()   // 포그라운드에서도 알림 배너 표시
        DataOwner.migrateIfNeeded()              // v2 이전 익명 uuid 소유자 기록 1회 정리
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
                    if phase == .active {
                        ExpiryNotifier.reschedule(for: store.ingredients)
                        store.promoteUrgent()   // 포그라운드 정렬 — 알림이 가리키는 임박 재료를 작업대로 승격
                    }
                }
        }
    }

    @ViewBuilder private var rootContent: some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-glyphGallery") {
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
        } else if ProcessInfo.processInfo.arguments.contains("-authView") {
            AuthView()
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

/// 진입 게이트 — 온보딩(기기당 1회) → 로그인(세션/게스트 없으면) → 메인.
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
}

private struct RootGateView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(FridgeStore.self) private var store
    @Environment(ProfileStore.self) private var profile
    @AppStorage("onboarding.done") private var onboardingDone = false

    var body: some View {
        gate
            // 계정 전환 감지 와이프 — 정식 계정 user id가 바뀌면(다른 계정 로그인) 이전 소유자의
            // 로컬 냉장고·프로필이 새 계정에 새지 않게 초기화한다. onChange는 최초 세션 복원
            // (nil→id)에도 발화하므로 소유자 최초 기록·익명→가입 승계(같은 id)도 여기서 다룬다.
            // 익명 세션은 `accountUserID`가 nil이라 여기 걸리지 않는다 — 로그아웃 직후 게이트가
            // 자동으로 붙이는 게스트 세션은 '다른 사람'이 아니라 같은 기기의 같은 사람이기 때문.
            .onChange(of: auth.accountUserID) { _, newID in reconcileDataOwner(newID) }
    }

    @ViewBuilder private var gate: some View {
        if auth.restoring {
            splash
        } else if !onboardingDone {
            OnboardingView(onFinish: { onboardingDone = true })
        } else {
            // 게스트 우선 — 온보딩 후엔 로그인 벽 없이 곧장 메인 앱. 세션이 없으면 익명 게스트로 진입한다.
            // 로그인/가입은 프로필 탭 Account 섹션에서 선택적으로(익명→가입 데이터 승계 보장).
            RootTabView()
                .transition(.opacity)
                .task { if !auth.isSignedIn { await auth.continueAsGuest() } }
        }
    }

    /// 소유자 대조 — 새 정식 계정 id가 기존 소유자와 다르면 로컬 데이터를 와이프하고 소유자를 갱신한다.
    /// 입력은 `AuthStore.accountUserID`(비익명 전용)라, 로그아웃·익명 게스트 구간은 nil로 들어와
    /// 소유자를 그대로 유지한다. 세 경로 보장:
    ///   ① 같은 계정 재로그인 = previous == newID → 와이프 없음(콜드 런치로 익명 게스트를 거쳐도 동일)
    ///   ② 익명→가입 승계 = 익명 구간엔 기록이 없고 가입 후 previous == nil → 최초 기록, 와이프 없음
    ///      (v2 이전 설치가 남긴 익명 uuid 기록은 DataOwner.migrateIfNeeded()가 1회 정리)
    ///   ③ 다른 계정 로그인 = previous != nil && previous != newID → 와이프
    private func reconcileDataOwner(_ newID: String?) {
        guard let newID else { return }
        let previous = UserDefaults.standard.string(forKey: DataOwner.key)
        guard previous != newID else { return }   // 같은 소유자(익명→가입 승계 포함) — 변화 없음
        if previous != nil {
            // 다른 계정으로 전환 — 이전 소유자 데이터 제거.
            store.resetAllData()
            profile.resetAll()
        }
        // previous == nil: 최초 기록(와이프 없음). 어느 경우든 소유자 확정.
        UserDefaults.standard.set(newID, forKey: DataOwner.key)
        // 가입 완료·계정 전환으로 프로필이 방금 미설정 상태가 됐을 수 있다 — 그럴 때만 자동 닉네임.
        profile.assignGeneratedNicknameIfUnset()
    }

    /// 세션 복원 동안의 정적 스플래시 — 런치 스크린과 같은 크림 + 워드마크(깜빡임 방지).
    private var splash: some View {
        ZStack {
            ReffiColor.canvas.ignoresSafeArea()
            Text(verbatim: "Reffi").reffiType(.display).foregroundStyle(ReffiColor.blueDark)
        }
    }
}
