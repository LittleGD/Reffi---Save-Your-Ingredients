import Foundation
import Observation
import os
import Supabase
import AuthenticationServices
import CryptoKit

/// 인증 상태 — Supabase Auth 세션의 단일 소스.
/// 이메일 가입/로그인 + Apple(네이티브 ID 토큰) + Google(OAuth 브라우저) + 게스트(둘러보기).
/// 세션은 supabase-swift가 Keychain에 영속화하고, `authStateChanges`로 복원·구독한다.
@Observable
@MainActor
final class AuthStore {

    /// 프로젝트 URL·publishable(anon) key — 클라이언트 임베드용 공개 값(RLS로 보호).
    static let supabaseURL = URL(string: "https://bzzpmaeitfbbunsmjvmd.supabase.co")!
    static let anonKey = "sb_publishable_RolVTNQCWTf9t9XBEcCz1w_HcEeYquc"

    /// Supabase 클라이언트 — publishable key는 클라이언트 임베드용 공개 키(RLS로 보호).
    static let client = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: anonKey,
        options: .init(auth: .init(emitLocalSessionAsInitialSession: true)))

    /// 인증 진단 로그(FridgeStore.log와 같은 서브시스템). 화면에 못 내보내는 서버 원문이 여기로 간다.
    static let log = Logger(subsystem: "com.reffi.app", category: "auth")

    /// OAuth 콜백 — Info.plist의 `reffi` URL 스킴과 일치해야 한다.
    static let redirectURL = URL(string: "reffi://auth-callback")!

    // MARK: - 상태

    private(set) var session: Session?
    /// 익명 로그인 실패(대시보드 비활성·오프라인) 시 폴백 — 로컬 전용 게스트 플래그.
    private(set) var localGuest: Bool
    /// 저장된 세션 복원 중(첫 프레임 스플래시 판단용).
    private(set) var restoring = true
    /// 네트워크 요청 진행 중(버튼 비활성).
    private(set) var busy = false
    private(set) var availability = AuthAvailability()
    var needsPasswordReset = false

    func refreshAvailability() async {
        var request = URLRequest(url: Self.supabaseURL.appendingPathComponent("auth/v1/settings"))
        request.setValue(Self.anonKey, forHTTPHeaderField: "apikey")
        request.timeoutInterval = 10
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return }
            availability = try JSONDecoder().decode(AuthAvailability.self, from: data)
        } catch { /* Keep unavailable providers hidden when offline. */ }
    }


    var errorMessage: String?
    /// 성공 안내(예: 가입 후 이메일 확인).
    var notice: String?

    /// 게스트 = 익명 세션(서버 user id 보유, 가입 시 승계) 또는 로컬 폴백.
    var isGuest: Bool { session?.user.isAnonymous == true || localGuest }
    /// 앱 진입은 로컬 자료 접근이다. 만료된 캐시도 소유자 복원에 사용하며 서버 작업은 별도로 인증한다.
    var isSignedIn: Bool { session != nil || localGuest }
    var userEmail: String? { session?.user.email }
    /// 로컬 저장 공간의 소유자. 익명/로컬 게스트는 별도 guest 공간을 사용한다.
    var accountUserID: String? {
        guard let user = session?.user, !user.isAnonymous else { return nil }
        return user.id.uuidString
    }

    init() {
        var guest = UserDefaults.standard.bool(forKey: Key.guest)
        #if DEBUG
        // 스크린샷·QA용 — 인증 게이트 건너뛰기(-fridgeTab 선례).
        if ProcessInfo.processInfo.arguments.contains("-skipAuth") { guest = true }
        if ProcessInfo.processInfo.arguments.contains("-authGate") { guest = false }
        #endif
        localGuest = guest
        Task { await listen() }
    }

    /// Keychain의 세션을 복원하고 이후 변경(로그인·로그아웃·갱신)을 구독.
    private func listen() async {
        for await (event, session) in Self.client.auth.authStateChanges {
            let wasAnonymous = self.session?.user.isAnonymous == true
            if self.session?.user.id != session?.user.id {
                Analytics.shared.changeAccount(to: session?.user.id.uuidString)
            }
            self.session = session
            if event == .passwordRecovery { needsPasswordReset = true }
            if session != nil { setLocalGuest(false) }
            if event == .initialSession { restoring = false }
            trackAuthChange(event, session: session, wasAnonymous: wasAnonymous)
        }
    }

    /// 계정 이벤트(64차) — 로그인 방식·익명 여부·익명→정식 승계만 남긴다(이메일·id는 싣지 않는다).
    /// 세션이 생기는 순간 큐를 밀어낸다: `user_id`는 서버가 `auth.uid()`로 채우므로 세션 없인 못 올린다.
    private func trackAuthChange(_ event: AuthChangeEvent, session: Session?, wasAnonymous: Bool) {
        switch event {
        case .signedIn:
            guard let user = session?.user else { return }
            Analytics.shared.track(.authSignIn(provider: Self.provider(of: user), anonymous: user.isAnonymous))
            Analytics.shared.flushSoon()
        case .userUpdated:
            guard let user = session?.user, wasAnonymous, !user.isAnonymous else { return }
            Analytics.shared.track(.authUpgrade(provider: Self.provider(of: user)))
        case .signedOut:
            Analytics.shared.track(.authSignOut)
        case .initialSession, .tokenRefreshed:
            if session != nil { Analytics.shared.flushSoon() }
        default:
            break
        }
    }

    private static func provider(of user: User) -> String {
        user.appMetadata["provider"]?.stringValue ?? (user.isAnonymous ? "anonymous" : "unknown")
    }

    // MARK: - 이메일

    /// 가입 — 익명 세션이면 같은 user id를 유지한 채 정식 계정으로 전환(데이터 승계).
    /// 이메일 확인이 켜져 있으면 인증 완료 시점에 전환이 확정된다.
    func signUp(email: String, password: String) async {
        await run {
            if let user = session?.user, user.isAnonymous {
                try await Self.client.auth.update(
                    user: UserAttributes(email: email, password: password), redirectTo: Self.redirectURL
                )
                self.notice = String(localized: "Check your inbox.\nOnce verified, your guest data carries over.")
            } else {
                let res = try await Self.client.auth.signUp(email: email, password: password, redirectTo: Self.redirectURL)
                if res.session == nil {
                    self.notice = String(localized: "Confirmation email sent.\nVerify it, then log in.")
                }
            }
        }
    }

    func signIn(email: String, password: String) async {
        await run { try await Self.client.auth.signIn(email: email, password: password) }
    }

    // MARK: - 소셜

    /// Apple — 네이티브 시트의 ID 토큰을 Supabase로 교환. `nonce`는 요청에 넣은 원본(raw) 값.
    func signInWithApple(_ result: Result<ASAuthorization, Error>, nonce: String) async {
        await run {
            switch result {
            case .failure(let e):
                if (e as? ASAuthorizationError)?.code == .canceled { return }
                throw e
            case .success(let auth):
                guard let cred = auth.credential as? ASAuthorizationAppleIDCredential,
                      let data = cred.identityToken,
                      let idToken = String(data: data, encoding: .utf8) else {
                    throw AuthLocalError.appleToken
                }
                try await Self.client.auth.signInWithIdToken(
                    credentials: OpenIDConnectCredentials(provider: .apple, idToken: idToken, nonce: nonce)
                )
            }
        }
    }

    /// Google — 시스템 브라우저(ASWebAuthenticationSession) OAuth. 완료 시 reffi:// 콜백으로 세션 수립.
    func signInWithGoogle() async {
        await run {
            try await Self.client.auth.signInWithOAuth(provider: .google, redirectTo: Self.redirectURL)
        }
    }

    /// OAuth 콜백 URL 처리(onOpenURL) — 외부 브라우저로 돌아온 경우의 안전망.
    func handleOpenURL(_ url: URL) {
        guard url.scheme == "reffi" else { return }
        Task { try? await Self.client.auth.session(from: url) }
    }

    // MARK: - 게스트 · 로그아웃

    /// 둘러보기 — 익명 세션 발급(서버 user id 확보 → 가입 시 기록 승계).
    /// 익명 로그인이 꺼져 있거나 오프라인이면 로컬 게스트로 조용히 폴백.
    func continueAsGuest() async {
        errorMessage = nil
        setLocalGuest(true)
        busy = true
        defer { busy = false }
        await refreshAvailability()
        guard availability.anonymous else { setLocalGuest(true); return }
        do { try await Self.client.auth.signInAnonymously() }
        catch { setLocalGuest(true) }
    }

    /// 이 기기의 인증 세션을 해제한다. 계정 자료는 별도 파일에 보관하고 게스트 공간으로 전환한다.
    /// Supabase의 로컬 세션 제거는 서버 요청보다 먼저 이뤄지므로 오프라인에서도 로그아웃한다.
    func signOut() async {
        errorMessage = nil
        notice = nil
        setLocalGuest(false)
        busy = true
        defer { busy = false }
        try? await Self.client.auth.signOut(scope: .local)
        session = nil
        setLocalGuest(true)
    }

    // MARK: - 계정 관리

    /// 서버가 삭제를 확정한 뒤에만 호출부가 로컬 자료를 지우고 로그아웃한다.
    func deleteAccount() async -> Bool {
        guard accountUserID != nil, !busy else { return false }
        errorMessage = nil
        busy = true
        defer { busy = false }
        do {
            try await Self.client.rpc("delete_own_account").execute()
            return true
        } catch {
            errorMessage = String(localized: "Couldn't delete your account. Your data is still saved. Check your connection and try again.")
            return false
        }
    }

    func sendPasswordReset(email: String) async {
        await run {
            try await Self.client.auth.resetPasswordForEmail(email, redirectTo: Self.redirectURL)
            notice = String(localized: "If this email has an account, a password reset link is on its way.")
        }
    }

    func updatePassword(_ password: String) async {
        await run {
            try await Self.client.auth.update(user: UserAttributes(password: password))
            needsPasswordReset = false
            notice = String(localized: "Password updated.")
        }
    }

    private func setLocalGuest(_ v: Bool) {
        guard localGuest != v else { return }
        localGuest = v
        UserDefaults.standard.set(v, forKey: Key.guest)
    }

    // MARK: - 공통 실행 래퍼

    private func run(_ work: () async throws -> Void) async {
        errorMessage = nil
        notice = nil
        busy = true
        defer { busy = false }
        do { try await work() }
        catch { errorMessage = Self.friendly(error) }
    }

    /// 서버 에러 → 사용자 문구(과도한 기술 노출 방지).
    private static func friendly(_ error: Error) -> String {
        let raw = error.localizedDescription
        let lower = raw.lowercased()
        if lower.contains("invalid login credentials") { return String(localized: "Email or password doesn't match.") }
        if lower.contains("email not confirmed") { return String(localized: "Please verify your email first.\nCheck your inbox.") }
        if lower.contains("already registered") { return String(localized: "This email is already registered.\nTry logging in.") }
        if lower.contains("at least 6 characters") || lower.contains("password should")
            { return String(localized: "Password must be at least 6 characters.") }
        if lower.contains("invalid format") || lower.contains("validate email")
            { return String(localized: "Please check the email address.") }
        if lower.contains("network") || lower.contains("offline") || lower.contains("internet")
            { return String(localized: "Check your network connection.") }
        if lower.contains("provider is not enabled") { return String(localized: "This sign-in method isn't available yet.") }
        if (error as? ASAuthorizationError) != nil { return String(localized: "Couldn't complete Apple sign-in.") }
        // 매칭 실패 폴백 — 서버 원문은 화면에 내보내지 않는다. 영어로 고정된 데다 서버 용어("AuthApiError",
        // "invalid_grant")를 그대로 노출해, 한국어 기기에서 유일하게 영어로 뜨는 문장이 되고 사용자가
        // 할 수 있는 일도 알려주지 않는다. 원문은 로그로만 남긴다(진단은 잃지 않는다).
        log.error("unmatched auth error: \(raw)")
        return String(localized: "Couldn't sign you in.\nTry again in a moment.")
    }

    enum AuthLocalError: LocalizedError {
        case appleToken
        var errorDescription: String? { String(localized: "Couldn't complete Apple sign-in.") }
    }

    private enum Key {
        static let guest = "auth.guest"
    }

    // MARK: - Apple nonce 헬퍼 (replay 방지)

    /// 요청용 랜덤 nonce — 원본은 Supabase에, SHA256은 Apple 요청에 넣는다.
    static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            guard status == errSecSuccess else { continue }
            if random < charset.count {
                result.append(charset[Int(random)])
                remaining -= 1
            }
        }
        return result
    }

    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

/// Read-only backend settings. Social login stays hidden until login and revocation QA is complete.
struct AuthAvailability: Decodable, Equatable {
    var external: [String: Bool] = [:]
    var anonymous: Bool { external["anonymous_users"] == true }
    var email: Bool { external["email"] ?? true }
    var apple: Bool { false }
    var google: Bool { false }
}
